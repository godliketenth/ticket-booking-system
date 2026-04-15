
# routes/admin.py
# admin panel: user management, revenue analytics
# all endpoints require admin role

from flask import Blueprint, request, jsonify, session
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, rows_to_dict, row_to_dict
from config import COMMISSION_RATE

admin_bp = Blueprint('admin', __name__)


def require_admin():
    """Returns user_id if admin, else None."""
    if session.get('role') != 'admin':
        return None
    return session.get('user_id')


# ── GET /api/admin/users ─────────────────────────────────────
# list all users with optional role filter
@admin_bp.route('/users', methods=['GET'])
def get_all_users():
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    role_filter = request.args.get('role', '')

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        query = """
            SELECT user_id, full_name, username, email, role, created_at,
                   ISNULL(is_active, 1) AS is_active
            FROM Users
            WHERE 1=1
        """
        params = []

        if role_filter and role_filter in ('customer', 'organizer', 'admin'):
            query += " AND role = ?"
            params.append(role_filter)

        query += " ORDER BY created_at DESC"

        if params:
            cursor.execute(query, *params)
        else:
            cursor.execute(query)

        users = rows_to_dict(cursor)
        conn.close()

        for u in users:
            if u.get('created_at') and hasattr(u['created_at'], 'isoformat'):
                u['created_at'] = u['created_at'].isoformat()

        return jsonify(users), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── DELETE /api/admin/users/<id> ─────────────────────────────
