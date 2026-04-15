"""Quick diagnostic: check actual Venue table schema and triggers in the database."""
import sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import CONNECTION_STRING
import pyodbc

conn = pyodbc.connect(CONNECTION_STRING)
cursor = conn.cursor()

print("=== Venue Table Columns ===")
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Venue'
    ORDER BY ORDINAL_POSITION
""")
for row in cursor.fetchall():
    print(f"  {row[0]:20s}  {row[1]:15s}  nullable={row[2]}  maxlen={row[3]}")

print("\n=== Triggers on Venue ===")
cursor.execute("""
    SELECT t.name AS trigger_name, t.is_disabled
    FROM sys.triggers t
    JOIN sys.objects o ON t.parent_id = o.object_id
    WHERE o.name = 'Venue'
""")
triggers = cursor.fetchall()
if not triggers:
    print("  (none)")
else:
    for row in triggers:
        print(f"  {row[0]}  disabled={row[1]}")

print("\n=== Quick INSERT test ===")
try:
    cursor.execute("SET NOCOUNT ON")
    cursor.execute("""
        INSERT INTO Venue (venue_name, address, venue_type, capacity, city_id)
        VALUES (?, ?, ?, ?, ?)
    """, 'TEST_DELETE_ME', 'Test Address 123', 'hall', 100, 1)
    cursor.execute("SELECT @@IDENTITY AS new_id")
    row = cursor.fetchone()
    print(f"  SUCCESS! new_id = {row[0]}")
    # rollback so we don't keep test data
    conn.rollback()
    print("  (rolled back)")
except Exception as e:
    print(f"  ERROR: {e}")
    conn.rollback()

conn.close()
