
# routes/organizer.py
# organizer dashboard: create/edit/delete events, view stats,
# attendees, earnings, payouts
# all endpoints require organizer role

from flask import Blueprint, request, jsonify, session
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, rows_to_dict, row_to_dict

organizer_bp = Blueprint('organizer', __name__)


def require_organizer():
    """Returns user_id if organizer, else None."""
    if session.get('role') != 'organizer':
        return None
    return session.get('user_id')


# ── GET /api/organizer/dashboard ─────────────────────────────
# summary stats for the organizer home screen
@organizer_bp.route('/dashboard', methods=['GET'])
def organizer_dashboard():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # total events
        cursor.execute("SELECT COUNT(*) FROM Event WHERE organiser_id = ?", uid)
        total_events = cursor.fetchone()[0]

        # total tickets sold & revenue from view
        cursor.execute("""
            SELECT
                ISNULL(SUM(tickets_sold), 0),
                ISNULL(SUM(total_revenue), 0)
            FROM vw_OrganizerEventStats
            WHERE organiser_id = ?
        """, uid)
        row = cursor.fetchone()
        total_sold    = row[0]
        total_revenue = float(row[1])

        # commission rate
        cursor.execute("SELECT setting_value FROM Platform_Settings WHERE setting_key = 'commission_rate'")
        cr = cursor.fetchone()
        commission_rate = float(cr[0]) if cr else 10.0

        commission = total_revenue * commission_rate / 100
        net_earnings = total_revenue - commission

        # pending payouts
        cursor.execute("""
            SELECT ISNULL(SUM(amount), 0) FROM Payout_Request
            WHERE organizer_id = ? AND status = 'pending'
        """, uid)
        pending_payouts = float(cursor.fetchone()[0])

        # total paid out
        cursor.execute("""
            SELECT ISNULL(SUM(amount), 0) FROM Payout_Request
            WHERE organizer_id = ? AND status = 'paid'
        """, uid)
        total_paid_out = float(cursor.fetchone()[0])

        conn.close()

        return jsonify({
            'total_events':    total_events,
            'total_sold':      total_sold,
            'total_revenue':   total_revenue,
            'commission_rate': commission_rate,
            'commission':      commission,
            'net_earnings':    net_earnings,
            'pending_payouts': pending_payouts,
            'total_paid_out':  total_paid_out
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/events ────────────────────────────────
# list all events created by this organizer
@organizer_bp.route('/events', methods=['GET'])
def get_organizer_events():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT *
            FROM vw_OrganizerEventStats
            WHERE organiser_id = ?
            ORDER BY start_datetime DESC
        """, uid)
        events = rows_to_dict(cursor)
        conn.close()

        for e in events:
            for k, v in e.items():
                if hasattr(v, 'isoformat'):
                    e[k] = v.isoformat()
                if v is not None and 'Decimal' in str(type(v)):
                    e[k] = float(v)

        return jsonify(events), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── POST /api/organizer/events/create ────────────────────────
# create a new event + ticket types
@organizer_bp.route('/events/create', methods=['POST'])
def create_event():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    data = request.get_json()

    title          = data.get('title', '').strip()
    description    = data.get('description', '').strip()
    start_str      = data.get('start_datetime')
    end_str        = data.get('end_datetime')
    image_url      = data.get('image_url', '').strip() or None
    ticket_types   = data.get('ticket_types', [])

    # safely convert venue_id and category_id to int
    try:
        venue_id = int(data.get('venue_id', 0))
    except (TypeError, ValueError):
        venue_id = 0

    try:
        category_id = int(data.get('category_id', 0))
    except (TypeError, ValueError):
        category_id = 0

    if not title or not start_str or not end_str or not venue_id or not category_id:
        return jsonify({'error': 'Title, dates, venue and category are required.'}), 400

    if not ticket_types or len(ticket_types) == 0:
        return jsonify({'error': 'At least one ticket type is required.'}), 400

    # parse datetime strings from HTML datetime-local input (e.g. "2026-04-20T18:00")
    from datetime import datetime as dt
    try:
        start_datetime = dt.fromisoformat(start_str)
        end_datetime   = dt.fromisoformat(end_str)
    except (ValueError, TypeError):
        return jsonify({'error': 'Invalid date format. Use the date picker.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # create the event via stored procedure
        cursor.execute("""
            EXEC sp_CreateEvent
                @organiser_id   = ?,
                @title          = ?,
                @description    = ?,
                @start_datetime = ?,
                @end_datetime   = ?,
                @venue_id       = ?,
                @category_id    = ?,
                @image_url      = ?
        """, uid, title, description, start_datetime, end_datetime,
             venue_id, category_id, image_url)

        result = row_to_dict(cursor)

        if result and 'error_message' in result:
            conn.close()
            return jsonify({'error': result['error_message']}), 400

        event_id = result['new_event_id']

        # insert ticket types
        for tt in ticket_types:
            tt_name = tt.get('type_name', '').strip()
            tt_price = tt.get('price', 0)
            tt_qty   = tt.get('quantity', 0)

            if not tt_name or tt_price < 0 or tt_qty <= 0:
                continue

            cursor.execute("""
                INSERT INTO Ticket_Type (type_name, price, total_quantity, available_quantity, event_id)
                VALUES (?, ?, ?, ?, ?)
            """, tt_name, tt_price, tt_qty, tt_qty, event_id)

        conn.commit()
        conn.close()

        return jsonify({
            'message':  'Event created successfully.',
            'event_id': event_id
        }), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── PUT /api/organizer/events/<id> ───────────────────────────
# edit event details (only if owned by this organizer)
@organizer_bp.route('/events/<int:event_id>', methods=['PUT'])
def edit_event(event_id):
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    data = request.get_json()

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # verify ownership
        cursor.execute("SELECT organiser_id FROM Event WHERE event_id = ?", event_id)
        row = cursor.fetchone()
        if not row or row[0] != uid:
            conn.close()
            return jsonify({'error': 'Event not found or access denied.'}), 403

        # build dynamic update
        fields = []
        params = []

        for col, key in [
            ('title', 'title'), ('description', 'description'),
            ('start_datetime', 'start_datetime'), ('end_datetime', 'end_datetime'),
            ('venue_id', 'venue_id'), ('category_id', 'category_id'),
            ('image_url', 'image_url'), ('status', 'status')
        ]:
            if key in data:
                fields.append(f"{col} = ?")
                params.append(data[key])

        if not fields:
            conn.close()
            return jsonify({'error': 'No fields to update.'}), 400

        params.append(event_id)
        cursor.execute(
            f"UPDATE Event SET {', '.join(fields)} WHERE event_id = ?",
            *params
        )
        conn.commit()
        conn.close()

        return jsonify({'message': 'Event updated successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── DELETE /api/organizer/events/<id> ────────────────────────
# delete event only if no bookings exist
@organizer_bp.route('/events/<int:event_id>', methods=['DELETE'])
def delete_event(event_id):
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("EXEC sp_DeleteEvent @event_id = ?, @organiser_id = ?", event_id, uid)
        result = row_to_dict(cursor)
        conn.commit()
        conn.close()

        if result and 'error_message' in result:
            return jsonify({'error': result['error_message']}), 400

        return jsonify({'message': 'Event deleted successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/events/<id>/stats ─────────────────────
# per-event statistics
@organizer_bp.route('/events/<int:event_id>/stats', methods=['GET'])
def event_stats(event_id):
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT * FROM vw_OrganizerEventStats
            WHERE event_id = ? AND organiser_id = ?
        """, event_id, uid)
        stats = row_to_dict(cursor)

        if not stats:
            conn.close()
            return jsonify({'error': 'Event not found.'}), 404

        # commission
        cursor.execute("SELECT setting_value FROM Platform_Settings WHERE setting_key = 'commission_rate'")
        cr = cursor.fetchone()
        commission_rate = float(cr[0]) if cr else 10.0

        conn.close()

        for k, v in stats.items():
            if hasattr(v, 'isoformat'):
                stats[k] = v.isoformat()
            if v is not None and 'Decimal' in str(type(v)):
                stats[k] = float(v)

        revenue = stats.get('total_revenue', 0)
        stats['commission_rate'] = commission_rate
        stats['commission']     = revenue * commission_rate / 100
        stats['net_earnings']   = revenue - stats['commission']

        return jsonify(stats), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/events/<id>/attendees ─────────────────
# list of people who booked this event
@organizer_bp.route('/events/<int:event_id>/attendees', methods=['GET'])
def event_attendees(event_id):
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # verify ownership
        cursor.execute("SELECT organiser_id FROM Event WHERE event_id = ?", event_id)
        row = cursor.fetchone()
        if not row or row[0] != uid:
            conn.close()
            return jsonify({'error': 'Event not found or access denied.'}), 403

        cursor.execute("""
            SELECT * FROM vw_EventAttendees
            WHERE event_id = ?
            ORDER BY booking_datetime DESC
        """, event_id)
        attendees = rows_to_dict(cursor)
        conn.close()

        for a in attendees:
            for k, v in a.items():
                if hasattr(v, 'isoformat'):
                    a[k] = v.isoformat()
                if v is not None and 'Decimal' in str(type(v)):
                    a[k] = float(v)

        return jsonify(attendees), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/earnings ──────────────────────────────
# total earnings with commission breakdown
@organizer_bp.route('/earnings', methods=['GET'])
def get_earnings():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # per-event earnings
        cursor.execute("""
            SELECT event_id, title, total_revenue, tickets_sold, total_seats
            FROM vw_OrganizerEventStats
            WHERE organiser_id = ?
            ORDER BY total_revenue DESC
        """, uid)
        events = rows_to_dict(cursor)

        # commission rate
        cursor.execute("SELECT setting_value FROM Platform_Settings WHERE setting_key = 'commission_rate'")
        cr = cursor.fetchone()
        commission_rate = float(cr[0]) if cr else 10.0

        conn.close()

        total_revenue  = 0
        for e in events:
            rev = float(e.get('total_revenue', 0))
            e['total_revenue'] = rev
            e['commission']    = rev * commission_rate / 100
            e['net_earnings']  = rev - e['commission']
            total_revenue += rev

        return jsonify({
            'commission_rate': commission_rate,
            'total_revenue':   total_revenue,
            'total_commission': total_revenue * commission_rate / 100,
            'net_earnings':    total_revenue * (1 - commission_rate / 100),
            'events':          events
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── POST /api/organizer/payouts/request ──────────────────────
@organizer_bp.route('/payouts/request', methods=['POST'])
def request_payout():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    data   = request.get_json()
    amount = data.get('amount', 0)

    if amount <= 0:
        return jsonify({'error': 'Amount must be greater than 0.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check if they have enough earnings
        cursor.execute("""
            SELECT ISNULL(SUM(total_revenue), 0)
            FROM vw_OrganizerEventStats WHERE organiser_id = ?
        """, uid)
        total_revenue = float(cursor.fetchone()[0])

        cursor.execute("SELECT setting_value FROM Platform_Settings WHERE setting_key = 'commission_rate'")
        cr = cursor.fetchone()
        commission_rate = float(cr[0]) if cr else 10.0
        net_earnings = total_revenue * (1 - commission_rate / 100)

        # subtract already paid/pending payouts
        cursor.execute("""
            SELECT ISNULL(SUM(amount), 0) FROM Payout_Request
            WHERE organizer_id = ? AND status IN ('pending', 'paid')
        """, uid)
        already_requested = float(cursor.fetchone()[0])

        available = net_earnings - already_requested
        if amount > available:
            conn.close()
            return jsonify({'error': f'Insufficient balance. Available: ₹{available:,.2f}'}), 400

        cursor.execute("""
            INSERT INTO Payout_Request (organizer_id, amount, status)
            VALUES (?, ?, 'pending')
        """, uid, amount)
        conn.commit()
        conn.close()

        return jsonify({'message': 'Payout request submitted successfully.'}), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/payouts ───────────────────────────────
@organizer_bp.route('/payouts', methods=['GET'])
def get_payouts():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT payout_id, amount, status, requested_at, paid_at, notes
            FROM Payout_Request
            WHERE organizer_id = ?
            ORDER BY requested_at DESC
        """, uid)
        payouts = rows_to_dict(cursor)
        conn.close()

        for p in payouts:
            for k, v in p.items():
                if hasattr(v, 'isoformat'):
                    p[k] = v.isoformat()
                if v is not None and 'Decimal' in str(type(v)):
                    p[k] = float(v)

        return jsonify(payouts), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/organizer/venues ────────────────────────────────
# list all venues (for create event dropdown)
@organizer_bp.route('/venues', methods=['GET'])
def get_venues():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT v.venue_id, v.venue_name, v.address, v.venue_type, v.capacity,
                   c.city_id, c.city_name, c.state
            FROM Venue v
            JOIN City c ON v.city_id = c.city_id
            ORDER BY c.city_name, v.venue_name
        """)
        venues = rows_to_dict(cursor)
        conn.close()

        return jsonify(venues), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── POST /api/organizer/venues/create ────────────────────────
# add a new venue (persisted to DB)
@organizer_bp.route('/venues/create', methods=['POST'])
def create_venue():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    data = request.get_json()

    venue_name = data.get('venue_name', '').strip()
    address    = data.get('address', '').strip()
    venue_type = data.get('venue_type', '').strip()

    # safely convert capacity and city_id to int
    try:
        capacity = int(data.get('capacity', 0))
    except (TypeError, ValueError):
        capacity = 0

    try:
        city_id = int(data.get('city_id', 0))
    except (TypeError, ValueError):
        city_id = 0

    if not venue_name or not address or not venue_type or capacity <= 0 or city_id <= 0:
        return jsonify({'error': 'All venue fields are required.'}), 400

    valid_types = ('stadium', 'theatre', 'auditorium', 'open-air', 'hall', 'arena', 'other')
    if venue_type not in valid_types:
        return jsonify({'error': f'venue_type must be one of: {", ".join(valid_types)}'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SET NOCOUNT ON")

        cursor.execute("""
            INSERT INTO Venue (venue_name, address, venue_type, capacity, city_id)
            VALUES (?, ?, ?, ?, ?)
        """, venue_name, address, venue_type, capacity, city_id)

        cursor.execute("SELECT @@IDENTITY AS new_id")
        row = cursor.fetchone()
        new_id = int(row[0]) if row and row[0] is not None else None

        conn.commit()
        conn.close()

        if new_id is None:
            return jsonify({'error': 'Venue was created but could not retrieve its ID.'}), 500

        return jsonify({
            'message':  'Venue created successfully.',
            'venue_id': new_id
        }), 201

    except Exception as e:
        import traceback
        print(f"[VENUE CREATE ERROR] data={data}, error={e}")
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ── POST /api/organizer/cities/create ────────────────────────
# add a new city (persisted to DB)
@organizer_bp.route('/cities/create', methods=['POST'])
def create_city():
    uid = require_organizer()
    if not uid:
        return jsonify({'error': 'Organizer access required.'}), 403

    data = request.get_json()

    city_name = data.get('city_name', '').strip()
    state     = data.get('state', '').strip()

    if not city_name or not state:
        return jsonify({'error': 'Both city_name and state are required.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check if it already exists
        cursor.execute("SELECT city_id FROM City WHERE city_name = ? AND state = ?", city_name, state)
        existing = cursor.fetchone()
        if existing:
            conn.close()
            return jsonify({'message': 'City already exists.', 'city_id': existing[0]}), 200

        cursor.execute("SET NOCOUNT ON")

        cursor.execute("""
            INSERT INTO City (city_name, state)
            VALUES (?, ?)
        """, city_name, state)

        cursor.execute("SELECT @@IDENTITY AS new_id")
        row = cursor.fetchone()
        new_id = int(row[0]) if row and row[0] is not None else None

        conn.commit()
        conn.close()

        if new_id is None:
            return jsonify({'error': 'City was created but could not retrieve its ID.'}), 500

        return jsonify({
            'message':  'City created successfully.',
            'city_id': new_id
        }), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500
