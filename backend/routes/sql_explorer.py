
# routes/sql_explorer.py
# Read-only SQL Explorer for semester project demo
# Exposes pre-defined queries grouped by SQL topic
# GET  /api/sql-explorer/queries  → list of all queries with metadata
# POST /api/sql-explorer/run/<id> → execute a specific query, return rows + columns

from flask import Blueprint, jsonify, session
import sys, os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from models.db import get_connection

sql_explorer_bp = Blueprint('sql_explorer', __name__)

# ── Query catalogue ──────────────────────────────────────────────────────────
# Each entry: id, category, title, description, sql
# All queries are SELECT-only (safe, read-only)

QUERIES = [

    # ── 1. BASIC SELECT ──────────────────────────────────────────────────────
    {
        "id": 1,
        "category": "Basic SELECT",
        "icon": "📋",
        "title": "All Users",
        "description": "Retrieve every column from the Users table.",
        "sql": "SELECT user_id, full_name, username, email, role, created_at FROM Users;"
    },
    {
        "id": 2,
        "category": "Basic SELECT",
        "icon": "📋",
        "title": "Specific Columns – Events",
        "description": "Select only the title, status and start date from Event.",
        "sql": "SELECT event_id, title, status, start_datetime FROM Event;"
    },
    {
        "id": 3,
        "category": "Basic SELECT",
        "icon": "📋",
        "title": "Column Aliases",
        "description": "Rename columns using AS aliases for clarity.",
        "sql": """SELECT
    event_id        AS [Event ID],
    title           AS [Event Name],
    start_datetime  AS [Start Date],
    status          AS [Current Status]
FROM Event;"""
    },
    {
        "id": 4,
        "category": "Basic SELECT",
        "icon": "📋",
        "title": "DISTINCT Roles",
        "description": "List every unique role that exists in the Users table.",
        "sql": "SELECT DISTINCT role FROM Users;"
    },
    {
        "id": 5,
        "category": "Basic SELECT",
        "icon": "📋",
        "title": "TOP 5 Most Expensive Tickets",
        "description": "Show the five highest-priced ticket types.",
        "sql": """SELECT TOP 5
    ticket_type_id, type_name, price, event_id
FROM Ticket_Type
ORDER BY price DESC;"""
    },

    # ── 2. WHERE & FILTERING ─────────────────────────────────────────────────
    {
        "id": 6,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "Upcoming Events Only",
        "description": "Filter events to show only those with status = 'upcoming'.",
        "sql": "SELECT event_id, title, start_datetime, status FROM Event WHERE status = 'upcoming';"
    },
    {
        "id": 7,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "Tickets Priced Between ₹300 and ₹1000",
        "description": "Use BETWEEN to filter a price range.",
        "sql": "SELECT ticket_type_id, type_name, price, event_id FROM Ticket_Type WHERE price BETWEEN 300 AND 1000;"
    },
    {
        "id": 8,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "Events in Mumbai or Delhi (IN)",
        "description": "Use IN to match multiple city values.",
        "sql": """SELECT e.event_id, e.title, c.city_name
FROM Event e
JOIN Venue v ON e.venue_id = v.venue_id
JOIN City  c ON v.city_id  = c.city_id
WHERE c.city_name IN ('Mumbai', 'Delhi');"""
    },
    {
        "id": 9,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "Users Whose Name Contains 'a' (LIKE)",
        "description": "Pattern matching with LIKE and wildcard %.",
        "sql": "SELECT user_id, full_name, email, role FROM Users WHERE full_name LIKE '%a%';"
    },
    {
        "id": 10,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "Bookings With No Payment (IS NULL)",
        "description": "Find bookings that have not been paid for yet using LEFT JOIN + IS NULL.",
        "sql": """SELECT b.booking_id, b.booking_status, b.total_amt, b.user_id
FROM Booking b
LEFT JOIN Payment p ON b.booking_id = p.booking_id
WHERE p.payment_id IS NULL;"""
    },
    {
        "id": 11,
        "category": "WHERE & Filtering",
        "icon": "🔍",
        "title": "High-Value Confirmed Bookings (AND / OR)",
        "description": "Combine AND/OR in a complex WHERE clause.",
        "sql": """SELECT booking_id, total_amt, booking_status, user_id
FROM Booking
WHERE (booking_status = 'confirmed' OR booking_status = 'pending')
  AND total_amt > 500
ORDER BY total_amt DESC;"""
    },

    # ── 3. ORDER BY ──────────────────────────────────────────────────────────
    {
        "id": 12,
        "category": "ORDER BY",
        "icon": "↕️",
        "title": "Events Sorted by Start Date (ASC)",
        "description": "Order events from earliest to latest.",
        "sql": "SELECT event_id, title, start_datetime, status FROM Event ORDER BY start_datetime ASC;"
    },
    {
        "id": 13,
        "category": "ORDER BY",
        "icon": "↕️",
        "title": "Bookings Sorted by Amount (DESC)",
        "description": "Show the most expensive bookings first.",
        "sql": "SELECT booking_id, user_id, total_amt, booking_status FROM Booking ORDER BY total_amt DESC;"
    },
    {
        "id": 14,
        "category": "ORDER BY",
        "icon": "↕️",
        "title": "Multi-column Sort – City then Venue",
        "description": "Sort by city name first, then venue name within each city.",
        "sql": """SELECT v.venue_id, v.venue_name, v.venue_type, c.city_name
FROM Venue v
JOIN City c ON v.city_id = c.city_id
ORDER BY c.city_name ASC, v.venue_name ASC;"""
    },

    # ── 4. AGGREGATE FUNCTIONS ───────────────────────────────────────────────
    {
        "id": 15,
        "category": "Aggregate Functions",
        "icon": "🔢",
        "title": "Total, Min, Max, Avg Ticket Price",
        "description": "Apply all four major aggregate functions on ticket price.",
        "sql": """SELECT
    COUNT(*)        AS total_ticket_types,
    MIN(price)      AS cheapest,
    MAX(price)      AS most_expensive,
    AVG(price)      AS average_price,
    SUM(price)      AS sum_of_all_prices
FROM Ticket_Type;"""
    },
    {
        "id": 16,
        "category": "Aggregate Functions",
        "icon": "🔢",
        "title": "Total Revenue Collected",
        "description": "Sum all completed payments to get total platform revenue.",
        "sql": """SELECT
    COUNT(*)         AS total_payments,
    SUM(paid_amt)    AS total_revenue,
    AVG(paid_amt)    AS avg_payment
FROM Payment
WHERE payment_status = 'completed';"""
    },
    {
        "id": 17,
        "category": "Aggregate Functions",
        "icon": "🔢",
        "title": "COUNT of Users by Role",
        "description": "Count how many users exist in each role.",
        "sql": "SELECT role, COUNT(*) AS user_count FROM Users GROUP BY role;"
    },

    # ── 5. GROUP BY ───────────────────────────────────────────────────────────
    {
        "id": 18,
        "category": "GROUP BY",
        "icon": "📊",
        "title": "Bookings Per Event",
        "description": "Count how many bookings each event has received.",
        "sql": """SELECT
    e.event_id,
    e.title,
    COUNT(b.booking_id) AS total_bookings
FROM Event e
LEFT JOIN Booking b ON e.event_id = b.event_id
GROUP BY e.event_id, e.title
ORDER BY total_bookings DESC;"""
    },
    {
        "id": 19,
        "category": "GROUP BY",
        "icon": "📊",
        "title": "Revenue Per Payment Method",
        "description": "Total money collected grouped by payment method.",
        "sql": """SELECT
    payment_method,
    COUNT(*)      AS transactions,
    SUM(paid_amt) AS total_collected
FROM Payment
WHERE payment_status = 'completed'
GROUP BY payment_method
ORDER BY total_collected DESC;"""
    },
    {
        "id": 20,
        "category": "GROUP BY",
        "icon": "📊",
        "title": "Events Per Category",
        "description": "Count how many events belong to each category.",
        "sql": """SELECT
    ec.category_name,
    COUNT(e.event_id) AS event_count
FROM Event_Category ec
LEFT JOIN Event e ON ec.category_id = e.category_id
GROUP BY ec.category_name
ORDER BY event_count DESC;"""
    },
    {
        "id": 21,
        "category": "GROUP BY",
        "icon": "📊",
        "title": "Tickets Sold Per Event",
        "description": "Sum quantities from Booking_Item per event.",
        "sql": """SELECT
    e.title,
    SUM(bi.quantity) AS tickets_sold
FROM Booking_Item bi
JOIN Booking b ON bi.booking_id = b.booking_id
JOIN Event   e ON b.event_id    = e.event_id
GROUP BY e.event_id, e.title
ORDER BY tickets_sold DESC;"""
    },

    # ── 6. HAVING ─────────────────────────────────────────────────────────────
    {
        "id": 22,
        "category": "HAVING",
        "icon": "🎯",
        "title": "Events With More Than 1 Booking",
        "description": "Use HAVING to filter groups — only events with > 1 booking.",
        "sql": """SELECT
    e.event_id,
    e.title,
    COUNT(b.booking_id) AS booking_count
FROM Event e
JOIN Booking b ON e.event_id = b.event_id
GROUP BY e.event_id, e.title
HAVING COUNT(b.booking_id) > 1
ORDER BY booking_count DESC;"""
    },
    {
        "id": 23,
        "category": "HAVING",
        "icon": "🎯",
        "title": "Payment Methods With Total > ₹1000",
        "description": "Filter grouped payment methods where total revenue exceeds ₹1000.",
        "sql": """SELECT
    payment_method,
    SUM(paid_amt) AS total
FROM Payment
WHERE payment_status = 'completed'
GROUP BY payment_method
HAVING SUM(paid_amt) > 1000
ORDER BY total DESC;"""
    },
    {
        "id": 24,
        "category": "HAVING",
        "icon": "🎯",
        "title": "Cities Hosting More Than 1 Event",
        "description": "Group by city and filter with HAVING to find busy cities.",
        "sql": """SELECT
    c.city_name,
    COUNT(DISTINCT e.event_id) AS event_count
FROM City c
JOIN Venue v ON c.city_id  = v.city_id
JOIN Event e ON v.venue_id = e.venue_id
GROUP BY c.city_name
HAVING COUNT(DISTINCT e.event_id) > 1
ORDER BY event_count DESC;"""
    },

    # ── 7. JOINS ──────────────────────────────────────────────────────────────
    {
        "id": 25,
        "category": "JOINs",
        "icon": "🔗",
        "title": "INNER JOIN – Event + Venue",
        "description": "Basic INNER JOIN between two tables.",
        "sql": """SELECT e.event_id, e.title, v.venue_name, v.venue_type
FROM Event e
INNER JOIN Venue v ON e.venue_id = v.venue_id;"""
    },
    {
        "id": 26,
        "category": "JOINs",
        "icon": "🔗",
        "title": "LEFT JOIN – All Events Including Those Without Bookings",
        "description": "LEFT JOIN shows all events even if they have 0 bookings.",
        "sql": """SELECT e.event_id, e.title, COUNT(b.booking_id) AS bookings
FROM Event e
LEFT JOIN Booking b ON e.event_id = b.event_id
GROUP BY e.event_id, e.title
ORDER BY bookings DESC;"""
    },
    {
        "id": 27,
        "category": "JOINs",
        "icon": "🔗",
        "title": "4-Table JOIN – Booking Full Detail",
        "description": "Join Booking → Users → Event → Venue in one query.",
        "sql": """SELECT
    b.booking_id,
    u.full_name      AS customer,
    e.title          AS event,
    v.venue_name     AS venue,
    b.total_amt,
    b.booking_status
FROM Booking b
JOIN Users u ON b.user_id  = u.user_id
JOIN Event e ON b.event_id = e.event_id
JOIN Venue v ON e.venue_id = v.venue_id
ORDER BY b.booking_id;"""
    },
    {
        "id": 28,
        "category": "JOINs",
        "icon": "🔗",
        "title": "5-Table JOIN – Full Booking + Payment + City",
        "description": "Chain five tables together for a complete booking report.",
        "sql": """SELECT
    b.booking_id,
    u.full_name        AS customer,
    e.title            AS event,
    c.city_name        AS city,
    b.total_amt,
    b.booking_status,
    p.payment_method,
    p.paid_at
FROM Booking b
JOIN Users   u ON b.user_id    = u.user_id
JOIN Event   e ON b.event_id   = e.event_id
JOIN Venue   v ON e.venue_id   = v.venue_id
JOIN City    c ON v.city_id    = c.city_id
LEFT JOIN Payment p ON b.booking_id = p.booking_id
ORDER BY b.booking_id;"""
    },
    {
        "id": 29,
        "category": "JOINs",
        "icon": "🔗",
        "title": "Self-style JOIN – Organizers and Their Events",
        "description": "Join Users (as organizer) back to Event.",
        "sql": """SELECT
    u.full_name  AS organizer,
    u.email,
    COUNT(e.event_id) AS events_organized
FROM Users u
LEFT JOIN Event e ON u.user_id = e.organiser_id
WHERE u.role = 'organizer'
GROUP BY u.user_id, u.full_name, u.email
ORDER BY events_organized DESC;"""
    },
    {
        "id": 30,
        "category": "JOINs",
        "icon": "🔗",
        "title": "Booking Items With Ticket & Event Name",
        "description": "Join Booking_Item to Ticket_Type to Event for line-item detail.",
        "sql": """SELECT
    bi.booking_item_id,
    bi.booking_id,
    e.title          AS event,
    tt.type_name     AS ticket_type,
    bi.quantity,
    bi.price_each,
    bi.subtotal
FROM Booking_Item bi
JOIN Ticket_Type tt ON bi.ticket_type_id = tt.ticket_type_id
JOIN Event        e ON tt.event_id       = e.event_id
ORDER BY bi.booking_id;"""
    },

    # ── 8. SUBQUERIES ────────────────────────────────────────────────────────
    {
        "id": 31,
        "category": "Subqueries",
        "icon": "🪆",
        "title": "Subquery in WHERE – Above-Average Bookings",
        "description": "Find bookings whose amount is above the table average.",
        "sql": """SELECT booking_id, user_id, total_amt, booking_status
FROM Booking
WHERE total_amt > (SELECT AVG(total_amt) FROM Booking)
ORDER BY total_amt DESC;"""
    },
    {
        "id": 32,
        "category": "Subqueries",
        "icon": "🪆",
        "title": "Subquery in FROM – Derived Table",
        "description": "Use a subquery as a derived table in the FROM clause.",
        "sql": """SELECT city_name, event_count
FROM (
    SELECT c.city_name, COUNT(e.event_id) AS event_count
    FROM City c
    JOIN Venue v ON c.city_id  = v.city_id
    JOIN Event e ON v.venue_id = e.venue_id
    GROUP BY c.city_name
) AS city_events
WHERE event_count >= 1
ORDER BY event_count DESC;"""
    },
    {
        "id": 33,
        "category": "Subqueries",
        "icon": "🪆",
        "title": "EXISTS – Events That Have At Least One Review",
        "description": "Use EXISTS to check for related rows without joining.",
        "sql": """SELECT event_id, title, status
FROM Event e
WHERE EXISTS (
    SELECT 1 FROM Review r WHERE r.event_id = e.event_id
);"""
    },
    {
        "id": 34,
        "category": "Subqueries",
        "icon": "🪆",
        "title": "NOT EXISTS – Events With No Reviews",
        "description": "Use NOT EXISTS to find events that nobody has reviewed yet.",
        "sql": """SELECT event_id, title, status
FROM Event e
WHERE NOT EXISTS (
    SELECT 1 FROM Review r WHERE r.event_id = e.event_id
);"""
    },

    # ── 9. CASE / COMPUTED COLUMNS ──────────────────────────────────────────
    {
        "id": 35,
        "category": "CASE & Computed",
        "icon": "⚡",
        "title": "CASE – Ticket Price Tier Label",
        "description": "Categorise each ticket type by price band using CASE WHEN.",
        "sql": """SELECT
    type_name,
    price,
    CASE
        WHEN price < 300  THEN 'Budget'
        WHEN price < 800  THEN 'Standard'
        WHEN price < 1500 THEN 'Premium'
        ELSE 'Luxury'
    END AS price_tier
FROM Ticket_Type
ORDER BY price;"""
    },
    {
        "id": 36,
        "category": "CASE & Computed",
        "icon": "⚡",
        "title": "CASE – Booking Status Label with Emoji",
        "description": "Use CASE to add a human-friendly status label.",
        "sql": """SELECT
    booking_id,
    total_amt,
    booking_status,
    CASE booking_status
        WHEN 'confirmed'  THEN '✅ Confirmed'
        WHEN 'pending'    THEN '⏳ Awaiting Payment'
        WHEN 'cancelled'  THEN '❌ Cancelled'
        WHEN 'refunded'   THEN '💸 Refunded'
        ELSE '❓ Unknown'
    END AS status_label
FROM Booking
ORDER BY booking_id;"""
    },
    {
        "id": 37,
        "category": "CASE & Computed",
        "icon": "⚡",
        "title": "Computed Column – Tickets Sold %",
        "description": "Calculate sold percentage as a derived column.",
        "sql": """SELECT
    event_id,
    type_name,
    total_quantity,
    available_quantity,
    (total_quantity - available_quantity)              AS tickets_sold,
    CAST(
        (total_quantity - available_quantity) * 100.0
        / total_quantity
    AS DECIMAL(5,1))                                   AS pct_sold
FROM Ticket_Type
ORDER BY pct_sold DESC;"""
    },

    # ── 10. VIEWS ────────────────────────────────────────────────────────────
    {
        "id": 38,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_EventDetails – Full Event Info",
        "description": "Query the pre-built view that joins Event, Venue, City, Category and Organizer.",
        "sql": "SELECT * FROM vw_EventDetails ORDER BY event_id;"
    },
    {
        "id": 39,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_BookingSummary – All Bookings With Context",
        "description": "Query the booking summary view used by the admin panel.",
        "sql": "SELECT * FROM vw_BookingSummary ORDER BY booking_id;"
    },
    {
        "id": 40,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_EventRevenue – Revenue Per Event",
        "description": "Show total revenue per event from the revenue view.",
        "sql": "SELECT * FROM vw_EventRevenue ORDER BY total_revenue DESC;"
    },
    {
        "id": 41,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_AvailableEvents – Open Events With Tickets",
        "description": "Query the available-events view — only upcoming events that have tickets left.",
        "sql": "SELECT * FROM vw_AvailableEvents ORDER BY starting_price ASC;"
    },
    {
        "id": 42,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_EventRatings – Average Rating Per Event",
        "description": "Query the ratings view to see how each event is rated.",
        "sql": "SELECT * FROM vw_EventRatings ORDER BY avg_rating DESC;"
    },
    {
        "id": 43,
        "category": "Views",
        "icon": "👁️",
        "title": "vw_TicketAvailability – Sold vs Available",
        "description": "See every ticket type's availability status across all events.",
        "sql": "SELECT * FROM vw_TicketAvailability ORDER BY event_id, price;"
    },

    # ── 11. ADVANCED (CTE, STRING, DATE) ─────────────────────────────────────
    {
        "id": 44,
        "category": "Advanced",
        "icon": "🚀",
        "title": "CTE – Top 3 Customers by Spend",
        "description": "Use a Common Table Expression (WITH) to rank customers.",
        "sql": """WITH CustomerSpend AS (
    SELECT
        u.user_id,
        u.full_name,
        SUM(b.total_amt) AS total_spent
    FROM Users u
    JOIN Booking b ON u.user_id = b.user_id
    WHERE b.booking_status = 'confirmed'
    GROUP BY u.user_id, u.full_name
)
SELECT TOP 3 user_id, full_name, total_spent
FROM CustomerSpend
ORDER BY total_spent DESC;"""
    },
    {
        "id": 45,
        "category": "Advanced",
        "icon": "🚀",
        "title": "String Functions – Format User Info",
        "description": "Use UPPER, LEN and CONCAT string functions on user data.",
        "sql": """SELECT
    user_id,
    UPPER(full_name)                              AS name_upper,
    LEN(full_name)                                AS name_length,
    CONCAT(username, ' <', email, '>')            AS formatted_contact,
    LEFT(email, CHARINDEX('@', email) - 1)        AS email_handle
FROM Users
ORDER BY user_id;"""
    },
    {
        "id": 46,
        "category": "Advanced",
        "icon": "🚀",
        "title": "Date Functions – Days Until Event",
        "description": "Use DATEDIFF and GETDATE() to compute days until each upcoming event.",
        "sql": """SELECT
    event_id,
    title,
    start_datetime,
    DATEDIFF(DAY, GETDATE(), start_datetime) AS days_away,
    FORMAT(start_datetime, 'dd MMM yyyy')    AS formatted_date
FROM Event
WHERE status = 'upcoming'
ORDER BY start_datetime ASC;"""
    },
    {
        "id": 47,
        "category": "Advanced",
        "icon": "🚀",
        "title": "Window Function – RANK Bookings by Amount",
        "description": "Use RANK() OVER(ORDER BY ...) to rank each booking by value.",
        "sql": """SELECT
    booking_id,
    user_id,
    total_amt,
    booking_status,
    RANK() OVER (ORDER BY total_amt DESC) AS spend_rank
FROM Booking
ORDER BY spend_rank;"""
    },
    {
        "id": 48,
        "category": "Advanced",
        "icon": "🚀",
        "title": "ROW_NUMBER Per Customer",
        "description": "Partition bookings by user and assign a row number within each customer's history.",
        "sql": """SELECT
    booking_id,
    user_id,
    total_amt,
    booking_datetime,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY booking_datetime) AS booking_number
FROM Booking
ORDER BY user_id, booking_number;"""
    },
]

