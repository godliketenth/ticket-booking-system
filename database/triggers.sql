-- triggers.sql
-- automatic triggers that fire on insert/update/delete
-- run this after ticket_booking.sql

USE TicketBookingSystem;
GO


-- trigger 1: reduce available_quantity when a booking item is inserted
-- fires automatically after every insert into Booking_Item
-- this keeps ticket inventory in sync without manual updates in the app

CREATE TRIGGER trg_ReduceTicketOnBooking
ON Booking_Item
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE tt
    SET tt.available_quantity = tt.available_quantity - i.quantity
    FROM Ticket_Type tt
    JOIN inserted i ON tt.ticket_type_id = i.ticket_type_id;

    -- safety check: if available_quantity went below 0, roll it back
    IF EXISTS (
        SELECT 1 FROM Ticket_Type WHERE available_quantity < 0
    )
    BEGIN
        RAISERROR('Not enough tickets available. Booking rolled back.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- trigger 2: restore available_quantity when a booking item is deleted
-- fires when booking items are removed (e.g. when a booking gets cancelled)

CREATE TRIGGER trg_RestoreTicketOnCancel
ON Booking_Item
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE tt
    SET tt.available_quantity = tt.available_quantity + d.quantity
    FROM Ticket_Type tt
    JOIN deleted d ON tt.ticket_type_id = d.ticket_type_id;
END;
GO


-- trigger 3: auto update total_amt in Booking when items change
-- fires after insert or update on Booking_Item
-- recalculates the total from all items in that booking

CREATE TRIGGER trg_UpdateBookingTotal
ON Booking_Item
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.total_amt = (
        SELECT ISNULL(SUM(bi.subtotal), 0)
        FROM Booking_Item bi
        WHERE bi.booking_id = b.booking_id
    )
    FROM Booking b
    WHERE b.booking_id IN (SELECT DISTINCT booking_id FROM inserted);
END;
GO


-- trigger 4: prevent booking into a cancelled or completed event
-- fires AFTER a booking is inserted
-- rolls back if the event is not in upcoming or ongoing state
-- NOTE: using AFTER INSERT (not INSTEAD OF) so that SCOPE_IDENTITY()
--       in the calling stored procedure still works correctly

CREATE TRIGGER trg_BlockBookingForClosedEvent
ON Booking
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- check if any of the events being booked are closed
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Event e ON i.event_id = e.event_id
        WHERE e.status IN ('cancelled', 'completed')
    )
    BEGIN
        RAISERROR('Cannot book tickets for a cancelled or completed event.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- trigger 5: prevent duplicate payment insert
-- fires before insert on Payment
-- checks if a payment already exists for that booking

CREATE TRIGGER trg_BlockDuplicatePayment
ON Payment
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Payment p ON i.booking_id = p.booking_id
    )
    BEGIN
        RAISERROR('A payment already exists for this booking.', 16, 1);
        RETURN;
    END

    INSERT INTO Payment (transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id)
    SELECT transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id
    FROM inserted;
END;
GO


DROP TRIGGER IF EXISTS trg_BlockBookingForClosedEvent;
GO

CREATE TRIGGER trg_BlockBookingForClosedEvent
ON Booking
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Event e ON i.event_id = e.event_id
        WHERE e.status IN ('cancelled', 'completed')
    )
    BEGIN
        RAISERROR('Cannot book tickets for a cancelled or completed event.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO