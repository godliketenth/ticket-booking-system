# 🎟️ Ticket Booking System

A DBMS mini project — BookMyShow-style ticket booking platform.

## Tech Stack
- **Database**: Microsoft SQL Server
- **Backend**: Python Flask
- **Frontend**: HTML + Bootstrap
- **DB Connector**: pyodbc

## Project Structure
```
ticket-booking-system/
├── database/          → SQL schema, views, procedures, triggers
├── backend/           → Flask app and API routes
├── frontend/          → HTML dashboard and static files
└── README.md
```

## Setup
1. Run `database/ticket_booking.sql` in SQL Server Management Studio (SSMS)
2. Update connection details in `backend/config.py`
3. Install dependencies: `pip install flask pyodbc`
4. Run the app: `python backend/app.py`
5. Open `frontend/dashboard.html` in your browser
