-- views.sql
-- pre-built views used by the dashboard and backend
-- run this after ticket_booking.sql

USE TicketBookingSystem;
GO


-- view 1: full event details
-- joins event with venue, city, category and organizer
-- useful for the event listing page

CREATE VIEW vw_EventDetails AS
SELECT
    e.event_id,
    e.title,
    e.description,
    e.start_datetime,
    e.end_datetime,
    e.status,
    v.venue_name,
    v.address,
    v.venue_type,
    v.capacity,
    c.city_name,
    c.state,
    ec.category_name,
    u.full_name   AS organizer_name,
    u.email       AS organizer_email
FROM Event e
JOIN Venue          v  ON e.venue_id     = v.venue_id
JOIN City           c  ON v.city_id      = c.city_id
JOIN Event_Category ec ON e.category_id  = ec.category_id
JOIN Users          u  ON e.organiser_id = u.user_id;
GO


-- view 2: upcoming events with available tickets
-- only shows events that still have tickets left
-- good for the homepage / browse section

CREATE VIEW vw_AvailableEvents AS
SELECT
    e.event_id,
    e.title,
    e.start_datetime,
    e.status,
    v.venue_name,
    c.city_name,
    ec.category_name,
    MIN(tt.price)              AS starting_price,
    SUM(tt.available_quantity) AS total_available_tickets
FROM Event e
JOIN Venue          v  ON e.venue_id    = v.venue_id
JOIN City           c  ON v.city_id     = c.city_id
JOIN Event_Category ec ON e.category_id = ec.category_id
JOIN Ticket_Type    tt ON e.event_id    = tt.event_id
WHERE e.status = 'upcoming'
  AND tt.available_quantity > 0
GROUP BY
    e.event_id, e.title, e.start_datetime, e.status,
    v.venue_name, c.city_name, ec.category_name;
GO


-- view 3: booking summary
-- shows booking details along with user and event info
-- used in booking history and admin panel

CREATE VIEW vw_BookingSummary AS
SELECT
    b.booking_id,
    b.booking_datetime,
    b.total_amt,
    b.booking_status,
    u.full_name   AS customer_name,
    u.email       AS customer_email,
    e.title       AS event_title,
    e.start_datetime,
    v.venue_name,
    c.city_name,
    p.payment_status,
    p.payment_method,
    p.paid_at
FROM Booking b
JOIN Users   u ON b.user_id  = u.user_id
JOIN Event   e ON b.event_id = e.event_id
JOIN Venue   v ON e.venue_id = v.venue_id
JOIN City    c ON v.city_id  = c.city_id
LEFT JOIN Payment p ON b.booking_id = p.booking_id;
GO


-- view 4: revenue per event
-- shows how much money each event has made
-- only counts completed payments

CREATE VIEW vw_EventRevenue AS
SELECT
    e.event_id,
    e.title,
    e.start_datetime,
    e.status,
    COUNT(DISTINCT b.booking_id)  AS total_bookings,
    SUM(p.paid_amt)               AS total_revenue
FROM Event e
LEFT JOIN Booking b ON e.event_id   = b.event_id
LEFT JOIN Payment p ON b.booking_id = p.booking_id
                    AND p.payment_status = 'completed'
GROUP BY e.event_id, e.title, e.start_datetime, e.status;
GO


-- view 5: average rating per event
-- shows event title alongside its average rating and review count

CREATE VIEW vw_EventRatings AS
SELECT
    e.event_id,
    e.title,
    COUNT(r.review_id)       AS total_reviews,
    AVG(CAST(r.rating AS DECIMAL(3,1))) AS avg_rating
FROM Event e
LEFT JOIN Review r ON e.event_id = r.event_id
GROUP BY e.event_id, e.title;
GO


-- view 6: ticket availability per event
-- shows all ticket types for each event and how many are left

CREATE VIEW vw_TicketAvailability AS
SELECT
    e.event_id,
    e.title        AS event_title,
    tt.ticket_type_id,
    tt.type_name,
    tt.price,
    tt.total_quantity,
    tt.available_quantity,
    (tt.total_quantity - tt.available_quantity) AS tickets_sold
FROM Event e
JOIN Ticket_Type tt ON e.event_id = tt.event_id;
GO
