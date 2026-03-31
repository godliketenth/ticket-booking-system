
# routes/events.py
# browse events, get event details, get ticket types for an event
# uses views: vw_AvailableEvents, vw_EventDetails, vw_EventRatings
# uses stored procedure: sp_GetEventTickets

from flask import Blueprint, request, jsonify
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, rows_to_dict, row_to_dict

events_bp = Blueprint('events', __name__)


# GET /api/events
# returns all upcoming events that still have tickets available
# optional query param: ?category=Music  ?city=Mumbai
@events_bp.route('/', methods=['GET'])
def get_available_events():
    category = request.args.get('category')
    city     = request.args.get('city')

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        query  = "SELECT * FROM vw_AvailableEvents WHERE 1=1"
        params = []

        if category:
            query += " AND category_name = ?"
            params.append(category)

        if city:
            query += " AND city_name = ?"
            params.append(city)

        query += " ORDER BY start_datetime ASC"

        cursor.execute(query, *params)
        events = rows_to_dict(cursor)
        conn.close()

        return jsonify(events), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/all
# returns all events regardless of status (for admin/organizer view)
@events_bp.route('/all', methods=['GET'])
def get_all_events():
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM vw_EventDetails ORDER BY start_datetime DESC")
        events = rows_to_dict(cursor)
        conn.close()

        return jsonify(events), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/<event_id>
# returns full details for a single event including ratings
@events_bp.route('/<int:event_id>', methods=['GET'])
def get_event_detail(event_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # get event details from the view
        cursor.execute("SELECT * FROM vw_EventDetails WHERE event_id = ?", event_id)
        event = row_to_dict(cursor)

        if event is None:
            conn.close()
            return jsonify({'error': 'Event not found.'}), 404

        # get rating info
        cursor.execute("SELECT total_reviews, avg_rating FROM vw_EventRatings WHERE event_id = ?", event_id)
        rating = row_to_dict(cursor)
        if rating:
            event['total_reviews'] = rating['total_reviews']
            event['avg_rating']    = float(rating['avg_rating']) if rating['avg_rating'] else None

        conn.close()
        return jsonify(event), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/<event_id>/tickets
# returns all ticket types for an event using the stored procedure
@events_bp.route('/<int:event_id>/tickets', methods=['GET'])
def get_event_tickets(event_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC sp_GetEventTickets @event_id = ?", event_id)
        tickets = rows_to_dict(cursor)
        conn.close()

        return jsonify(tickets), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/categories
# returns all event categories (for filter dropdowns)
@events_bp.route('/categories', methods=['GET'])
def get_categories():
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT category_id, category_name FROM Event_Category ORDER BY category_name")
        categories = rows_to_dict(cursor)
        conn.close()

        return jsonify(categories), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/cities
# returns all cities (for filter dropdowns)
@events_bp.route('/cities', methods=['GET'])
def get_cities():
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT city_id, city_name, state FROM City ORDER BY city_name")
        cities = rows_to_dict(cursor)
        conn.close()

        return jsonify(cities), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/events/<event_id>/revenue
# returns revenue info for an event (for organizer/admin)
@events_bp.route('/<int:event_id>/revenue', methods=['GET'])
def get_event_revenue(event_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM vw_EventRevenue WHERE event_id = ?", event_id)
        revenue = row_to_dict(cursor)
        conn.close()

        if revenue is None:
            return jsonify({'error': 'No revenue data found for this event.'}), 404

        return jsonify(revenue), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
