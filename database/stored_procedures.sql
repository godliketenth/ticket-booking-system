-- stored_procedures.sql
-- stored procedures for the main booking flow
-- run this after ticket_booking.sql and views.sql

USE TicketBookingSystem;
GO


-- procedure 1: create a new booking
-- takes user id, event id, and a ticket request in json format
-- checks availability before inserting
-- rolls back everything if anything fails

CREATE PROCEDURE sp_CreateBooking
    @user_id       INT,
    @event_id      INT,
    @ticket_type_id INT,
    @quantity      INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- check if enough tickets are available
        DECLARE @available INT;
        SELECT @available = available_quantity
        FROM Ticket_Type
        WHERE ticket_type_id = @ticket_type_id AND event_id = @event_id;

        IF @available IS NULL
        BEGIN
            RAISERROR('Ticket type not found for this event.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @available < @quantity
        BEGIN
            RAISERROR('Not enough tickets available.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- get price
        DECLARE @price_each DECIMAL(10,2);
        SELECT @price_each = price
        FROM Ticket_Type
        WHERE ticket_type_id = @ticket_type_id;

        DECLARE @subtotal  DECIMAL(10,2) = @price_each * @quantity;

        -- create the booking record
        DECLARE @booking_id INT;
        INSERT INTO Booking (total_amt, booking_status, user_id, event_id)
        VALUES (@subtotal, 'pending', @user_id, @event_id);

        SET @booking_id = SCOPE_IDENTITY();

        -- insert booking item
        INSERT INTO Booking_Item (quantity, price_each, subtotal, booking_id, ticket_type_id)
        VALUES (@quantity, @price_each, @subtotal, @booking_id, @ticket_type_id);

        -- reduce available quantity (trigger also does this, procedure is a backup)
        UPDATE Ticket_Type
        SET available_quantity = available_quantity - @quantity
        WHERE ticket_type_id = @ticket_type_id;

        COMMIT TRANSACTION;

        -- return the new booking id
        SELECT @booking_id AS new_booking_id, @subtotal AS total_amt;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- return the error so the app can handle it
        SELECT
            ERROR_NUMBER()  AS error_number,
            ERROR_MESSAGE() AS error_message;
    END CATCH
END;
GO


-- procedure 2: confirm payment for a booking
-- updates booking status to confirmed
-- inserts a payment record

CREATE PROCEDURE sp_ConfirmPayment
    @booking_id      INT,
    @payment_method  NVARCHAR(50),
    @transaction_ref NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- check booking exists and is still pending
        DECLARE @status NVARCHAR(20);
        DECLARE @amt    DECIMAL(10,2);

        SELECT @status = booking_status, @amt = total_amt
        FROM Booking
        WHERE booking_id = @booking_id;

        IF @status IS NULL
        BEGIN
            RAISERROR('Booking not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @status != 'pending'
        BEGIN
            RAISERROR('Booking is not in pending state.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- insert payment record
        INSERT INTO Payment (transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id)
        VALUES (@transaction_ref, @payment_method, 'completed', @amt, GETDATE(), @booking_id);

        -- update booking status
        UPDATE Booking
        SET booking_status = 'confirmed'
        WHERE booking_id = @booking_id;

        COMMIT TRANSACTION;

        SELECT 'Payment confirmed successfully.' AS result;

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


-- procedure 3: cancel a booking
-- restores ticket quantity back
-- marks booking as cancelled

CREATE PROCEDURE sp_CancelBooking
    @booking_id INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @status NVARCHAR(20);
        SELECT @status = booking_status FROM Booking WHERE booking_id = @booking_id;

        IF @status IS NULL
        BEGIN
            RAISERROR('Booking not found.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @status IN ('cancelled', 'refunded')
        BEGIN
            RAISERROR('Booking is already cancelled or refunded.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- restore ticket quantities from booking items
        UPDATE tt
        SET tt.available_quantity = tt.available_quantity + bi.quantity
        FROM Ticket_Type tt
        JOIN Booking_Item bi ON tt.ticket_type_id = bi.ticket_type_id
        WHERE bi.booking_id = @booking_id;

        -- mark booking as cancelled
        UPDATE Booking
        SET booking_status = 'cancelled'
        WHERE booking_id = @booking_id;

        -- mark payment as refunded if it exists
        UPDATE Payment
        SET payment_status = 'refunded'
        WHERE booking_id = @booking_id AND payment_status = 'completed';

        COMMIT TRANSACTION;

        SELECT 'Booking cancelled successfully.' AS result;

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


-- procedure 4: get all bookings for a user
-- returns booking history with event and payment info

CREATE PROCEDURE sp_GetUserBookings
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.booking_id,
        b.booking_datetime,
        b.total_amt,
        b.booking_status,
        e.title         AS event_title,
        e.start_datetime,
        v.venue_name,
        c.city_name,
        p.payment_method,
        p.payment_status,
        p.paid_at
    FROM Booking b
    JOIN Event   e ON b.event_id    = e.event_id
    JOIN Venue   v ON e.venue_id    = v.venue_id
    JOIN City    c ON v.city_id     = c.city_id
    LEFT JOIN Payment p ON b.booking_id = p.booking_id
    WHERE b.user_id = @user_id
    ORDER BY b.booking_datetime DESC;
END;
GO


-- procedure 5: get ticket types for an event
-- used on the event detail page to show what tickets are available

CREATE PROCEDURE sp_GetEventTickets
    @event_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ticket_type_id,
        type_name,
        price,
        total_quantity,
        available_quantity,
        (total_quantity - available_quantity) AS sold
    FROM Ticket_Type
    WHERE event_id = @event_id
    ORDER BY price ASC;
END;
GO