# ── Endpoints ────────────────────────────────────────────────────────────────

@sql_explorer_bp.route('/queries', methods=['GET'])
def list_queries():
    """Return metadata for all queries (no SQL execution here)."""
    safe = [
        {
            "id":          q["id"],
            "category":    q["category"],
            "icon":        q["icon"],
            "title":       q["title"],
            "description": q["description"],
            "sql":         q["sql"],
        }
        for q in QUERIES
    ]
    return jsonify(safe), 200


@sql_explorer_bp.route('/run/<int:query_id>', methods=['POST'])
def run_query(query_id):
    """Execute a pre-defined query by ID and return columns + rows."""
    query = next((q for q in QUERIES if q["id"] == query_id), None)
    if not query:
        return jsonify({"error": "Query not found."}), 404

    try:
        conn   = get_connection()
        cursor = conn.cursor()
        cursor.execute(query["sql"])

        columns = [col[0] for col in cursor.description] if cursor.description else []
        rows_raw = cursor.fetchall()
        conn.close()

        # Serialise: convert Decimal / datetime → basic Python types
        rows = []
        for row in rows_raw:
            r = []
            for val in row:
                if val is None:
                    r.append(None)
                elif hasattr(val, 'isoformat'):
                    r.append(val.isoformat())
                else:
                    try:
                        import decimal
                        if isinstance(val, decimal.Decimal):
                            r.append(float(val))
                        else:
                            r.append(val)
                    except Exception:
                        r.append(str(val))
            rows.append(r)

        return jsonify({
            "id":          query["id"],
            "title":       query["title"],
            "sql":         query["sql"],
            "columns":     columns,
            "rows":        rows,
            "row_count":   len(rows),
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
