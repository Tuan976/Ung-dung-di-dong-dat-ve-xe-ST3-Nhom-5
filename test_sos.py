from app import app

with app.test_client() as c:
    resp = c.post(
        '/api/v1/sos',
        json={'lat': 10.83, 'lng': 106.72}
    )
    print('Status:', resp.status_code)
    print('Body:', resp.data.decode('utf-8'))
