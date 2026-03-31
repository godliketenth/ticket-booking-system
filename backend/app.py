
# app.py
# flask app entry point
# registers all route blueprints and starts the server

from flask import Flask
from flask_cors import CORS

from routes.auth     import auth_bp
from routes.events   import events_bp
from routes.bookings import bookings_bp
from routes.payments import payments_bp
from routes.reviews  import reviews_bp

app = Flask(__name__)
app.secret_key = 'tbs_secret_key_change_in_production'

CORS(app)

# register blueprints with url prefixes
app.register_blueprint(auth_bp,     url_prefix='/api/auth')
app.register_blueprint(events_bp,   url_prefix='/api/events')
app.register_blueprint(bookings_bp, url_prefix='/api/bookings')
app.register_blueprint(payments_bp, url_prefix='/api/payments')
app.register_blueprint(reviews_bp,  url_prefix='/api/reviews')


@app.route('/')
def index():
    return {'message': 'Ticket Booking System API is running.'}, 200


if __name__ == '__main__':
    app.run(debug=True, port=5000)
