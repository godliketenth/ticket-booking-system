-- schema_migration.sql
-- run this AFTER ticket_booking.sql, views.sql, stored_procedures.sql, triggers.sql
-- adds tables and columns needed for organizer dashboard + admin analytics

USE TicketBookingSystem;
GO


-- ═══════════════════════════════════════════════════════════════
-- 1. Platform Settings table
--    stores global config like commission rate
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE Platform_Settings (
    setting_key    NVARCHAR(100) NOT NULL,
    setting_value  NVARCHAR(500) NOT NULL,
    updated_at     DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Platform_Settings PRIMARY KEY (setting_key)
);
GO

-- default 10% commission
INSERT INTO Platform_Settings (setting_key, setting_value)
VALUES ('commission_rate', '10');
GO


-- ═══════════════════════════════════════════════════════════════
-- 2. Add is_active column to Users for soft delete
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE Users
ADD is_active BIT NOT NULL DEFAULT 1;
GO


-- ═══════════════════════════════════════════════════════════════
-- 3. Add image_url to Event (optional poster)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE Event
ADD image_url NVARCHAR(500) NULL;
GO


-- ═══════════════════════════════════════════════════════════════
-- 4. Payout Request table
--    organizers request withdrawal of their earnings
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE Payout_Request (
    payout_id       INT            NOT NULL IDENTITY(1,1),
    organizer_id    INT            NOT NULL,
    amount          DECIMAL(10,2)  NOT NULL,
    status          NVARCHAR(20)   NOT NULL DEFAULT 'pending',
    requested_at    DATETIME       NOT NULL DEFAULT GETDATE(),
    paid_at         DATETIME       NULL,
    notes           NVARCHAR(500)  NULL,

    CONSTRAINT PK_Payout_Request      PRIMARY KEY (payout_id),
    CONSTRAINT FK_Payout_Organizer    FOREIGN KEY (organizer_id) REFERENCES Users(user_id),
    CONSTRAINT CK_Payout_Status       CHECK (status IN ('pending', 'paid', 'rejected')),
    CONSTRAINT CK_Payout_Amount       CHECK (amount > 0)
);
GO


-- ═══════════════════════════════════════════════════════════════
-- 5. View: organizer revenue per event
--    calculates tickets sold, revenue, commission, net earnings
-- ═══════════════════════════════════════════════════════════════

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

    -- total seats from ticket types
    ISNULL(SUM(tt.total_quantity), 0)         AS total_seats,
    ISNULL(SUM(tt.available_quantity), 0)      AS remaining_seats,

    -- tickets sold: count from actual booking items (confirmed + pending)
    ISNULL((
        SELECT SUM(bi.quantity)
        FROM Booking b
        JOIN Booking_Item bi ON b.booking_id = bi.booking_id
        JOIN Ticket_Type tt2 ON bi.ticket_type_id = tt2.ticket_type_id
        WHERE tt2.event_id = e.event_id
          AND b.booking_status IN ('confirmed', 'pending')
    ), 0) AS tickets_sold,

    -- revenue (only confirmed bookings with completed payments)
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
    ec.category_name, ec.category_id;
GO


-- ═══════════════════════════════════════════════════════════════
-- 6. View: admin revenue analytics
--    monthly breakdown with commission calculations
-- ═══════════════════════════════════════════════════════════════

CREATE VIEW vw_MonthlyRevenue AS
SELECT
    YEAR(p.paid_at)                           AS rev_year,
    MONTH(p.paid_at)                          AS rev_month,
    DATEPART(QUARTER, p.paid_at)              AS rev_quarter,
    COUNT(DISTINCT b.booking_id)              AS total_bookings,
    SUM(p.paid_amt)                           AS total_revenue,
    e.organiser_id,
    u.full_name                               AS organizer_name,
    ec.category_name,
    c.city_name
FROM Payment p
JOIN Booking        b  ON p.booking_id  = b.booking_id
JOIN Event          e  ON b.event_id    = e.event_id
JOIN Users          u  ON e.organiser_id = u.user_id
JOIN Venue          v  ON e.venue_id    = v.venue_id
JOIN City           c  ON v.city_id     = c.city_id
JOIN Event_Category ec ON e.category_id = ec.category_id
WHERE p.payment_status = 'completed'
  AND b.booking_status = 'confirmed'
GROUP BY
    YEAR(p.paid_at), MONTH(p.paid_at), DATEPART(QUARTER, p.paid_at),
    e.organiser_id, u.full_name,
    ec.category_name, c.city_name;
GO


-- ═══════════════════════════════════════════════════════════════
-- 7. Stored procedure: create event with ticket types
-- ═══════════════════════════════════════════════════════════════

CREATE PROCEDURE sp_CreateEvent
    @organiser_id   INT,
    @title          NVARCHAR(300),
    @description    NVARCHAR(MAX),
    @start_datetime DATETIME,
    @end_datetime   DATETIME,
    @venue_id       INT,
    @category_id    INT,
    @image_url      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Event (title, description, start_datetime, end_datetime,
                           status, venue_id, category_id, organiser_id, image_url)
        VALUES (@title, @description, @start_datetime, @end_datetime,
                'upcoming', @venue_id, @category_id, @organiser_id, @image_url);

        DECLARE @event_id INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @event_id AS new_event_id;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT
            ERROR_NUMBER()  AS error_number,
            ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO


-- ═══════════════════════════════════════════════════════════════
-- 8. Stored procedure: delete event (only if no bookings)
-- ═══════════════════════════════════════════════════════════════

CREATE PROCEDURE sp_DeleteEvent
    @event_id     INT,
    @organiser_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- verify ownership
    IF NOT EXISTS (
        SELECT 1 FROM Event
        WHERE event_id = @event_id AND organiser_id = @organiser_id
    )
    BEGIN
        SELECT 'Event not found or you do not own this event.' AS error_message;
        RETURN;
    END

    -- check for bookings
    IF EXISTS (
        SELECT 1 FROM Booking WHERE event_id = @event_id
    )
    BEGIN
        SELECT 'Cannot delete event — bookings already exist.' AS error_message;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- delete ticket types first
        DELETE FROM Ticket_Type WHERE event_id = @event_id;

        -- delete the event
        DELETE FROM Event WHERE event_id = @event_id;

        COMMIT TRANSACTION;

        SELECT 'Event deleted successfully.' AS result;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT
            ERROR_NUMBER()  AS error_number,
            ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO


-- ═══════════════════════════════════════════════════════════════
-- 9. View: attendee list per event
-- ═══════════════════════════════════════════════════════════════

CREATE VIEW vw_EventAttendees AS
SELECT
    b.event_id,
    b.booking_id,
    b.booking_datetime,
    b.total_amt,
    b.booking_status,
    u.user_id,
    u.full_name     AS attendee_name,
    u.email         AS attendee_email,
    bi.quantity,
    bi.price_each,
    tt.type_name    AS ticket_type,
    p.payment_status
FROM Booking b
JOIN Users        u  ON b.user_id       = u.user_id
JOIN Booking_Item bi ON b.booking_id    = bi.booking_id
JOIN Ticket_Type  tt ON bi.ticket_type_id = tt.ticket_type_id
LEFT JOIN Payment p  ON b.booking_id    = p.booking_id
WHERE b.booking_status IN ('confirmed', 'pending');
GO


PRINT '=== Migration completed successfully ===';
GO
