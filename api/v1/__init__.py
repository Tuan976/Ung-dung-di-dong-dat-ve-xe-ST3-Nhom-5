from flask import Blueprint

api_v1_bp = Blueprint('api_v1', __name__, url_prefix='/api/v1')

# Import routes to register them with the blueprint
from . import auth
from . import trips
from . import bookings
from . import payments
from . import errors
from . import notifications
