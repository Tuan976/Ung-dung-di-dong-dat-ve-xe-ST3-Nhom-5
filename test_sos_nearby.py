"""
Kiem thu he thong SOS canh bao theo vi tri (Kich ban A-I + bao mat + chong lam dung).
Chay: python test_sos_nearby.py   (dung CSDL SQLite tam, KHONG dong vao bus_booking.db)
"""
import os
import sys
import tempfile
import unittest
from datetime import datetime, timedelta

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

_tmp = os.path.join(tempfile.gettempdir(), 'vexe_sos_test.db')
if os.path.exists(_tmp):
    os.remove(_tmp)
os.environ['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + _tmp.replace('\\', '/')

from app import app                                    # noqa: E402
from extensions import db                              # noqa: E402
from models import (User, SOSIncident, SOSNotification, SOSAuditLog,   # noqa: E402
                    UserLocation, PassengerSOS)
from api.v1.auth import _generate_access_token         # noqa: E402
from api.v1 import sos as sos_mod                      # noqa: E402

BASE = (10.8000, 106.7000)          # vi tri nguoi gap nan A


def off(meters_north=0.0, meters_east=0.0):
    return BASE[0] + meters_north / 111320.0, BASE[1] + meters_east / 111320.0


class SosNearbyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sos_mod.CONFIG_OVERRIDE.update({
            'min_location_interval_seconds': 0,
            'reverse_geocode_enabled': False,
        })
        cls.ctx = app.app_context()
        cls.ctx.push()
        db.create_all()
        cls.client = app.test_client()
        cls.users = {}
        User.query.filter(User.email.like('%@sos.test')).delete()
        db.session.commit()
        for name in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']:
            u = User(name='User ' + name, email=name.lower() + '@sos.test', password='x', phone='09000000' + str(ord(name)))
            db.session.add(u)
        db.session.commit()
        for name in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']:
            u = User.query.filter_by(email=name.lower() + '@sos.test').first()
            tok, _ = _generate_access_token(u)
            cls.users[name] = {'id': u.id, 'h': {'Authorization': 'Bearer ' + tok}}

    @classmethod
    def tearDownClass(cls):
        db.session.remove()
        cls.ctx.pop()

    def setUp(self):
        # moi test bat dau tu trang thai sach cho du lieu SOS
        SOSNotification.query.delete()
        SOSIncident.query.delete()
        PassengerSOS.query.delete()
        UserLocation.query.delete()
        SOSAuditLog.query.delete()
        db.session.commit()

    # --- helpers
    def h(self, who):
        return self.users[who]['h']

    def hb(self, who, pos, acc=20, perm='granted', **extra):
        body = {'permission_status': perm}
        if pos is not None:
            body.update({'lat': pos[0], 'lng': pos[1], 'accuracy': acc})
        body.update(extra)
        return self.client.post('/api/v1/location', json=body, headers=self.h(who))

    def alerts(self, who):
        r = self.client.get('/api/v1/sos/inbox', headers=self.h(who))
        self.assertEqual(r.status_code, 200)
        return r.get_json()['data']['alerts']

    def sos(self, who, pos=BASE, **extra):
        body = dict(extra)
        if pos is not None:
            body.update({'lat': pos[0], 'lng': pos[1], 'accuracy': 12})
        return self.client.post('/api/v1/sos', json=body, headers=self.h(who))

    # ------------------------------------------------------------------ A
    def test_A_nearby_user_receives_realtime_alert(self):
        self.hb('B', off(200))
        r = self.sos('A')
        self.assertEqual(r.status_code, 201)
        d = r.get_json()['data']
        self.assertEqual(d['status'], 'active')
        self.assertEqual(d['delivery']['in_zone_devices'], 1)
        al = self.alerts('B')
        self.assertEqual(len(al), 1)
        a = al[0]
        self.assertEqual(a['event_id'], d['event_id'])
        self.assertEqual(a['title'], 'CẢNH BÁO KHẨN CẤP')
        self.assertIn(a['distance_m'], range(150, 251))          # ~200m, lam tron 50m
        # khong lo thong tin ca nhan cua nguoi gui SOS
        blob = str(a)
        self.assertNotIn('User A', blob)
        self.assertNotIn('a@sos.test', blob)
        self.assertNotIn('09000000', blob)
        # nguoi gui khong tu nhan canh bao cua chinh minh
        self.hb('A', BASE)
        self.assertEqual(self.alerts('A'), [])
        print('[PASS] A: B trong ban kinh nhan canh bao realtime, khong lo thong tin ca nhan, A khong tu nhan')

    # ------------------------------------------------------------------ B
    def test_B_outside_radius_not_notified_and_rings_expand(self):
        self.hb('B', off(200))
        self.hb('C', off(5000))       # 5 km - ngoai moi vong
        self.hb('E', off(800))        # 800 m - thuoc vong 2 (sau 30s)
        d = self.sos('A').get_json()['data']
        self.assertEqual(d['delivery']['in_zone_devices'], 1)   # chi B ngay luc dau
        self.assertEqual(self.alerts('C'), [])
        self.assertEqual(self.alerts('E'), [])
        # gia lap da qua 40s: vong 2 mo (1000m) -> E nhan o lan heartbeat ke tiep, C van khong
        inc = SOSIncident.query.filter_by(event_id=d['event_id']).first()
        inc.created_at = datetime.utcnow() - timedelta(seconds=40)
        db.session.commit()
        self.hb('E', off(800))
        self.hb('C', off(5000))
        self.assertEqual(len(self.alerts('E')), 1)
        self.assertEqual(self.alerts('C'), [])
        # qua 100s: vong 3 (3000m) van khong cham toi C (5 km)
        inc.created_at = datetime.utcnow() - timedelta(seconds=100)
        db.session.commit()
        self.hb('C', off(5000))
        self.assertEqual(self.alerts('C'), [])
        print('[PASS] B: C (5 km) khong nhan canh bao; vong 2 mo rong dung theo thoi gian cho E (800 m)')

    # ------------------------------------------------------------------ C
    def test_C_unreliable_location_is_not_assumed_nearby(self):
        self.hb('D', off(100), acc=500)                         # sai so qua lon
        self.hb('E', off(100), acc=None)                        # khong bao do chinh xac
        self.hb('F', None, perm='denied')                       # tu choi quyen vi tri
        self.hb('G', off(100))                                  # vi tri tot nhung se bi cu
        loc = UserLocation.query.get(self.users['G']['id'])
        loc.updated_at = datetime.utcnow() - timedelta(seconds=600)
        db.session.commit()
        self.hb('H', off(100), sharing=False)                   # khong dong y chia se
        d = self.sos('A').get_json()['data']
        self.assertEqual(d['delivery']['in_zone_devices'], 0)
        for who in 'DEFGH':
            self.assertEqual(self.alerts(who), [], who)
        print('[PASS] C: sai so lon / thieu do chinh xac / tu choi quyen / vi tri cu / khong chia se -> khong bi coi la o gan')

    # ------------------------------------------------------------------ D
    def test_D_reconnect_no_duplicates(self):
        self.hb('B', off(150))
        d = self.sos('A').get_json()['data']
        first = self.alerts('B')
        for _ in range(4):                                      # mat ket noi roi ket noi lai nhieu lan
            self.hb('B', off(150))
            self.alerts('B')
        again = self.alerts('B')
        self.assertEqual(len(first), 1)
        self.assertEqual(len(again), 1)
        self.assertEqual(again[0]['event_id'], d['event_id'])
        self.assertEqual(SOSNotification.query.count(), 1)
        n = SOSNotification.query.first()
        self.assertIsNotNone(n.delivered_at)
        print('[PASS] D: B ket noi lai nhieu lan van chi co 1 canh bao / 1 ban ghi phan phoi')

    # ------------------------------------------------------------------ E
    def test_E_resolve_updates_recipients_and_stops_alerts(self):
        self.hb('B', off(150))
        d = self.sos('A').get_json()['data']
        eid = d['event_id']
        r = self.client.post('/api/v1/sos/%s/resolve' % eid, json={'resolution': 'resolved'}, headers=self.h('A'))
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.get_json()['data']['status'], 'resolved')
        al = self.alerts('B')
        self.assertEqual(al[0]['status'], 'resolved')
        # sau khi ket thuc: khong phan phoi them, khong cho phan hoi
        self.hb('C', off(100))
        self.assertEqual(self.alerts('C'), [])
        rr = self.client.post('/api/v1/sos/%s/respond' % eid, json={'response': 'helping'}, headers=self.h('B'))
        self.assertEqual(rr.status_code, 409)
        rl = self.client.post('/api/v1/sos/%s/location' % eid, json={'lat': BASE[0], 'lng': BASE[1]}, headers=self.h('A'))
        self.assertEqual(rl.status_code, 409)
        # ban ghi KHONG bi xoa (nhat ky giu lai)
        self.assertEqual(SOSIncident.query.filter_by(event_id=eid).count(), 1)
        self.assertGreaterEqual(SOSAuditLog.query.count(), 2)
        # legacy dashboard dong bo
        self.assertEqual(PassengerSOS.query.first().status, 'RESOLVED')
        print('[PASS] E: A ket thuc -> B thay trang thai resolved, khong phat them canh bao, nhat ky duoc giu')

    def test_E2_staff_resolve_closes_incident(self):
        self.hb('B', off(150))
        d = self.sos('A').get_json()['data']
        legacy_id = SOSIncident.query.filter_by(event_id=d['event_id']).first().legacy_sos_id
        r = self.client.post('/api/v1/sos_alerts/%d/resolve' % legacy_id)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.alerts('B')[0]['status'], 'resolved')
        print('[PASS] E2: nhan vien ket thuc o bang dieu khien -> su kien thoi gian thuc cung ket thuc')

    def test_E3_reporter_disconnect_does_not_resolve_and_cancel_keeps_history(self):
        d = self.sos('A').get_json()['data']
        # mat ket noi: khong co heartbeat nao -> su kien van active
        self.assertEqual(SOSIncident.query.filter_by(event_id=d['event_id']).first().status, 'active')
        r = self.client.post('/api/v1/sos/%s/resolve' % d['event_id'], json={'resolution': 'cancelled'}, headers=self.h('A'))
        self.assertEqual(r.get_json()['data']['status'], 'cancelled')
        self.assertEqual(SOSIncident.query.count(), 1)
        print('[PASS] E3: mat ket noi khong tu ket thuc SOS; bao nham -> cancelled, lich su van con')

    # ------------------------------------------------------------------ F
    def test_F_unauthorized_access_rejected(self):
        self.hb('B', off(150))
        d = self.sos('A').get_json()['data']
        eid = d['event_id']
        self.assertEqual(self.client.post('/api/v1/sos', json={'lat': 10.8, 'lng': 106.7}).status_code, 401)
        self.assertEqual(self.client.get('/api/v1/sos/%s' % eid).status_code, 401)
        self.assertEqual(self.client.get('/api/v1/sos/inbox').status_code, 401)
        self.assertEqual(self.client.post('/api/v1/location', json={}).status_code, 401)
        bad = {'Authorization': 'Bearer not.a.token'}
        self.assertEqual(self.client.get('/api/v1/sos/%s' % eid, headers=bad).status_code, 401)
        # C dang nhap nhung KHONG nam trong danh sach nguoi nhan do server xac dinh
        for method, path, body in [
            ('get', '/api/v1/sos/%s' % eid, None),
            ('post', '/api/v1/sos/%s/acknowledge' % eid, {}),
            ('post', '/api/v1/sos/%s/respond' % eid, {'response': 'helping'}),
            ('post', '/api/v1/sos/%s/resolve' % eid, {}),
            ('post', '/api/v1/sos/%s/location' % eid, {'lat': 10.8, 'lng': 106.7}),
        ]:
            fn = getattr(self.client, method)
            r = fn(path, headers=self.h('C')) if body is None else fn(path, json=body, headers=self.h('C'))
            self.assertEqual(r.status_code, 403, path)
        # B (nguoi nhan) khong duoc ket thuc / cap nhat vi tri su kien cua A
        self.assertEqual(self.client.post('/api/v1/sos/%s/resolve' % eid, json={}, headers=self.h('B')).status_code, 403)
        self.assertEqual(self.client.post('/api/v1/sos/%s/location' % eid, json={'lat': 10.8, 'lng': 106.7},
                                          headers=self.h('B')).status_code, 403)
        self.assertEqual(SOSIncident.query.filter_by(event_id=eid).first().status, 'active')
        # id khong ton tai
        self.assertEqual(self.client.get('/api/v1/sos/khong-ton-tai', headers=self.h('A')).status_code, 404)
        # client khong the tu khai bao nguoi nhan
        r = self.client.post('/api/v1/sos', json={'lat': 10.9, 'lng': 106.9, 'recipients': [self.users['C']['id']],
                                                  'recipient_user_ids': [self.users['C']['id']]}, headers=self.h('D'))
        self.assertEqual(r.get_json()['data']['delivery']['in_zone_devices'], 0)
        self.assertEqual(self.alerts('C'), [])
        print('[PASS] F: chua dang nhap / token gia -> 401; nguoi khong lien quan -> 403; client khong tu chon nguoi nhan')

    # ------------------------------------------------------------------ G
    def test_G_location_denied_still_sends_without_fake_coordinates(self):
        self.hb('B', off(100))
        r = self.sos('A', pos=None, incident_type='medical')
        self.assertEqual(r.status_code, 201)
        d = r.get_json()['data']
        self.assertEqual(d['location_status'], 'unknown')
        self.assertIsNone(d['latitude'])
        self.assertIsNone(d['longitude'])
        self.assertEqual(d['delivery']['in_zone_devices'], 0)
        self.assertEqual(self.alerts('B'), [])
        # co vi tri sau do -> bat dau phan phoi
        r2 = self.client.post('/api/v1/sos/%s/location' % d['event_id'],
                              json={'lat': BASE[0], 'lng': BASE[1], 'accuracy': 15}, headers=self.h('A'))
        self.assertEqual(r2.status_code, 200)
        self.assertEqual(r2.get_json()['data']['location_status'], 'known')
        self.assertEqual(len(self.alerts('B')), 1)
        # du lieu vi tri khong hop le bi tu choi, khong bia toa do
        self.assertEqual(self.sos('C', pos=(999, 999)).status_code, 400)
        self.assertEqual(self.sos('C', pos=(0.0, 0.0)).status_code, 400)
        self.assertEqual(self.client.post('/api/v1/sos', json={'lat': 'abc', 'lng': 1}, headers=self.h('C')).status_code, 400)
        print('[PASS] G: tu choi vi tri -> van gui SOS, khong bia toa do; bo sung vi tri sau thi moi phan phoi')

    # ------------------------------------------------------------------ H
    def test_H_two_simultaneous_sos_independent(self):
        self.hb('B', off(100))
        self.hb('C', off(100, 300))
        results = {}
        import threading

        def fire(who, pos):
            with app.test_client() as c:
                results[who] = c.post('/api/v1/sos', json={'lat': pos[0], 'lng': pos[1], 'accuracy': 10},
                                      headers=self.h(who)).get_json()['data']
        t1 = threading.Thread(target=fire, args=('A', BASE))
        t2 = threading.Thread(target=fire, args=('D', off(2500)))     # SOS thu hai o xa
        t1.start(); t2.start(); t1.join(); t2.join()
        self.assertNotEqual(results['A']['event_id'], results['D']['event_id'])
        ba = {a['event_id'] for a in self.alerts('B')}
        self.assertEqual(ba, {results['A']['event_id']})
        self.assertEqual(SOSIncident.query.count(), 2)
        n_a = SOSNotification.query.join(SOSIncident, SOSIncident.id == SOSNotification.incident_id) \
            .filter(SOSIncident.event_id == results['A']['event_id']).count()
        n_d = SOSNotification.query.join(SOSIncident, SOSIncident.id == SOSNotification.incident_id) \
            .filter(SOSIncident.event_id == results['D']['event_id']).count()
        self.assertEqual(n_a, 2)      # B va C
        self.assertEqual(n_d, 0)      # khong ai gan D
        print('[PASS] H: 2 SOS dong thoi co ID va danh sach phan phoi doc lap')

    # ------------------------------------------------------------------ I
    def test_I_multiple_incidents_per_recipient_tracked_separately(self):
        self.hb('B', off(100))
        d1 = self.sos('A').get_json()['data']
        d2 = self.sos('C', pos=off(60, 60)).get_json()['data']
        al = {a['event_id']: a for a in self.alerts('B')}
        self.assertEqual(set(al), {d1['event_id'], d2['event_id']})
        r1 = self.client.post('/api/v1/sos/%s/acknowledge' % d1['event_id'], headers=self.h('B'))
        self.assertEqual(r1.get_json()['data']['my_status'], 'acknowledged')
        r2 = self.client.post('/api/v1/sos/%s/respond' % d2['event_id'], json={'response': 'helping'}, headers=self.h('B'))
        self.assertEqual(r2.get_json()['data']['my_status'], 'responding')
        al = {a['event_id']: a for a in self.alerts('B')}
        self.assertEqual(al[d1['event_id']]['my_status'], 'acknowledged')
        self.assertEqual(al[d2['event_id']]['my_status'], 'responding')
        # nguoi gui chi thay so lieu co bang chung
        v1 = self.client.get('/api/v1/sos/%s' % d1['event_id'], headers=self.h('A')).get_json()['data']
        v2 = self.client.get('/api/v1/sos/%s' % d2['event_id'], headers=self.h('C')).get_json()['data']
        self.assertEqual(v1['delivery']['acknowledged'], 1)
        self.assertEqual(v1['delivery']['responding'], 0)
        self.assertEqual(v2['delivery']['responding'], 1)
        # cap nhat trang thai: khong the tiep tuc ho tro
        r3 = self.client.post('/api/v1/sos/%s/respond' % d2['event_id'], json={'response': 'cannot_help'}, headers=self.h('B'))
        self.assertEqual(r3.get_json()['data']['my_status'], 'declined')
        v2 = self.client.get('/api/v1/sos/%s' % d2['event_id'], headers=self.h('C')).get_json()['data']
        self.assertEqual(v2['delivery']['responding'], 0)
        print('[PASS] I: B nhan 2 su kien khac nhau, trang thai moi su kien doc lap; nguoi gui chi thay so lieu co bang chung')

    # ----------------------------------------------------- bao ve / lam dung
    def test_J_idempotency_and_duplicate_active(self):
        r1 = self.client.post('/api/v1/sos', json={'lat': BASE[0], 'lng': BASE[1]},
                              headers=dict(self.h('A'), **{'Idempotency-Key': 'abc-123'}))
        r2 = self.client.post('/api/v1/sos', json={'lat': BASE[0], 'lng': BASE[1]},
                              headers=dict(self.h('A'), **{'Idempotency-Key': 'abc-123'}))
        r3 = self.client.post('/api/v1/sos', json={'lat': BASE[0], 'lng': BASE[1]}, headers=self.h('A'))
        e1 = r1.get_json()['data']['event_id']
        self.assertEqual(e1, r2.get_json()['data']['event_id'])
        self.assertEqual(e1, r3.get_json()['data']['event_id'])
        self.assertTrue(r2.get_json()['data']['duplicate'])
        self.assertEqual(SOSIncident.query.count(), 1)
        print('[PASS] J: nhan SOS lien tuc / gui lai cung idempotency key khong tao nhieu su kien')

    def test_K_rate_limit_suppresses_distribution_but_never_blocks_sos(self):
        sos_mod.CONFIG_OVERRIDE['max_incidents_per_hour_user'] = 2
        try:
            self.hb('B', off(100))
            for i in range(3):
                r = self.sos('A')
                self.assertEqual(r.status_code, 201)
                eid = r.get_json()['data']['event_id']
                if i < 2:
                    self.client.post('/api/v1/sos/%s/resolve' % eid, json={'resolution': 'cancelled'}, headers=self.h('A'))
            d = r.get_json()['data']
            self.assertTrue(d['distribution_suppressed'])           # SOS thu 3 bi han che phat tan
            self.assertEqual(d['delivery']['in_zone_devices'], 0)
            self.assertEqual(r.status_code, 201)                    # nhung van duoc ghi nhan
        finally:
            sos_mod.CONFIG_OVERRIDE.pop('max_incidents_per_hour_user', None)
        print('[PASS] K: lam dung (nhieu SOS/gio) -> van ghi nhan nhung han che phat tan canh bao lan can')

    def test_L_config_and_privacy_and_expiry(self):
        c = self.client.get('/api/v1/sos/config', headers=self.h('A')).get_json()['data']
        self.assertEqual([r['radius_m'] for r in c['rings']], [500, 1000, 3000])
        # doi ban kinh khong can sua Flutter: chi doi cau hinh
        sos_mod.CONFIG_OVERRIDE['rings'] = [{'ring': 1, 'radius_m': 100, 'delay_s': 0}]
        try:
            self.hb('B', off(200))
            d = self.sos('A').get_json()['data']
            self.assertEqual(d['delivery']['in_zone_devices'], 0)     # 200 m > 100 m
        finally:
            sos_mod.CONFIG_OVERRIDE.pop('rings', None)
        # het han tu dong
        inc = SOSIncident.query.filter_by(event_id=d['event_id']).first()
        inc.created_at = datetime.utcnow() - timedelta(hours=7)
        db.session.commit()
        act = self.client.get('/api/v1/sos/active', headers=self.h('A')).get_json()['data']
        self.assertIsNone(act['incident'])
        self.assertEqual(SOSIncident.query.first().status, 'expired')
        # xoa vi tri khi tat chia se / dang xuat
        self.hb('B', off(200))
        self.assertEqual(UserLocation.query.filter_by(user_id=self.users['B']['id']).count(), 1)
        self.client.post('/api/v1/location/stop', json={}, headers=self.h('B'))
        self.assertEqual(UserLocation.query.filter_by(user_id=self.users['B']['id']).count(), 0)
        print('[PASS] L: ban kinh doi bang cau hinh; SOS het han tu dong; dang xuat xoa vi tri da luu')


if __name__ == '__main__':
    unittest.main(verbosity=1)
