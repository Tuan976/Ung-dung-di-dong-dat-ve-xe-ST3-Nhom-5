import json
from datetime import timedelta


def timedelta_hours_filter(dt, hours):
    """Usage: {{ some_datetime | timedelta_hours(6.5) }}"""
    return dt + timedelta(hours=float(hours))


def from_json(value):
    return json.loads(value)


def timedelta_hours_jinja(dt, hours):
    """Cộng thêm số giờ vào datetime. Dùng: {{ departure_time | timedelta_hours(6.5) }}"""
    return dt + timedelta(hours=float(hours))
