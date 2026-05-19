from app import app
from extensions import db
from models import Route

def fix_names():
    mapping = {
        "TP. Ho Chi Minh": "TP. Hồ Chí Minh",
        "Cu Jut": "Cư Jut",
        "Da Lat": "Đà Lạt",
        "Da Nang": "Đà Nẵng",
        "Ha Noi": "Hà Nội",
        "Can Tho": "Cần Thơ",
        "Dak Mil": "Đắk Mil",
        "Dak Doa": "Đắk Đoa",
        "Gia Nghia": "Gia Nghĩa"
    }
    
    with app.app_context():
        print("Starting to unify province names...")
        routes = Route.query.all()
        updated_count = 0
        
        for route in routes:
            changed = False
            if route.start_point in mapping:
                route.start_point = mapping[route.start_point]
                changed = True
            if route.end_point in mapping:
                route.end_point = mapping[route.end_point]
                changed = True
            
            if changed:
                updated_count += 1
        
        db.session.commit()
        print(f"Updated {updated_count} routes with unified names.")
        print("Province names unification completed!")

if __name__ == "__main__":
    fix_names()