# soft delete a user (set is_active = 0)
@admin_bp.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    # prevent self-deletion
    if user_id == uid:
        return jsonify({'error': 'You cannot deactivate your own account.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check user exists
        cursor.execute("SELECT user_id, role, is_active FROM Users WHERE user_id = ?", user_id)
        row = cursor.fetchone()

        if not row:
            conn.close()
            return jsonify({'error': 'User not found.'}), 404

        if row[2] == 0:
            conn.close()
            return jsonify({'error': 'User is already deactivated.'}), 400

        # soft delete
        cursor.execute("UPDATE Users SET is_active = 0 WHERE user_id = ?", user_id)
        conn.commit()
        conn.close()

        return jsonify({'message': 'User deactivated successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── PUT /api/admin/users/<id>/activate ───────────────────────
# reactivate a soft-deleted user
@admin_bp.route('/users/<int:user_id>/activate', methods=['PUT'])
def activate_user(user_id):
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("UPDATE Users SET is_active = 1 WHERE user_id = ?", user_id)
        conn.commit()
        conn.close()

        return jsonify({'message': 'User activated successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/admin/analytics/revenue ─────────────────────────
# revenue breakdown: monthly, quarterly, yearly
@admin_bp.route('/analytics/revenue', methods=['GET'])
def analytics_revenue():
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    period = request.args.get('period', 'monthly')  # monthly, quarterly, yearly
    commission_rate = COMMISSION_RATE

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        if period == 'yearly':
            cursor.execute("""
                SELECT
                    rev_year,
                    SUM(total_bookings) AS total_bookings,
                    SUM(total_revenue)  AS total_revenue
                FROM vw_MonthlyRevenue
                GROUP BY rev_year
                ORDER BY rev_year DESC
            """)
        elif period == 'quarterly':
            cursor.execute("""
                SELECT
                    rev_year,
                    rev_quarter,
                    SUM(total_bookings) AS total_bookings,
                    SUM(total_revenue)  AS total_revenue
                FROM vw_MonthlyRevenue
                GROUP BY rev_year, rev_quarter
                ORDER BY rev_year DESC, rev_quarter DESC
            """)
        else:
            cursor.execute("""
                SELECT
                    rev_year,
                    rev_month,
                    SUM(total_bookings) AS total_bookings,
                    SUM(total_revenue)  AS total_revenue
                FROM vw_MonthlyRevenue
                GROUP BY rev_year, rev_month
                ORDER BY rev_year DESC, rev_month DESC
            """)

        rows = rows_to_dict(cursor)
        conn.close()

        for r in rows:
            rev = float(r.get('total_revenue', 0))
            r['total_revenue']      = rev
            r['admin_profit']       = round(rev * commission_rate / 100, 2)
            r['organizer_earnings'] = round(rev - r['admin_profit'], 2)

        return jsonify({
            'period':          period,
            'commission_rate': commission_rate,
            'data':            rows
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/admin/analytics/trends ──────────────────────────
# sales trends, popular categories, revenue by city
@admin_bp.route('/analytics/trends', methods=['GET'])
def analytics_trends():
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    commission_rate = COMMISSION_RATE

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # revenue by category
        cursor.execute("""
            SELECT
                category_name,
                SUM(total_bookings) AS total_bookings,
                SUM(total_revenue)  AS total_revenue
            FROM vw_MonthlyRevenue
            GROUP BY category_name
            ORDER BY total_revenue DESC
        """)
        by_category = rows_to_dict(cursor)

        # revenue by city
        cursor.execute("""
            SELECT
                city_name,
                SUM(total_bookings) AS total_bookings,
                SUM(total_revenue)  AS total_revenue
            FROM vw_MonthlyRevenue
            GROUP BY city_name
            ORDER BY total_revenue DESC
        """)
        by_city = rows_to_dict(cursor)

        # monthly sales trend (last 12 months)
        cursor.execute("""
            SELECT
                rev_year,
                rev_month,
                SUM(total_bookings) AS total_bookings,
                SUM(total_revenue)  AS total_revenue
            FROM vw_MonthlyRevenue
            GROUP BY rev_year, rev_month
            ORDER BY rev_year ASC, rev_month ASC
        """)
        monthly_trend = rows_to_dict(cursor)

        # overall totals
        cursor.execute("""
            SELECT
                ISNULL(SUM(total_bookings), 0) AS total_bookings,
                ISNULL(SUM(total_revenue), 0)  AS total_revenue
            FROM vw_MonthlyRevenue
        """)
        totals = row_to_dict(cursor)

        conn.close()

        # convert decimals
        for lst in [by_category, by_city, monthly_trend]:
            for r in lst:
                for k, v in r.items():
                    if v is not None and 'Decimal' in str(type(v)):
                        r[k] = float(v)

        total_rev = float(totals['total_revenue']) if totals else 0
        admin_profit = round(total_rev * commission_rate / 100, 2)

        return jsonify({
            'commission_rate':    commission_rate,
            'total_revenue':     total_rev,
            'total_bookings':    totals['total_bookings'] if totals else 0,
            'admin_profit':      admin_profit,
            'organizer_earnings': round(total_rev - admin_profit, 2),
            'by_category':       by_category,
            'by_city':           by_city,
            'monthly_trend':     monthly_trend
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/admin/analytics/organizers ──────────────────────
# revenue grouped by organizer
@admin_bp.route('/analytics/organizers', methods=['GET'])
def analytics_organizers():
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    commission_rate = COMMISSION_RATE

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT
                organiser_id,
                organizer_name,
                SUM(total_bookings) AS total_bookings,
                SUM(total_revenue)  AS total_revenue
            FROM vw_MonthlyRevenue
            GROUP BY organiser_id, organizer_name
            ORDER BY total_revenue DESC
        """)
        organizers = rows_to_dict(cursor)
        conn.close()

        for o in organizers:
            rev = float(o.get('total_revenue', 0))
            o['total_revenue']      = rev
            o['admin_profit']       = round(rev * commission_rate / 100, 2)
            o['organizer_earnings'] = round(rev - o['admin_profit'], 2)

        return jsonify({
            'commission_rate': commission_rate,
            'organizers':      organizers
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ── GET /api/admin/settings ─────────────────────────────────
@admin_bp.route('/settings', methods=['GET'])
def get_settings():
    uid = require_admin()
    if not uid:
        return jsonify({'error': 'Admin access required.'}), 403

    return jsonify({
        'commission_rate': COMMISSION_RATE
    }), 200
