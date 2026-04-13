# 🎟️ Ticket Booking System

A full-stack **BookMyShow-style** event ticket booking platform built as a **Database Management System (DBMS) semester project**. The system supports user registration, event browsing, ticket booking with payment processing, reviews, an admin panel, and an interactive **SQL Explorer** showcasing 48+ SQL queries across 11 categories.

---

## 📑 Table of Contents

- [Tech Stack](#-tech-stack)
- [Features](#-features)
- [Project Structure](#-project-structure)
- [Database Design](#-database-design)
  - [ER Diagram (Tables)](#tables-9)
  - [Views](#views-6)
  - [Stored Procedures](#stored-procedures-5)
  - [Triggers](#triggers-5)
- [API Reference](#-api-reference)
- [Frontend Pages](#-frontend-pages)
- [SQL Explorer](#-sql-explorer)
- [Setup & Installation](#-setup--installation)
- [Running the Project](#-running-the-project)
- [Sample Data](#-sample-data)
- [How to Add a New SQL Explorer Query](#-how-to-add-a-new-sql-explorer-query)
- [Contributors](#-contributors)

---

## 🛠️ Tech Stack

| Layer      | Technology                          |
|------------|-------------------------------------|
| Database   | Microsoft SQL Server (T-SQL)        |
| Backend    | Python 3 · Flask · Flask-CORS       |
| Frontend   | HTML5 · CSS3 · Bootstrap 5 · Vanilla JS |
| DB Driver  | pyodbc (ODBC Driver 17 for SQL Server) |
| Auth       | Flask Sessions · Werkzeug (password hashing) |

---

## ✨ Features

### 👤 User Management
- User registration with role selection (Customer / Organizer / Admin)
- Secure login with password hashing (PBKDF2-SHA256)
- Session-based authentication
- Role-based access control

### 🎪 Event Browsing
- Browse all upcoming events with available tickets
- Filter events by **category** and **city**
- Detailed event pages with venue info, ticket types, and reviews
- Event ratings and average score display

### 🎫 Ticket Booking
- Select ticket type and quantity
- Real-time availability checking
- Automatic inventory management via database triggers
- Booking history with status tracking (pending → confirmed → cancelled)

### 💳 Payment Processing
- Multiple payment methods: UPI, Credit Card, Debit Card, Net Banking, Wallet, Cash
- Unique transaction reference generation
- Payment confirmation via stored procedure
- Refund handling on cancellation

### ⭐ Reviews & Ratings
- Submit ratings (1-5 stars) and comments for attended events
- One review per user per event (enforced at DB level)
- Average rating aggregation per event

### 🔧 Admin Panel
- View all bookings system-wide
- Access booking summary with payment status
- Admin-only routes protected by role checks

### 🔍 SQL Explorer (48 Queries)
- Interactive page showcasing SQL proficiency
- 11 categories: SELECT, WHERE, ORDER BY, Aggregates, GROUP BY, HAVING, JOINs, Subqueries, CASE, Views, Advanced
- Run any query live and see results in a formatted table
- Syntax-highlighted SQL display

---

## 📁 Project Structure

```
ticket-booking-system/
│
├── database/                        → SQL scripts (run in order)
│   ├── ticket_booking.sql           → Schema + sample data (run FIRST)
│   ├── views.sql                    → 6 database views
│   ├── stored_procedures.sql        → 5 stored procedures
│   └── triggers.sql                 → 5 database triggers
│
├── backend/                         → Flask application
│   ├── app.py                       → Main entry point, registers blueprints
│   ├── config.py                    → Database connection settings
│   ├── requirements.txt             → Python dependencies
│   ├── models/
│   │   └── db.py                    → Connection helper + row-to-dict utilities
│   └── routes/
│       ├── auth.py                  → Register, login, logout, session check
│       ├── events.py                → Event browsing, detail, tickets, filters
│       ├── bookings.py              → Create, view, cancel bookings
│       ├── payments.py              → Confirm payment, view payment details
│       ├── reviews.py               → Submit, view, delete reviews
│       └── sql_explorer.py          → 48 pre-defined SQL queries
│
├── frontend/                        → HTML templates (served by Flask/Jinja2)
│   ├── events.html                  → Event listing / homepage
│   ├── event-detail.html            → Single event detail + booking form
│   ├── login.html                   → Login page
│   ├── register.html                → Registration page
│   ├── dashboard.html               → User dashboard (booking history + stats)
│   ├── admin.html                   → Admin panel (all bookings overview)
│   ├── sql-explorer.html            → Interactive SQL query explorer
│   └── static/
│       ├── css/
│       │   └── style.css            → Global stylesheet
│       └── js/
│           └── main.js              → Shared JavaScript utilities
│
└── README.md                        → This file
```

---

## 🗄️ Database Design

### Tables (9)

| # | Table            | Purpose                                             | Key Constraints                                      |
|---|------------------|-----------------------------------------------------|------------------------------------------------------|
| 1 | **City**         | Stores city and state info                          | PK, UNIQUE(city_name, state)                         |
| 2 | **Event_Category** | Event categories (Music, Sports, Comedy, etc.)   | PK, UNIQUE(category_name)                            |
| 3 | **Users**        | Customers, organizers, and admins                   | PK, UNIQUE(email, username), CHECK(role)             |
| 4 | **Venue**        | Event venues linked to cities                       | PK, FK→City, CHECK(capacity > 0, venue_type)        |
| 5 | **Event**        | Events with schedule, venue, category, organizer    | PK, FK→Venue/Category/Users, CHECK(end > start)     |
| 6 | **Ticket_Type**  | Ticket tiers per event (General, VIP, etc.)        | PK, FK→Event, UNIQUE(event, type_name), CHECK(qty)  |
| 7 | **Booking**      | User bookings for events                            | PK, FK→Users/Event, CHECK(status, amt ≥ 0)          |
| 8 | **Booking_Item** | Line items within a booking                         | PK, FK→Booking/Ticket_Type, UNIQUE(booking, ticket) |
| 9 | **Payment**      | One payment per booking                             | PK, FK→Booking, UNIQUE(booking_id, transaction_ref) |
| 10| **Review**       | User reviews and ratings for events                 | PK, FK→Users/Event, UNIQUE(user, event), CHECK(1-5) |

### Relationships

```
City ──(1:M)── Venue ──(1:M)── Event ──(1:M)── Ticket_Type
                                  │                   │
                                  │                   │
Event_Category ──(1:M)── Event    │                   │
                          │       │                   │
Users ──(1:M as organizer)─┘      │                   │
Users ──(1:M as customer)── Booking ──(1:M)── Booking_Item ──(M:1)── Ticket_Type
                              │
                              ├──(1:1)── Payment
                              │
Users ──(1:M)── Review ──(M:1)── Event
```

### Views (6)

| View                     | Purpose                                                     |
|--------------------------|-------------------------------------------------------------|
| `vw_EventDetails`        | Full event info (joins Event + Venue + City + Category + Organizer) |
| `vw_AvailableEvents`     | Upcoming events with tickets still available               |
| `vw_BookingSummary`      | Booking details with user, event, venue, and payment info  |
| `vw_EventRevenue`        | Total revenue per event (only completed payments)          |
| `vw_EventRatings`        | Average rating and review count per event                  |
| `vw_TicketAvailability`  | Sold vs available tickets for every ticket type            |

### Stored Procedures (5)

| Procedure              | Purpose                                                        |
|------------------------|----------------------------------------------------------------|
| `sp_CreateBooking`     | Creates a booking + booking item, checks availability, uses transaction |
| `sp_ConfirmPayment`    | Inserts payment record and updates booking status to confirmed |
| `sp_CancelBooking`     | Cancels booking, restores ticket qty, marks payment as refunded |
| `sp_GetUserBookings`   | Returns full booking history for a user with event/payment info |
| `sp_GetEventTickets`   | Returns all ticket types and availability for an event         |

### Triggers (5)

| Trigger                          | Fires On           | Purpose                                                |
|----------------------------------|---------------------|--------------------------------------------------------|
| `trg_ReduceTicketOnBooking`     | Booking_Item INSERT | Auto-decreases available_quantity when tickets are booked |
| `trg_RestoreTicketOnCancel`     | Booking_Item DELETE | Auto-restores available_quantity on cancellation        |
| `trg_UpdateBookingTotal`        | Booking_Item INSERT/UPDATE | Recalculates booking total_amt from all line items |
| `trg_BlockBookingForClosedEvent`| Booking INSERT      | Prevents bookings for cancelled/completed events       |
| `trg_BlockDuplicatePayment`     | Payment INSERT (INSTEAD OF) | Prevents duplicate payments for a booking       |

---

## 📡 API Reference

All API routes return JSON. Base URL: `http://localhost:5000`

### Authentication (`/api/auth`)

| Method | Endpoint            | Body                                                 | Description               |
|--------|---------------------|------------------------------------------------------|---------------------------|
| POST   | `/api/auth/register`| `{ full_name, username, email, password, role? }`    | Register a new user       |
| POST   | `/api/auth/login`   | `{ email, password }`                                | Login (creates session)   |
| POST   | `/api/auth/logout`  | –                                                    | Logout (clears session)   |
| GET    | `/api/auth/me`      | –                                                    | Get current logged-in user|

### Events (`/api/events`)

| Method | Endpoint                         | Description                                    |
|--------|----------------------------------|------------------------------------------------|
| GET    | `/api/events/`                   | List upcoming events (filter: `?category=&city=`) |
| GET    | `/api/events/all`                | List all events (admin/organizer)              |
| GET    | `/api/events/<id>`               | Get single event detail + ratings              |
| GET    | `/api/events/<id>/tickets`       | Get ticket types for an event (uses SP)        |
| GET    | `/api/events/categories`         | List all event categories                      |
| GET    | `/api/events/cities`             | List all cities                                |
| GET    | `/api/events/<id>/revenue`       | Get revenue data for an event                  |

### Bookings (`/api/bookings`) — *Login required*

| Method | Endpoint                          | Body                                       | Description                     |
|--------|-----------------------------------|--------------------------------------------|---------------------------------|
| POST   | `/api/bookings/create`            | `{ event_id, ticket_type_id, quantity }`   | Create a new booking (uses SP)  |
| GET    | `/api/bookings/my`                | –                                          | Get logged-in user's bookings   |
| GET    | `/api/bookings/<id>`              | –                                          | Get single booking detail       |
| POST   | `/api/bookings/<id>/cancel`       | –                                          | Cancel a booking (uses SP)      |
| GET    | `/api/bookings/summary`           | –                                          | All bookings (admin only)       |

### Payments (`/api/payments`) — *Login required*

| Method | Endpoint                    | Body                              | Description                       |
|--------|-----------------------------|-----------------------------------|-----------------------------------|
| POST   | `/api/payments/confirm`     | `{ booking_id, payment_method }`  | Confirm payment for a booking     |
| GET    | `/api/payments/<booking_id>`| –                                 | Get payment details for a booking |
| GET    | `/api/payments/all`         | –                                 | All payments (admin only)         |

### Reviews (`/api/reviews`) — *Login required for POST/DELETE*

| Method | Endpoint                   | Body                             | Description                       |
|--------|----------------------------|----------------------------------|------------------------------------|
| GET    | `/api/reviews/<event_id>`  | –                                | Get all reviews for an event       |
| POST   | `/api/reviews/submit`      | `{ event_id, rating, comment? }` | Submit a review (must have booking)|
| DELETE | `/api/reviews/<review_id>` | –                                | Delete a review (author/admin)     |

### SQL Explorer (`/api/sql-explorer`)

| Method | Endpoint                        | Description                           |
|--------|---------------------------------|---------------------------------------|
| GET    | `/api/sql-explorer/queries`     | Get metadata for all 48 queries       |
| POST   | `/api/sql-explorer/run/<id>`    | Execute query by ID, returns results  |

### Health Check

| Method | Endpoint    | Description               |
|--------|-------------|---------------------------|
| GET    | `/api`      | API health check          |

---

## 🖥️ Frontend Pages

| Page                 | URL                        | Description                                              |
|----------------------|----------------------------|----------------------------------------------------------|
| **Events Listing**   | `/` or `/events.html`      | Homepage — browse upcoming events with filter options    |
| **Event Detail**     | `/event-detail.html?id=X`  | Full event info, ticket selection, booking form, reviews |
| **Login**            | `/login.html`              | User login form                                          |
| **Register**         | `/register.html`           | New user registration form                               |
| **Dashboard**        | `/dashboard.html`          | User's booking history, stats, and quick actions        |
| **Admin Panel**      | `/admin.html`              | Admin-only — all bookings, payments overview             |
| **SQL Explorer**     | `/sql-explorer.html`       | Interactive SQL query explorer (48 queries, 11 categories) |

---

## 🔍 SQL Explorer

The SQL Explorer is an interactive page that demonstrates SQL proficiency through **48 pre-defined queries** across **11 categories**:

| #  | Category             | Queries | Topics Covered                                          |
|----|----------------------|---------|---------------------------------------------------------|
| 1  | Basic SELECT         | 5       | SELECT *, specific columns, aliases, DISTINCT, TOP      |
| 2  | WHERE & Filtering    | 6       | =, BETWEEN, IN, LIKE, IS NULL, AND/OR                   |
| 3  | ORDER BY             | 3       | ASC, DESC, multi-column sort                             |
| 4  | Aggregate Functions  | 3       | COUNT, SUM, AVG, MIN, MAX                                |
| 5  | GROUP BY             | 4       | Grouping with joins, counting per group                  |
| 6  | HAVING               | 3       | Post-aggregation filtering                               |
| 7  | JOINs                | 6       | INNER, LEFT, 4-table, 5-table, self-style join           |
| 8  | Subqueries           | 4       | WHERE subquery, FROM (derived table), EXISTS, NOT EXISTS |
| 9  | CASE & Computed      | 3       | CASE WHEN, simple CASE, computed columns                 |
| 10 | Views                | 6       | Querying all 6 database views                            |
| 11 | Advanced             | 5       | CTE (WITH), string functions, date functions, RANK(), ROW_NUMBER() |

Each query can be run live with a single click, displaying the SQL and results in a formatted table.

---

## 🚀 Setup & Installation

### Prerequisites

- **Microsoft SQL Server** (2019 or later recommended) — [Download](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- **SQL Server Management Studio (SSMS)** — [Download](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)
- **Python 3.10+** — [Download](https://www.python.org/downloads/)
- **ODBC Driver 17 for SQL Server** — [Download](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Step 1: Set Up the Database

Open SSMS and run the SQL scripts **in this order**:

```
1. database/ticket_booking.sql     → Creates database, tables, and sample data
2. database/views.sql              → Creates 6 views
3. database/stored_procedures.sql  → Creates 5 stored procedures
4. database/triggers.sql           → Creates 5 triggers
```

> **Note:** Each script begins with `USE TicketBookingSystem;` — the first script creates the database itself.

### Step 2: Configure the Backend

Open `backend/config.py` and update the connection settings:

```python
SERVER   = 'localhost'              # Your SQL Server instance (e.g., DESKTOP-XXXX\SQLEXPRESS)
DATABASE = 'TicketBookingSystem'
DRIVER   = 'ODBC Driver 17 for SQL Server'
```

By default, the app uses **Windows Authentication** (`Trusted_Connection=yes`). If you use SQL Server Authentication, switch to the commented-out block in `config.py` and provide your username/password.

### Step 3: Install Python Dependencies

```bash
cd ticket-booking-system
pip install -r backend/requirements.txt
```

Or install manually:

```bash
pip install flask flask-cors pyodbc werkzeug
```

---

## ▶️ Running the Project

```bash
python backend/app.py
```

The server starts at **http://localhost:5000**. Open this URL in your browser.

| URL                                    | What You'll See                |
|----------------------------------------|--------------------------------|
| `http://localhost:5000/`               | Events listing (homepage)      |
| `http://localhost:5000/login.html`     | Login page                     |
| `http://localhost:5000/dashboard.html` | User dashboard                 |
| `http://localhost:5000/admin.html`     | Admin panel                    |
| `http://localhost:5000/sql-explorer.html` | SQL Explorer               |

### Sample Login Credentials

| Role      | Email                | Password   |
|-----------|----------------------|------------|
| Admin     | admin@example.com    | sid        |
| Organizer | sidj@example.com     | sid        |

> **Note:** Sample users (arjun@example.com, etc.) use plain-text hashed passwords (`hashed_pw_1`, etc.) that won't work for login. Use the credentials above or register a new account.

---

## 📊 Sample Data

The database comes pre-loaded with:

| Entity         | Count | Examples                                           |
|----------------|-------|----------------------------------------------------|
| Cities         | 11    | Mumbai, Bangalore, Delhi, Kolkata, Hyderabad, etc. |
| Categories     | 5     | Music, Sports, Comedy, Technology, Theatre          |
| Users          | 26    | 18 customers, 4 organizers, 2 admins               |
| Venues         | 11    | NSCI Dome, Palace Grounds, Siri Fort, HITEX, etc.  |
| Events         | 16    | Sunburn Festival, TechSummit, Comedy Nights, etc.  |
| Ticket Types   | 31    | General, VIP, Premium, Day Pass, Workshop, etc.    |
| Bookings       | 22    | 19 confirmed, 1 pending, 1 cancelled, 1 refunded  |
| Payments       | 20    | UPI, Credit Card, Debit Card, Net Banking, etc.    |
| Reviews        | 8     | Ratings from 3-5 stars with comments               |

---

## ➕ How to Add a New SQL Explorer Query

Only **one file** needs to be modified: `backend/routes/sql_explorer.py`

1. Open the file and find the `QUERIES` list (starts at line 20)
2. Add a new dictionary entry before the closing `]`:

```python
{
    "id": 49,                          # Next number after the last query
    "category": "GROUP BY",            # Must match an existing category exactly
    "icon": "📊",                      # Use the icon for that category (see table below)
    "title": "Your Query Title",       # Shown as the card heading
    "description": "What this query demonstrates.",
    "sql": "SELECT column1, column2 FROM TableName WHERE condition;"
},
```

3. Save and restart the backend — the query auto-appears on the frontend

**Category → Icon mapping:**

| Category | Icon | Category | Icon |
|---|---|---|---|
| Basic SELECT | 📋 | JOINs | 🔗 |
| WHERE & Filtering | 🔍 | Subqueries | 🪆 |
| ORDER BY | ↕️ | CASE & Computed | ⚡ |
| Aggregate Functions | 🔢 | Views | 👁️ |
| GROUP BY | 📊 | Advanced | 🚀 |
| HAVING | 🎯 | | |

> **Important:** Only `SELECT` queries are allowed — the explorer is read-only.

---

## 📄 License

This project was developed as a **DBMS Semester Project** for academic purposes.

---

<p align="center">
  Built using Flask, SQL Server, and Bootstrap
</p>
