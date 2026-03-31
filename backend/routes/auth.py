
# routes/auth.py
# handles user registration, login, and logout
# uses flask session to keep the user logged in
# passwords are hashed with werkzeug before storing

from flask import Blueprint, request, jsonify, session
from werkzeug.security import generate_password_hash, check_password_hash
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection, row_to_dict

auth_bp = Blueprint('auth', __name__)


# POST /api/auth/register
# registers a new user
# body: { full_name, username, email, password, role (optional, defaults to customer) }
@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()

    full_name = data.get('full_name', '').strip()
    username  = data.get('username', '').strip()
    email     = data.get('email', '').strip().lower()
    password  = data.get('password', '')
    role      = data.get('role', 'customer')

    # basic validation
    if not full_name or not username or not email or not password:
        return jsonify({'error': 'All fields are required.'}), 400

    if role not in ('customer', 'organizer', 'admin'):
        return jsonify({'error': 'Invalid role.'}), 400

    password_hash = generate_password_hash(password)

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        # check if email or username already exists
        cursor.execute(
            "SELECT user_id FROM Users WHERE email = ? OR username = ?",
            email, username
        )
        if cursor.fetchone():
            conn.close()
            return jsonify({'error': 'Email or username already in use.'}), 409

        cursor.execute(
            """
            INSERT INTO Users (full_name, username, email, password_hash, role)
            VALUES (?, ?, ?, ?, ?)
            """,
            full_name, username, email, password_hash, role
        )
        conn.commit()

        # get the new user's id
        cursor.execute("SELECT user_id FROM Users WHERE email = ?", email)
        row = cursor.fetchone()
        conn.close()

        return jsonify({'message': 'Registration successful.', 'user_id': row[0]}), 201

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# POST /api/auth/login
# logs in an existing user
# body: { email, password }
@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()

    email    = data.get('email', '').strip().lower()
    password = data.get('password', '')

    if not email or not password:
        return jsonify({'error': 'Email and password are required.'}), 400

    try:
        conn   = get_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT user_id, full_name, username, email, password_hash, role FROM Users WHERE email = ?",
            email
        )
        row = cursor.fetchone()
        conn.close()

        if row is None:
            return jsonify({'error': 'Invalid email or password.'}), 401

        user_id, full_name, username, user_email, password_hash, role = row

        if not check_password_hash(password_hash, password):
            return jsonify({'error': 'Invalid email or password.'}), 401

        # store user info in session
        session['user_id']   = user_id
        session['full_name'] = full_name
        session['email']     = user_email
        session['role']      = role

        return jsonify({
            'message':   'Login successful.',
            'user_id':   user_id,
            'full_name': full_name,
            'username':  username,
            'email':     user_email,
            'role':      role
        }), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500


# POST /api/auth/logout
# clears the session
@auth_bp.route('/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'message': 'Logged out successfully.'}), 200


# GET /api/auth/me
# returns the currently logged-in user's info from session
@auth_bp.route('/me', methods=['GET'])
def me():
    if 'user_id' not in session:
        return jsonify({'error': 'Not logged in.'}), 401

    return jsonify({
        'user_id':   session['user_id'],
        'full_name': session['full_name'],
        'email':     session['email'],
        'role':      session['role']
    }), 200
