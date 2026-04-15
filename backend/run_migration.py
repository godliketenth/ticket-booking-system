"""Run all pending DB changes against the existing database."""
import sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from config import CONNECTION_STRING
import pyodbc

conn = pyodbc.connect(CONNECTION_STRING, autocommit=True)
cursor = conn.cursor()

# -- 1. Drop extra tables --
print("1. Dropping Platform_Settings and Payout_Request tables...")
try:
    cursor.execute("DROP TABLE IF EXISTS Payout_Request")
    cursor.execute("DROP TABLE IF EXISTS Platform_Settings")
    print("   OK")
except Exception as e:
    print(f"   (skipped: {e})")

# -- 2. Fix vw_OrganizerEventStats view --
print("2. Updating vw_OrganizerEventStats (tickets_sold fix)...")
try:
    cursor.execute("DROP VIEW IF EXISTS vw_OrganizerEventStats")
    cursor.execute("""
        CREATE VIEW vw_OrganizerEventStats AS
        SELECT
            e.event_id,
            e.title,
            e.start_datetime,
            e.end_datetime,
            e.status,
            e.image_url,
            e.organiser_id,
            v.venue_name,
            v.venue_id,
            c.city_name,
            c.city_id,
            ec.category_name,
            ec.category_id,
            ISNULL(SUM(tt.total_quantity), 0)    AS total_seats,
            ISNULL(SUM(tt.available_quantity), 0) AS remaining_seats,
            ISNULL((
                SELECT SUM(bi.quantity)
                FROM Booking b
                JOIN Booking_Item bi ON b.booking_id = bi.booking_id
                JOIN Ticket_Type tt2 ON bi.ticket_type_id = tt2.ticket_type_id
                WHERE tt2.event_id = e.event_id
                  AND b.booking_status IN ('confirmed', 'pending')
            ), 0) AS tickets_sold,
            ISNULL((
                SELECT SUM(p.paid_amt)
                FROM Booking b
                JOIN Payment p ON b.booking_id = p.booking_id
                WHERE b.event_id = e.event_id
                  AND b.booking_status = 'confirmed'
                  AND p.payment_status = 'completed'
            ), 0) AS total_revenue
        FROM Event e
        JOIN Venue          v  ON e.venue_id    = v.venue_id
        JOIN City           c  ON v.city_id     = c.city_id
        JOIN Event_Category ec ON e.category_id = ec.category_id
        LEFT JOIN Ticket_Type tt ON e.event_id  = tt.event_id
        GROUP BY
            e.event_id, e.title, e.start_datetime, e.end_datetime,
            e.status, e.image_url, e.organiser_id,
            v.venue_name, v.venue_id, c.city_name, c.city_id,
            ec.category_name, ec.category_id
    """)
    print("   OK")
except Exception as e:
    print(f"   ERROR: {e}")

# -- 3. Add Indian cities --
print("3. Adding Indian cities...")
new_cities = [
    ('Chennai','Tamil Nadu'),('Goa','Goa'),('Indore','Madhya Pradesh'),
    ('Bhopal','Madhya Pradesh'),('Patna','Bihar'),('Bhubaneswar','Odisha'),
    ('Guwahati','Assam'),('Dehradun','Uttarakhand'),('Shimla','Himachal Pradesh'),
    ('Ranchi','Jharkhand'),('Raipur','Chhattisgarh'),('Thiruvananthapuram','Kerala'),
    ('Coimbatore','Tamil Nadu'),('Madurai','Tamil Nadu'),('Mysore','Karnataka'),
    ('Mangalore','Karnataka'),('Visakhapatnam','Andhra Pradesh'),
    ('Vijayawada','Andhra Pradesh'),('Nagpur','Maharashtra'),('Nashik','Maharashtra'),
    ('Aurangabad','Maharashtra'),('Surat','Gujarat'),('Vadodara','Gujarat'),
    ('Rajkot','Gujarat'),('Varanasi','Uttar Pradesh'),('Agra','Uttar Pradesh'),
    ('Kanpur','Uttar Pradesh'),('Noida','Uttar Pradesh'),('Ghaziabad','Uttar Pradesh'),
    ('Prayagraj','Uttar Pradesh'),('Gurugram','Haryana'),('Faridabad','Haryana'),
    ('Amritsar','Punjab'),('Ludhiana','Punjab'),('Jalandhar','Punjab'),
    ('Udaipur','Rajasthan'),('Jodhpur','Rajasthan'),('Kota','Rajasthan'),
    ('Jammu','Jammu & Kashmir'),('Srinagar','Jammu & Kashmir'),('Gangtok','Sikkim'),
    ('Shillong','Meghalaya'),('Imphal','Manipur'),('Agartala','Tripura'),
    ('Aizawl','Mizoram'),('Kohima','Nagaland'),('Itanagar','Arunachal Pradesh'),
    ('Dibrugarh','Assam'),('Silchar','Assam'),('Panaji','Goa'),
    ('Navi Mumbai','Maharashtra'),('Thane','Maharashtra'),('Kolhapur','Maharashtra'),
    ('Pondicherry','Puducherry'),('Port Blair','Andaman & Nicobar'),
    ('Haridwar','Uttarakhand'),('Rishikesh','Uttarakhand'),
    ('Dharamshala','Himachal Pradesh'),('Manali','Himachal Pradesh'),
    ('Tirupati','Andhra Pradesh'),('Warangal','Telangana'),
    ('Hubli','Karnataka'),('Belgaum','Karnataka'),
]
added = 0
for city_name, state in new_cities:
    cursor.execute("SELECT COUNT(*) FROM City WHERE city_name = ? AND state = ?", city_name, state)
    if cursor.fetchone()[0] == 0:
        cursor.execute("INSERT INTO City (city_name, state) VALUES (?, ?)", city_name, state)
        added += 1
print(f"   OK - Added {added} new cities ({len(new_cities) - added} already existed)")

# -- 4. Verify --
print("")
print("=== Verification ===")
cursor.execute("SELECT COUNT(*) FROM City")
print(f"Total cities: {cursor.fetchone()[0]}")

cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('Platform_Settings','Payout_Request')")
extra = cursor.fetchone()[0]
print(f"Extra tables remaining: {extra} {'(clean!)' if extra == 0 else '(still exist!)'}")

cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE'")
print(f"Total tables: {cursor.fetchone()[0]}")

conn.close()
print("")
print("=== All changes applied successfully ===")
