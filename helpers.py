import json
from datetime import timedelta
import urllib.request
import urllib.error

import os

def send_resend_email(to_email, subject, html_content):
    url = 'https://api.resend.com/emails'
    api_key = os.environ.get('RESEND_API_KEY', 'your_resend_api_key_here')
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    }
    data = {
        'from': 'Hutech Bus <noreply@atools.id.vn>',
        'to': to_email,
        'subject': subject,
        'html': html_content
    }
    req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return True, response.read().decode()
    except Exception as e:
        return False, str(e)


def timedelta_hours_filter(dt, hours):
    """Usage: {{ some_datetime | timedelta_hours(6.5) }}"""
    return dt + timedelta(hours=float(hours))


def from_json(value):
    return json.loads(value)


def timedelta_hours_jinja(dt, hours):
    """Cộng thêm số giờ vào datetime. Dùng: {{ departure_time | timedelta_hours(6.5) }}"""
    return dt + timedelta(hours=float(hours))
