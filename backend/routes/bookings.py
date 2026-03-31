
# routes/bookings.py
# create a booking, view booking history, cancel a booking
# uses stored procedures: sp_CreateBooking, sp_CancelBooking, sp_GetUserBookings

from flask import Blueprint, request, jsonify, session
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, rows_to_dict, row_to_dict

bookings_bp = Blueprint('bookings', __name__)


def login_required():
    """Helper to check if user is logged in. Returns user_id or None."""
    return session.get('user_id')


# POST /api/bookings/create
# creates a new booking using the stored procedure
# body: { event_id, ticket_type_id, quantity }
# user_id is taken from the session
@bookings_bp.route('/create', methods=['POST'])
def create_booking():
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required to book tickets.'}), 401

    data = request.get_json()

    event_id       = data.get('event_id')
    ticket_type_id = data.get('ticket_type_id')
    quantity       = data.get('quantity')

    if not event_id or not ticket_type_id or not quantity:
        return jsonify({'error': 'event_id, ticket_type_id and quantity are required.'}), 400

    if quantity <= 0:
        return jsonify({'error': 'Quantity must be at least 1.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            EXEC sp_CreateBooking
                @user_id        = ?,
                @event_id       = ?,
                @ticket_type_id = ?,
                @quantity       = ?
            """,
            user_id, event_id, ticket_type_id, quantity
        )

        result = row_to_dict(cursor)
        conn.commit()
        conn.close()

        # sp returns either new_booking_id or error_message
        if result and 'error_message' in result:
            return jsonify({'error': result['error_message']}), 400

        return jsonify({
            'message':       'Booking created successfully.',
            'booking_id':    result['new_booking_id'],
            'total_amt':     float(result['total_amt'])
        }), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/bookings/my
# returns all bookings for the currently logged-in user
@bookings_bp.route('/my', methods=['GET'])
def get_my_bookings():
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC sp_GetUserBookings @user_id = ?", user_id)
        bookings = rows_to_dict(cursor)
        conn.close()

        # convert datetime objects to strings for json
        for b in bookings:
            for key, val in b.items():
                if hasattr(val, 'isoformat'):
                    b[key] = val.isoformat()
                if val is not None and hasattr(val, '__float__'):
                    try:
                        b[key] = float(val)
                    except Exception:
                        pass

        return jsonify(bookings), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/bookings/<booking_id>
# returns details for a single booking
# the booking must belong to the logged-in user (or user is admin)
@bookings_bp.route('/<int:booking_id>', methods=['GET'])
def get_booking_detail(booking_id):
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM vw_BookingSummary WHERE booking_id = ?", booking_id)
        booking = row_to_dict(cursor)
        conn.close()

        if booking is None:
            return jsonify({'error': 'Booking not found.'}), 404

        # security: only the booking owner or admin can view it
        cursor2 = get_connection().cursor()
        cursor2.execute("SELECT user_id FROM Booking WHERE booking_id = ?", booking_id)
        row = cursor2.fetchone()
        cursor2.connection.close()

        if row and row[0] != user_id and session.get('role') != 'admin':
            return jsonify({'error': 'Access denied.'}), 403

        # convert types for json
        for key, val in booking.items():
            if hasattr(val, 'isoformat'):
                booking[key] = val.isoformat()
            if val is not None:
                try:
                    if isinstance(val, float) or (hasattr(val, '__class__') and 'Decimal' in str(type(val))):
                        booking[key] = float(val)
                except Exception:
                    pass

        return jsonify(booking), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# POST /api/bookings/<booking_id>/cancel
# cancels a booking and restores ticket inventory
# uses sp_CancelBooking
@bookings_bp.route('/<int:booking_id>/cancel', methods=['POST'])
def cancel_booking(booking_id):
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # verify the booking belongs to this user
        cursor.execute("SELECT user_id, booking_status FROM Booking WHERE booking_id = ?", booking_id)
        row = cursor.fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Booking not found.'}), 404

        booking_user_id, current_status = row

        if booking_user_id != user_id and session.get('role') != 'admin':
            conn.close()
            return jsonify({'error': 'Access denied.'}), 403

        # call cancel procedure
        cursor.execute("EXEC sp_CancelBooking @booking_id = ?", booking_id)
        result = row_to_dict(cursor)
        conn.commit()
        conn.close()

        if result and 'error_message' in result:
            return jsonify({'error': result['error_message']}), 400

        return jsonify({'message': 'Booking cancelled successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/bookings/summary
# returns all bookings (admin only, uses vw_BookingSummary)
@bookings_bp.route('/summary', methods=['GET'])
def get_all_bookings():
    if session.get('role') != 'admin':
        return jsonify({'error': 'Admin access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM vw_BookingSummary ORDER BY booking_datetime DESC")
        bookings = rows_to_dict(cursor)
        conn.close()

        for b in bookings:
            for key, val in b.items():
                if hasattr(val, 'isoformat'):
                    b[key] = val.isoformat()
                if val is not None:
                    try:
                        if 'Decimal' in str(type(val)):
                            b[key] = float(val)
                    except Exception:
                        pass

        return jsonify(bookings), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
