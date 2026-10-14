"""
SOS - Canh bao nguy hiem theo vi tri dia ly (Nearby Emergency Alert)

Kien truc realtime: HEARTBEAT/INBOX qua HTTPS co xac thuc JWT (khong them WebSocket moi).
Ly do: backend chay Flask tren cPanel/Passenger (nhieu worker, khong dam bao WebSocket), nen
trang thai phan phoi duoc luu trong DB (SOSNotification) va thiet bi dang mo app dinh ky goi
POST /location (heartbeat + vi tri) -> nhan ve cac canh bao danh rieng cho minh. Moi quyet dinh
"ai la nguoi nhan" do SERVER tinh tu vi tri da xac minh; client khong the tu khai bao nguoi nhan.
"""
import json
import math
import os
import threading
import uuid
from datetime import datetime, timedelta

from flask import request, current_app
from sqlalchemy.exc import IntegrityError

from extensions import db
from models import (User, PassengerSOS, SOSIncident, SOSNotification,
                    SOSAuditLog, UserLocation)

from . import api_v1_bp
from .errors import api_success, api_error
from .decorators import jwt_required

INCIDENT_TYPES = {'general', 'accident', 'medical', 'threat', 'other'}
GRANTED_PERMISSIONS = {'granted', 'whileinuse', 'always'}

DEFAULT_CONFIG = {
    "rings": [
        {"ring": 1, "radius_m": 500, "delay_s": 0},
        {"ring": 2, "radius_m": 1000, "delay_s": 30},
        {"ring": 3, "radius_m": 3000, "delay_s": 90},
    ],
    "heartbeat_seconds": 10,
    "presence_ttl_seconds": 35,
    "location_max_age_seconds": 120,
    "max_recipient_accuracy_m": 150,
    "incident_expire_hours": 6,
    "max_incidents_per_hour_user": 5,
    "max_incidents_per_hour_device": 8,
    "min_location_interval_seconds": 2,
    "location_retention_hours": 24,
    "inbox_resolved_window_minutes": 10,
    "max_notified_per_incident": 500,
    "reverse_geocode_enabled": True,
    "push_enabled": False,
    "push_location_max_age_seconds": 600,
}

_cfg_cache = {"mtime": None, "path": None, "data": None}
CONFIG_OVERRIDE = {}   # dung cho kiem thu
_last_purge = {"at": None}


# ----------------------------------------------------------------- config
def _config_path():
    env = os.getenv('SOS_CONFIG_PATH')
    if env:
        return env
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(root, 'sos_config.json')


def get_config():
    """Doc sos_config.json (cache theo mtime) + gop voi mac dinh. Sua file la co hieu luc, khong can sua Flutter."""
    path = _config_path()
    data = dict(DEFAULT_CONFIG)
    try:
        mtime = os.path.getmtime(path)
        if _cfg_cache["path"] != path or _cfg_cache["mtime"] != mtime:
            with open(path, 'r', encoding='utf-8') as f:
                _cfg_cache.update(path=path, mtime=mtime, data=json.load(f))
        data.update(_cfg_cache["data"] or {})
    except Exception:
        pass
    data.update(CONFIG_OVERRIDE)
    try:
        data["rings"] = sorted(
            [{"ring": int(r["ring"]), "radius_m": float(r["radius_m"]), "delay_s": float(r["delay_s"])}
             for r in data["rings"]], key=lambda r: (r["delay_s"], r["radius_m"]))
    except Exception:
        data["rings"] = DEFAULT_CONFIG["rings"]
    return data


# ---------------------------------------------------------------- helpers
def _now():
    return datetime.utcnow()


def _iso(dt):
    return dt.isoformat() + 'Z' if dt else None


