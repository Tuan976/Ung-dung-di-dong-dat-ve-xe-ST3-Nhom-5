from flask import jsonify, request
from extensions import db
from models import Notification, User
from .decorators import jwt_required
from . import api_v1_bp

@api_v1_bp.route('/notifications', methods=['GET'])
@jwt_required()
def get_notifications():
    current_user = request.current_user
    notifications = Notification.query.filter(
        (Notification.user_id == current_user.id) | (Notification.user_id == None)
    ).order_by(Notification.created_at.desc()).all()
    
    return jsonify([n.to_dict() for n in notifications])

@api_v1_bp.route('/notifications/<int:notification_id>/read', methods=['POST'])
@jwt_required()
def mark_read(notification_id):
    current_user = request.current_user
    notification = Notification.query.get_or_404(notification_id)
    if notification.user_id is not None and notification.user_id != current_user.id:
        return jsonify({'message': 'Unauthorized'}), 403
        
    notification.is_read = True
    db.session.commit()
    
    return jsonify({'message': 'Marked as read'})
