
# routes/payments.py
# confirm payment for a booking
# uses stored procedure: sp_ConfirmPayment

from flask import Blueprint, request, jsonify, session
import sys
import os
import uuid

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, row_to_dict, rows_to_dict

payments_bp = Blueprint('payments', __name__)


def login_required():
    return session.get('user_id')


# POST /api/payments/confirm
# confirms payment for a pending booking
# body: { booking_id, payment_method }
# payment_method: 'upi' | 'credit_card' | 'debit_card' | 'net_banking' | 'wallet' | 'cash'
# transaction_ref is auto-generated here (in a real app this would come from a payment gateway)
@payments_bp.route('/confirm', methods=['POST'])
def confirm_payment():
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    data = request.get_json()

    booking_id     = data.get('booking_id')
    payment_method = data.get('payment_method', '').strip()

    valid_methods = ('upi', 'credit_card', 'debit_card', 'net_banking', 'wallet', 'cash')

    if not booking_id:
        return jsonify({'error': 'booking_id is required.'}), 400

    if payment_method not in valid_methods:
        return jsonify({'error': f'payment_method must be one of: {", ".join(valid_methods)}'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # verify the booking belongs to this user
        cursor.execute("SELECT user_id FROM Booking WHERE booking_id = ?", booking_id)
        row = cursor.fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Booking not found.'}), 404

        if row[0] != user_id:
            conn.close()
            return jsonify({'error': 'Access denied.'}), 403

        # generate a unique transaction reference
        transaction_ref = 'TXN' + uuid.uuid4().hex[:12].upper()

        cursor.execute(
            """
            EXEC sp_ConfirmPayment
                @booking_id      = ?,
                @payment_method  = ?,
                @transaction_ref = ?
            """,
            booking_id, payment_method, transaction_ref
        )

        result = row_to_dict(cursor)
        conn.commit()
        conn.close()

        if result and 'error_message' in result:
            return jsonify({'error': result['error_message']}), 400

        return jsonify({
            'message':         'Payment confirmed successfully.',
            'transaction_ref': transaction_ref,
            'booking_id':      booking_id
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/payments/<booking_id>
# returns payment details for a booking
@payments_bp.route('/<int:booking_id>', methods=['GET'])
def get_payment_details(booking_id):
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check booking ownership
        cursor.execute("SELECT user_id FROM Booking WHERE booking_id = ?", booking_id)
        row = cursor.fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Booking not found.'}), 404

        if row[0] != user_id and session.get('role') != 'admin':
            conn.close()
            return jsonify({'error': 'Access denied.'}), 403

        cursor.execute(
            """
            SELECT
                payment_id, transaction_ref, payment_method,
                payment_status, paid_amt, paid_at, booking_id
            FROM Payment
            WHERE booking_id = ?
            """,
            booking_id
        )
        payment = row_to_dict(cursor)
        conn.close()

        if payment is None:
            return jsonify({'message': 'No payment found for this booking.'}), 404

        # convert types
        if payment.get('paid_at') and hasattr(payment['paid_at'], 'isoformat'):
            payment['paid_at'] = payment['paid_at'].isoformat()
        if payment.get('paid_amt'):
            payment['paid_amt'] = float(payment['paid_amt'])

        return jsonify(payment), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# GET /api/payments/all
# returns all payments (admin only)
@payments_bp.route('/all', methods=['GET'])
def get_all_payments():
    if session.get('role') != 'admin':
        return jsonify({'error': 'Admin access required.'}), 403

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                p.payment_id, p.transaction_ref, p.payment_method,
                p.payment_status, p.paid_amt, p.paid_at,
                b.booking_id, u.full_name AS customer_name, e.title AS event_title
            FROM Payment p
            JOIN Booking b ON p.booking_id = b.booking_id
            JOIN Users   u ON b.user_id    = u.user_id
            JOIN Event   e ON b.event_id   = e.event_id
            ORDER BY p.paid_at DESC
            """
        )
        payments = rows_to_dict(cursor)
        conn.close()

        for p in payments:
            if p.get('paid_at') and hasattr(p['paid_at'], 'isoformat'):
                p['paid_at'] = p['paid_at'].isoformat()
            if p.get('paid_amt'):
                p['paid_amt'] = float(p['paid_amt'])

        return jsonify(payments), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
