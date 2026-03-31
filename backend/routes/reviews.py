
# routes/reviews.py
# submit and fetch reviews for events
# users can only review events they have a confirmed booking for

from flask import Blueprint, request, jsonify, session
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, rows_to_dict, row_to_dict

reviews_bp = Blueprint('reviews', __name__)


def login_required():
    return session.get('user_id')


# GET /api/reviews/<event_id>
# returns all reviews for an event
@reviews_bp.route('/<int:event_id>', methods=['GET'])
def get_event_reviews(event_id):
    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                r.review_id,
                r.rating,
                r.comment,
                r.reviewed_at,
                u.full_name AS reviewer_name
            FROM Review r
            JOIN Users u ON r.user_id = u.user_id
            WHERE r.event_id = ?
            ORDER BY r.reviewed_at DESC
            """,
            event_id
        )
        reviews = rows_to_dict(cursor)

        # get average rating from view
        cursor.execute(
            "SELECT total_reviews, avg_rating FROM vw_EventRatings WHERE event_id = ?",
            event_id
        )
        rating_summary = row_to_dict(cursor)
        conn.close()

        for r in reviews:
            if r.get('reviewed_at') and hasattr(r['reviewed_at'], 'isoformat'):
                r['reviewed_at'] = r['reviewed_at'].isoformat()

        return jsonify({
            'reviews':        reviews,
            'total_reviews':  rating_summary['total_reviews'] if rating_summary else 0,
            'avg_rating':     float(rating_summary['avg_rating']) if rating_summary and rating_summary['avg_rating'] else None
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# POST /api/reviews/submit
# submits a review for an event
# user must have a confirmed booking for that event
# body: { event_id, rating, comment }
@reviews_bp.route('/submit', methods=['POST'])
def submit_review():
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required to submit a review.'}), 401

    data = request.get_json()

    event_id = data.get('event_id')
    rating   = data.get('rating')
    comment  = data.get('comment', '').strip()

    if not event_id or rating is None:
        return jsonify({'error': 'event_id and rating are required.'}), 400

    if not isinstance(rating, int) or rating < 1 or rating > 5:
        return jsonify({'error': 'Rating must be an integer between 1 and 5.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check if the user has a confirmed booking for this event
        cursor.execute(
            """
            SELECT booking_id FROM Booking
            WHERE user_id = ? AND event_id = ? AND booking_status = 'confirmed'
            """,
            user_id, event_id
        )
        if cursor.fetchone() is None:
            conn.close()
            return jsonify({'error': 'You can only review events you have attended.'}), 403

        # check if user already reviewed this event
        cursor.execute(
            "SELECT review_id FROM Review WHERE user_id = ? AND event_id = ?",
            user_id, event_id
        )
        if cursor.fetchone():
            conn.close()
            return jsonify({'error': 'You have already reviewed this event.'}), 409

        cursor.execute(
            "INSERT INTO Review (rating, comment, user_id, event_id) VALUES (?, ?, ?, ?)",
            rating, comment if comment else None, user_id, event_id
        )
        conn.commit()
        conn.close()

        return jsonify({'message': 'Review submitted successfully.'}), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# DELETE /api/reviews/<review_id>
# deletes a review (only the author or admin can delete)
@reviews_bp.route('/<int:review_id>', methods=['DELETE'])
def delete_review(review_id):
    user_id = login_required()
    if not user_id:
        return jsonify({'error': 'Login required.'}), 401

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute("SELECT user_id FROM Review WHERE review_id = ?", review_id)
        row = cursor.fetchone()

        if row is None:
            conn.close()
            return jsonify({'error': 'Review not found.'}), 404

        if row[0] != user_id and session.get('role') != 'admin':
            conn.close()
            return jsonify({'error': 'Access denied.'}), 403

        cursor.execute("DELETE FROM Review WHERE review_id = ?", review_id)
        conn.commit()
        conn.close()

        return jsonify({'message': 'Review deleted successfully.'}), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500
