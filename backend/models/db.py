
# models/db.py
# database connection helper
# get_connection() returns a pyodbc connection
# use it with a 'with' block or close it manually after use

import pyodbc
from config import CONNECTION_STRING


def get_connection():
    """Returns a new pyodbc connection to the database."""
    return pyodbc.connect(CONNECTION_STRING)


def rows_to_dict(cursor):
    """
    Converts cursor rows to a list of dicts using column names.
    Makes it easy to jsonify query results.
    """
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def row_to_dict(cursor):
    """
    Converts a single cursor row to a dict.
    Returns None if no row found.
    """
    columns = [col[0] for col in cursor.description]
    row = cursor.fetchone()
    if row is None:
        return None
    return dict(zip(columns, row))