def haversine_m(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


class _BadLocation(ValueError):
    pass


def _parse_coords(lat, lng):
    """None neu client khong gui toa do. Nem _BadLocation neu gui nhung khong hop le (khong tu bia toa do)."""
    if lat is None and lng is None:
        return None
    try:
        lat, lng = float(lat), float(lng)
    except (TypeError, ValueError):
        raise _BadLocation("Toa do khong hop le")
    if not (math.isfinite(lat) and math.isfinite(lng)):
        raise _BadLocation("Toa do khong hop le")
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        raise _BadLocation("Toa do nam ngoai pham vi")
    if lat == 0.0 and lng == 0.0:
        raise _BadLocation("Toa do (0,0) khong hop le")
    return lat, lng


def _parse_accuracy(value):
    try:
        v = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(v) or v < 0:
        return None
    return min(v, 100000.0)


def _device_id(data):
    raw = request.headers.get('X-Device-Id') or (data or {}).get('device_id') or ''
    raw = str(raw).strip()[:64]
    return raw or None


def _audit(incident, user, action, detail=None):
    try:
        db.session.add(SOSAuditLog(
            incident_id=incident.id if incident is not None else None,
            user_id=user.id if user is not None else None,
            action=action,
            detail=(detail or '')[:300] or None,
            ip=(request.headers.get('X-Forwarded-For') or request.remote_addr or '')[:64],
        ))
    except Exception:
        pass


def _current_radius(incident, now, cfg):
    elapsed = max(0.0, (now - incident.created_at).total_seconds())
    radius = 0.0
    for r in cfg["rings"]:
        if elapsed >= r["delay_s"]:
            radius = max(radius, r["radius_m"])
    return radius


def _ring_for_distance(dist, cfg):
    for r in sorted(cfg["rings"], key=lambda r: r["radius_m"]):
        if dist <= r["radius_m"]:
            return r["ring"]
    return cfg["rings"][-1]["ring"]


def _loc_usable(loc, now, cfg, max_age):
    """Vi tri du tin cay de xac dinh khoang cach: da dong y, co quyen, moi, du chinh xac."""
    if not loc or not loc.sharing_enabled:
        return False
    if loc.latitude is None or loc.longitude is None or loc.updated_at is None:
        return False
    if (loc.permission_status or '').lower() not in GRANTED_PERMISSIONS:
        return False
    if (now - loc.updated_at).total_seconds() > max_age:
        return False
    if loc.accuracy_meters is None or loc.accuracy_meters > cfg["max_recipient_accuracy_m"]:
        return False
    return True


def _is_present(loc, now, cfg):
    return bool(loc) and (now - loc.last_seen_at).total_seconds() <= cfg["presence_ttl_seconds"]


def _expire_stale(now, cfg):
    cutoff = now - timedelta(hours=cfg["incident_expire_hours"])
    stale = SOSIncident.query.filter(SOSIncident.status == 'active', SOSIncident.created_at < cutoff).all()
    for inc in stale:
        inc.status = 'expired'
        inc.resolved_at = now
        inc.resolved_by = 'system'
        _audit(inc, None, 'expire', 'het han tu dong')
    if stale:
        db.session.commit()


def _purge_old_locations(now, cfg):
    last = _last_purge["at"]
    if last and (now - last).total_seconds() < 600:
        return
    _last_purge["at"] = now
    cutoff = now - timedelta(hours=cfg["location_retention_hours"])
    try:
        UserLocation.query.filter(UserLocation.last_seen_at < cutoff).delete(synchronize_session=False)
        db.session.commit()
    except Exception:
        db.session.rollback()


# ------------------------------------------------------------ serializers
def _stats(incident):
    q = SOSNotification.query.filter_by(incident_id=incident.id)
    notifs = q.all()
    return {
        "in_zone_devices": len(notifs),
        "delivered": sum(1 for n in notifs if n.delivered_at is not None),
        "acknowledged": sum(1 for n in notifs if n.acknowledged_at is not None),
        "responding": sum(1 for n in notifs if n.response == 'helping'),
    }


def _reporter_view(incident, cfg, duplicate=False):
    now = _now()
    return {
        "event_id": incident.event_id,
        "status": incident.status,
        "incident_type": incident.incident_type,
        "location_status": incident.location_status,
        "latitude": incident.latitude,
        "longitude": incident.longitude,
        "accuracy_meters": incident.accuracy_meters,
        "address": incident.address_text,
        "created_at": _iso(incident.created_at),
        "last_location_update_at": _iso(incident.last_location_update_at),
        "resolved_at": _iso(incident.resolved_at),
        "resolved_by": incident.resolved_by,
        "distribution_suppressed": 'distribution_suppressed' in (incident.flags or ''),
        "current_radius_m": _current_radius(incident, now, cfg) if incident.status == 'active' else 0,
        "delivery": _stats(incident),
        "duplicate": duplicate,
    }


def _recipient_view(n, incident, cur_loc=None, cfg=None):
    dist = n.distance_m
    if cur_loc is not None and incident.latitude is not None:
        dist = haversine_m(incident.latitude, incident.longitude, cur_loc.latitude, cur_loc.longitude)
    approx = None
    if dist is not None:
        approx = int(max(50, round(dist / 50.0) * 50))
    return {
        "event_id": incident.event_id,
        "status": incident.status,
        "incident_type": incident.incident_type,
        "title": "CẢNH BÁO KHẨN CẤP",
        "message": "Có người đang gặp nguy hiểm ở gần bạn",
        "distance_m": approx,
        "latitude": incident.latitude,
        "longitude": incident.longitude,
        "accuracy_meters": incident.accuracy_meters,
        "area": incident.address_text,
        "created_at": _iso(incident.created_at),
        "location_updated_at": _iso(incident.last_location_update_at),
        "resolved_at": _iso(incident.resolved_at),
        "my_status": n.delivery_status,
        "ring": n.ring,
        # Khong tra ve ten, so dien thoai hay thong tin ca nhan cua nguoi gui SOS
    }


# ----------------------------------------------------------- distribution
def _insert_notifications(objs):
    if not objs:
        return []
    try:
        db.session.add_all(objs)
        db.session.commit()
        return objs
    except IntegrityError:
        db.session.rollback()
    inserted = []
    for o in objs:
        try:
            with db.session.begin_nested():
                db.session.add(SOSNotification(
                    incident_id=o.incident_id, recipient_user_id=o.recipient_user_id,
                    distance_m=o.distance_m, ring=o.ring, delivery_status='queued'))
            inserted.append(o)
        except IntegrityError:
            continue
    db.session.commit()
    return inserted


def _distribute(incident, now, cfg):
    """Xac dinh nguoi nhan THEO VI TRI (bounding box + Haversine) trong ban kinh vong hien tai."""
    if incident.status != 'active' or incident.location_status != 'known':
        return []
    if 'distribution_suppressed' in (incident.flags or ''):
        return []
    radius = _current_radius(incident, now, cfg)
    if radius <= 0:
        return []

    dlat = radius / 111320.0
    dlng = radius / (111320.0 * max(math.cos(math.radians(incident.latitude)), 0.01))
    q = UserLocation.query.filter(
        UserLocation.user_id != incident.reporter_user_id,
        UserLocation.sharing_enabled.is_(True),
        UserLocation.latitude.between(incident.latitude - dlat, incident.latitude + dlat),
        UserLocation.longitude.between(incident.longitude - dlng, incident.longitude + dlng),
    )
    existing = {r[0] for r in db.session.query(SOSNotification.recipient_user_id)
                .filter_by(incident_id=incident.id).all()}
    budget = cfg["max_notified_per_incident"] - len(existing)
    if budget <= 0:
        return []

    candidates = []
    for loc in q.all():
        if loc.user_id in existing:
            continue
        present = _is_present(loc, now, cfg)
        if present:
            ok = _loc_usable(loc, now, cfg, cfg["location_max_age_seconds"])
        elif cfg["push_enabled"]:
            ok = _loc_usable(loc, now, cfg, cfg["push_location_max_age_seconds"])
        else:
            ok = False
        if not ok:
            continue
        dist = haversine_m(incident.latitude, incident.longitude, loc.latitude, loc.longitude)
        if dist <= radius:
            candidates.append((dist, loc, present))

    candidates.sort(key=lambda c: c[0])
    candidates = candidates[:budget]
    objs = [SOSNotification(incident_id=incident.id, recipient_user_id=loc.user_id,
                            distance_m=dist, ring=_ring_for_distance(dist, cfg), delivery_status='queued')
            for dist, loc, present in candidates]
    inserted = _insert_notifications(objs)
    if inserted:
        _audit(incident, None, 'distribute', f"{len(inserted)} thiet bi trong ban kinh {int(radius)}m")
        db.session.commit()
        offline = {loc.user_id for dist, loc, present in candidates if not present}
        _send_push([n for n in inserted if n.recipient_user_id in offline], incident)
    return inserted


def _match_user_to_active_incidents(user, loc, now, cfg):
    """Khi mot thiet bi gui vi tri: kiem tra no co vua nam trong vung cua SOS dang hoat dong hay khong
    (giup cac vong mo rong theo thoi gian va nguoi di chuyen vao vung ma khong can bo lap lich)."""
    if not _loc_usable(loc, now, cfg, cfg["location_max_age_seconds"]):
        return
    actives = SOSIncident.query.filter(
        SOSIncident.status == 'active', SOSIncident.location_status == 'known',
        SOSIncident.reporter_user_id != user.id).all()
    for inc in actives:
        if 'distribution_suppressed' in (inc.flags or ''):
            continue
        if SOSNotification.query.filter_by(incident_id=inc.id, recipient_user_id=user.id).first():
            continue
        if SOSNotification.query.filter_by(incident_id=inc.id).count() >= cfg["max_notified_per_incident"]:
            continue
        dist = haversine_m(inc.latitude, inc.longitude, loc.latitude, loc.longitude)
        if dist <= _current_radius(inc, now, cfg):
            _insert_notifications([SOSNotification(
                incident_id=inc.id, recipient_user_id=user.id, distance_m=dist,
                ring=_ring_for_distance(dist, cfg), delivery_status='queued')])
            _audit(inc, None, 'distribute', f"them 1 thiet bi (heartbeat) cach {int(dist)}m")
            db.session.commit()


def _send_push(notifs, incident):
    """Bo sung (mac dinh TAT): chi gui cho token da dang ky cua nguoi nhan do server xac dinh."""
    if not notifs:
        return
    try:
        import firebase_admin
        from firebase_admin import messaging
        if not firebase_admin._apps:
            return
    except Exception:
        return
    for n in notifs:
        user = User.query.get(n.recipient_user_id)
        if not user or not user.fcm_token:
            continue
        try:
            messaging.send(messaging.Message(
                token=user.fcm_token,
                notification=messaging.Notification(
                    title='CẢNH BÁO KHẨN CẤP',
                    body='Có người đang gặp nguy hiểm ở gần bạn. Mở ứng dụng để xem.'),
                data={'type': 'sos', 'event_id': incident.event_id}))
            n.push_sent_at = _now()
        except Exception as e:
            name = type(e).__name__
            if name in ('UnregisteredError', 'SenderIdMismatchError'):
                user.fcm_token = None   # token het han / khong hop le
    db.session.commit()


def _reverse_geocode_async(app, incident_id, lat, lng):
    def run():
        try:
            import requests
            r = requests.get('https://nominatim.openstreetmap.org/reverse', params={
                'format': 'jsonv2', 'lat': lat, 'lon': lng, 'zoom': 16, 'accept-language': 'vi'},
                headers={'User-Agent': 'VeXeMobile-SOS/1.0'}, timeout=4)
            addr = (r.json() or {}).get('address', {})
            parts = []
            for keys in (('road',), ('suburb', 'quarter', 'neighbourhood', 'village'),
                         ('city_district', 'county'), ('city', 'town', 'state')):
                for k in keys:
                    v = addr.get(k)
                    if v and v not in parts:
                        parts.append(v)
                        break
            text = ', '.join(parts)[:200]
            if not text:
                return
            with app.app_context():
                inc = SOSIncident.query.get(incident_id)
                if inc and not inc.address_text:
                    inc.address_text = text
                    db.session.commit()
        except Exception:
            pass
    threading.Thread(target=run, daemon=True).start()


# --------------------------------------------------------------- lookups
def _incident_or_none(event_id):
    return SOSIncident.query.filter_by(event_id=str(event_id)[:36]).first()


def _forbidden():
    return api_error(message="Bạn không có quyền với sự kiện SOS này", error_code="SOS_FORBIDDEN", status=403)


def _not_found():
    return api_error(message="Không tìm thấy sự kiện SOS", error_code="SOS_NOT_FOUND", status=404)


# ================================================================ routes
@api_v1_bp.route('/sos/config', methods=['GET'])
@jwt_required()
def sos_config():
    cfg = get_config()
    return api_success({
        "heartbeat_seconds": cfg["heartbeat_seconds"],
        "rings": cfg["rings"],
        "max_recipient_accuracy_m": cfg["max_recipient_accuracy_m"],
        "location_max_age_seconds": cfg["location_max_age_seconds"],
    })


@api_v1_bp.route('/sos', methods=['POST'])
@jwt_required()
def create_sos():
    user = request.current_user
    data = request.get_json(silent=True) or {}
    cfg, now = get_config(), _now()
    _expire_stale(now, cfg)

    try:
        coords = _parse_coords(data.get('lat'), data.get('lng'))
    except _BadLocation as e:
        return api_error(message=str(e), error_code="INVALID_LOCATION", status=400)
    accuracy = _parse_accuracy(data.get('accuracy'))
    itype = data.get('incident_type') if data.get('incident_type') in INCIDENT_TYPES else 'general'
    idem = str(request.headers.get('Idempotency-Key') or data.get('idempotency_key') or '').strip()[:64] or None
    device_id = _device_id(data)

    # Chong gui trung: cung idempotency key, hoac da co SOS dang hoat dong
    if idem:
        same = SOSIncident.query.filter_by(reporter_user_id=user.id, idempotency_key=idem).first()
        if same:
            return api_success(_reporter_view(same, cfg, duplicate=True), message="SOS đã được tiếp nhận trước đó")
    active = SOSIncident.query.filter_by(reporter_user_id=user.id, status='active').first()
    if active:
        if coords:
            active.latitude, active.longitude = coords
            active.accuracy_meters = accuracy
            active.location_status = 'known'
            active.last_location_update_at = now
            db.session.commit()
            _distribute(active, now, cfg)
        _audit(active, user, 'create_duplicate', 'da co SOS dang hoat dong')
        db.session.commit()
        return api_success(_reporter_view(active, cfg, duplicate=True), message="Bạn đang có một SOS đang hoạt động")

    # Phat hien lam dung: KHONG chan cung - van ghi nhan SOS, chi han che phat tan canh bao lan can
    flags = []
    since = now - timedelta(hours=1)
    if SOSIncident.query.filter(SOSIncident.reporter_user_id == user.id,
                                SOSIncident.created_at >= since).count() >= cfg["max_incidents_per_hour_user"]:
        flags.append('distribution_suppressed:user_rate')
    if device_id and SOSIncident.query.filter(SOSIncident.device_id == device_id,
                                              SOSIncident.created_at >= since).count() >= cfg["max_incidents_per_hour_device"]:
        flags.append('distribution_suppressed:device_rate')

    incident = SOSIncident(
        event_id=str(uuid.uuid4()), reporter_user_id=user.id,
        latitude=coords[0] if coords else None, longitude=coords[1] if coords else None,
        accuracy_meters=accuracy if coords else None,
        location_status='known' if coords else 'unknown',
        address_text=(str(data.get('address')).strip()[:200] or None) if data.get('address') else None,
        incident_type=itype, status='active', idempotency_key=idem, device_id=device_id,
        flags=';'.join(flags) or None, created_at=now,
        last_location_update_at=now if coords else None)
    db.session.add(incident)
    try:
        # Ban ghi cho bang dieu khien cua nha xe (giu tuong thich man hinh /sos_alerts)
        legacy = PassengerSOS(
            user_id=user.id, passenger_name=user.name, passenger_phone=user.phone,
            latitude=coords[0] if coords else 0.0, longitude=coords[1] if coords else 0.0,
            message=('SOS ứng dụng - loại: %s' % itype) + ('' if coords else ' [VỊ TRÍ CHƯA XÁC ĐỊNH]'))
        db.session.add(legacy)
        db.session.flush()
        incident.legacy_sos_id = legacy.id
        db.session.flush()
        _audit(incident, user, 'create',
               f"type={itype} loc={'known' if coords else 'unknown'} flags={incident.flags or '-'}")
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        return api_error(message=f"Không thể lưu SOS: {e}", error_code="SOS_ERROR", status=500)

    if coords:
        _distribute(incident, now, cfg)
        if cfg["reverse_geocode_enabled"] and not incident.address_text:
            _reverse_geocode_async(current_app._get_current_object(), incident.id, coords[0], coords[1])

    return api_success(_reporter_view(incident, cfg), message="Backend đã tiếp nhận SOS", status=201)


@api_v1_bp.route('/sos/active', methods=['GET'])
@jwt_required()
def sos_active():
    user, cfg, now = request.current_user, get_config(), _now()
    _expire_stale(now, cfg)
    inc = SOSIncident.query.filter_by(reporter_user_id=user.id, status='active') \
        .order_by(SOSIncident.created_at.desc()).first()
    return api_success({"incident": _reporter_view(inc, cfg) if inc else None})


@api_v1_bp.route('/sos/inbox', methods=['GET'])
@jwt_required()
def sos_inbox():
    return api_success({"alerts": _collect_inbox(request.current_user, get_config(), _now())})


def _collect_inbox(user, cfg, now):
    _expire_stale(now, cfg)
    window = now - timedelta(minutes=cfg["inbox_resolved_window_minutes"])
    rows = (db.session.query(SOSNotification, SOSIncident)
            .join(SOSIncident, SOSIncident.id == SOSNotification.incident_id)
            .filter(SOSNotification.recipient_user_id == user.id)
            .filter((SOSIncident.status == 'active') | (SOSIncident.resolved_at >= window))
            .order_by(SOSIncident.created_at.desc()).limit(20).all())
    loc = UserLocation.query.get(user.id)
    cur = loc if _loc_usable(loc, now, cfg, cfg["location_max_age_seconds"]) else None
    out = []
    for n, inc in rows:
        if n.delivered_at is None:
            n.delivered_at = now
            if n.delivery_status == 'queued':
                n.delivery_status = 'delivered'
        out.append(_recipient_view(n, inc, cur, cfg))
    if rows:
        db.session.commit()
    return out


@api_v1_bp.route('/sos/<event_id>', methods=['GET'])
@jwt_required()
def get_sos(event_id):
    user, cfg = request.current_user, get_config()
    inc = _incident_or_none(event_id)
    if not inc:
        return _not_found()
    _expire_stale(_now(), cfg)
    if inc.reporter_user_id == user.id:
        return api_success(_reporter_view(inc, cfg))
    n = SOSNotification.query.filter_by(incident_id=inc.id, recipient_user_id=user.id).first()
    if n:
        return api_success(_recipient_view(n, inc, None, cfg))
    return _forbidden()


@api_v1_bp.route('/sos/<event_id>/location', methods=['POST'])
@jwt_required()
def sos_update_location(event_id):
    user, cfg, now = request.current_user, get_config(), _now()
    inc = _incident_or_none(event_id)
    if not inc:
        return _not_found()
    if inc.reporter_user_id != user.id:
        return _forbidden()
    if inc.status != 'active':
        return api_error(message="SOS đã kết thúc", error_code="SOS_NOT_ACTIVE", status=409)
    data = request.get_json(silent=True) or {}
    try:
        coords = _parse_coords(data.get('lat'), data.get('lng'))
    except _BadLocation as e:
        return api_error(message=str(e), error_code="INVALID_LOCATION", status=400)
    if not coords:
        return api_error(message="Thiếu tọa độ", error_code="MISSING_LOCATION", status=400)
    last = inc.last_location_update_at
    if last and (now - last).total_seconds() < cfg["min_location_interval_seconds"]:
        return api_error(message="Cập nhật vị trí quá nhanh", error_code="RATE_LIMITED", status=429)
    inc.latitude, inc.longitude = coords
    inc.accuracy_meters = _parse_accuracy(data.get('accuracy'))
    inc.location_status = 'known'
    inc.last_location_update_at = now
    if inc.legacy_sos_id:
        legacy = PassengerSOS.query.get(inc.legacy_sos_id)
        if legacy:
            legacy.latitude, legacy.longitude = coords
    _audit(inc, user, 'location_update')
    db.session.commit()
    _distribute(inc, now, cfg)
    return api_success(_reporter_view(inc, cfg))


def _recipient_context(event_id, user):
    inc = _incident_or_none(event_id)
    if not inc:
        return None, None, _not_found()
    n = SOSNotification.query.filter_by(incident_id=inc.id, recipient_user_id=user.id).first()
    if not n:
        # nguoi khong nam trong danh sach phan phoi do server xac dinh -> tu choi
        return inc, None, _forbidden()
    return inc, n, None


@api_v1_bp.route('/sos/<event_id>/acknowledge', methods=['POST'])
@jwt_required()
def sos_acknowledge(event_id):
    user, cfg, now = request.current_user, get_config(), _now()
    inc, n, err = _recipient_context(event_id, user)
    if err:
        return err
    if n.acknowledged_at is None:
        n.acknowledged_at = now
        if n.delivery_status in ('queued', 'delivered'):
            n.delivery_status = 'acknowledged'
        if n.delivered_at is None:
            n.delivered_at = now
        _audit(inc, user, 'acknowledge')
        db.session.commit()
    return api_success(_recipient_view(n, inc, None, cfg))


@api_v1_bp.route('/sos/<event_id>/respond', methods=['POST'])
@jwt_required()
def sos_respond(event_id):
    user, cfg, now = request.current_user, get_config(), _now()
    inc, n, err = _recipient_context(event_id, user)
    if err:
        return err
    data = request.get_json(silent=True) or {}
    response = data.get('response', 'helping')
    if response not in ('helping', 'cannot_help'):
        return api_error(message="Phản hồi không hợp lệ", error_code="INVALID_RESPONSE", status=400)
    if inc.status != 'active':
        return api_error(message="SOS đã kết thúc", error_code="SOS_NOT_ACTIVE", status=409)
    n.response = response
    n.responded_at = now
    n.delivery_status = 'responding' if response == 'helping' else 'declined'
    if n.acknowledged_at is None:
        n.acknowledged_at = now
    _audit(inc, user, 'respond', response)
    db.session.commit()
    return api_success(_recipient_view(n, inc, None, cfg))


@api_v1_bp.route('/sos/<event_id>/resolve', methods=['POST'])
@jwt_required()
def sos_resolve(event_id):
    user, cfg, now = request.current_user, get_config(), _now()
    inc = _incident_or_none(event_id)
    if not inc:
        return _not_found()
    if inc.reporter_user_id != user.id:
        return _forbidden()
    if inc.status != 'active':
        return api_success(_reporter_view(inc, cfg), message="SOS đã kết thúc trước đó")
    data = request.get_json(silent=True) or {}
    resolution = data.get('resolution', 'resolved')
    if resolution not in ('resolved', 'cancelled'):
        return api_error(message="Kiểu kết thúc không hợp lệ", error_code="INVALID_RESOLUTION", status=400)
    inc.status = resolution          # 'cancelled' = bao nham; ban ghi KHONG bi xoa
    inc.resolved_at = now
    inc.resolved_by = 'reporter'
    if inc.legacy_sos_id:
        legacy = PassengerSOS.query.get(inc.legacy_sos_id)
        if legacy and legacy.status == 'PENDING':
            legacy.status = 'RESOLVED' if resolution == 'resolved' else 'CANCELLED'
            legacy.resolved_at = now
    _audit(inc, user, 'resolve', resolution)
    db.session.commit()
    return api_success(_reporter_view(inc, cfg), message="Đã kết thúc SOS")


@api_v1_bp.route('/location', methods=['POST'])
@jwt_required()
def update_location():
    """Heartbeat + vi tri (chi khi nguoi dung dong y chia se). Tra ve canh bao dang nham vao thiet bi nay."""
    user, cfg, now = request.current_user, get_config(), _now()
    data = request.get_json(silent=True) or {}
    _purge_old_locations(now, cfg)

    try:
        coords = _parse_coords(data.get('lat'), data.get('lng'))
    except _BadLocation as e:
        return api_error(message=str(e), error_code="INVALID_LOCATION", status=400)
    permission = str(data.get('permission_status') or 'unknown').strip().lower()[:30]

    loc = UserLocation.query.get(user.id)
    throttled = False
    if loc is None:
        loc = UserLocation(user_id=user.id, last_seen_at=now)
        db.session.add(loc)
    elif (now - loc.last_seen_at).total_seconds() < cfg["min_location_interval_seconds"]:
        throttled = True

    if not throttled:
        loc.last_seen_at = now
        loc.sharing_enabled = bool(data.get('sharing', True))
        loc.permission_status = permission
        loc.device_id = _device_id(data)
        if coords and loc.sharing_enabled and permission in GRANTED_PERMISSIONS:
            loc.latitude, loc.longitude = coords
            loc.accuracy_meters = _parse_accuracy(data.get('accuracy'))
            loc.updated_at = now
        else:
            # Khong co quyen / khong chia se / khong co toa do -> xoa vi tri cu, khong suy doan
            loc.latitude = loc.longitude = loc.accuracy_meters = loc.updated_at = None
        token = data.get('fcm_token')
        if isinstance(token, str) and 20 <= len(token) <= 255:
            user.fcm_token = token
        db.session.commit()
        _match_user_to_active_incidents(user, loc, now, cfg)

    return api_success({
        "alerts": _collect_inbox(user, cfg, now),
        "heartbeat_seconds": cfg["heartbeat_seconds"],
        "throttled": throttled,
        "server_time": _iso(now),
    })


@api_v1_bp.route('/location/stop', methods=['POST'])
@jwt_required()
def stop_location_sharing():
    """Tat chia se / dang xuat: xoa vi tri da luu va token push cua thiet bi."""
    user = request.current_user
    UserLocation.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    if (request.get_json(silent=True) or {}).get('clear_token', True):
        user.fcm_token = None
    db.session.commit()
    return api_success({"stopped": True})
