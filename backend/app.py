
# app.py
# flask app entry point
# serves both API routes (JSON) and HTML pages via Jinja2
# registers all route blueprints and starts the server

import os
from flask import Flask, render_template, session, jsonify
from flask_cors import CORS

from routes.auth         import auth_bp
from routes.events       import events_bp
from routes.bookings     import bookings_bp
from routes.payments     import payments_bp
from routes.reviews      import reviews_bp
from routes.sql_explorer import sql_explorer_bp

# resolve absolute paths for template and static directories
BASE_DIR     = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(BASE_DIR, '..', 'frontend')
STATIC_DIR   = os.path.join(BASE_DIR, '..', 'frontend', 'static')

app = Flask(
    __name__,
    template_folder=TEMPLATE_DIR,
    static_folder=STATIC_DIR
)
app.secret_key = 'tbs_secret_key_change_in_production'

# enable CORS with credentials so session cookies work across origins
CORS(app, supports_credentials=True)

# ── API Blueprints ───────────────────────────────────────────
app.register_blueprint(auth_bp,          url_prefix='/api/auth')
app.register_blueprint(events_bp,        url_prefix='/api/events')
app.register_blueprint(bookings_bp,      url_prefix='/api/bookings')
app.register_blueprint(payments_bp,      url_prefix='/api/payments')
app.register_blueprint(reviews_bp,       url_prefix='/api/reviews')
app.register_blueprint(sql_explorer_bp,  url_prefix='/api/sql-explorer')


# ── Page Routes (Jinja2 Templates) ──────────────────────────

@app.route('/')
def index():
    """Root redirects to events listing."""
    return render_template('events.html')


@app.route('/events.html')
def events_page():
    return render_template('events.html')


@app.route('/event-detail.html')
def event_detail_page():
    return render_template('event-detail.html')


@app.route('/login.html')
def login_page():
    return render_template('login.html')


@app.route('/register.html')
def register_page():
    return render_template('register.html')


@app.route('/dashboard.html')
def dashboard_page():
    """
    Dashboard page — renders with server-side stats if user is logged in.
    Stats are pre-fetched from the database so the page loads with real
    numbers immediately, then JS refreshes them via API calls.
    """
    stats = None
    user_id = session.get('user_id')

    if user_id:
        try:
            from models.db import get_connection
            conn   = get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                SELECT
                    COUNT(*)                                                                    AS total,
                    SUM(CASE WHEN booking_status = 'confirmed' THEN 1 ELSE 0 END)               AS confirmed,
                    SUM(CASE WHEN booking_status = 'pending'   THEN 1 ELSE 0 END)               AS pending,
                    ISNULL(SUM(CASE WHEN booking_status = 'confirmed' THEN total_amt ELSE 0 END), 0) AS spent
                FROM Booking
                WHERE user_id = ?
            """, user_id)

            row = cursor.fetchone()
            conn.close()

            if row:
                spent = float(row[3])
                stats = {
                    'total':         row[0],
                    'confirmed':     row[1],
                    'pending':       row[2],
                    'spent':         spent,
                    'spent_display': '₹{:,.0f}'.format(spent)
                }
        except Exception:
            stats = None

    return render_template('dashboard.html', stats=stats)


@app.route('/admin.html')
def admin_page():
    return render_template('admin.html')


@app.route('/sql-explorer.html')
def sql_explorer_page():
    return render_template('sql-explorer.html')


# ── API Health Check ─────────────────────────────────────────

@app.route('/api')
def api_health():
    return jsonify({'message': 'Ticket Booking System API is running.'}), 200


if __name__ == '__main__':
    app.run(debug=True, port=5000)
