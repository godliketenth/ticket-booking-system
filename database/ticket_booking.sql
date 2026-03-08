-- ticket_booking.sql
-- main schema file for the ticket booking system project
-- creates all tables with proper constraints and some sample data


CREATE DATABASE TicketBookingSystem;
GO

USE TicketBookingSystem;
GO


-- city table
-- stores city and state info
-- one city can have many venues

CREATE TABLE City (
    city_id    INT           NOT NULL IDENTITY(1,1),
    city_name  NVARCHAR(100) NOT NULL,
    state      NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_City             PRIMARY KEY (city_id),
    CONSTRAINT UQ_City_Name_State  UNIQUE (city_name, state)
);
GO


-- event category table
-- just stores category names like music, sports, comedy etc

CREATE TABLE Event_Category (
    category_id    INT           NOT NULL IDENTITY(1,1),
    category_name  NVARCHAR(100) NOT NULL,

    CONSTRAINT PK_Event_Category  PRIMARY KEY (category_id),
    CONSTRAINT UQ_Category_Name   UNIQUE (category_name)
);
GO


-- users table
-- handles customers, organizers and admins
-- password_hash because we never store plain text passwords

CREATE TABLE Users (
    user_id        INT           NOT NULL IDENTITY(1,1),
    full_name      NVARCHAR(150) NOT NULL,
    username       NVARCHAR(100) NOT NULL,
    email          NVARCHAR(255) NOT NULL,
    password_hash  NVARCHAR(255) NOT NULL,
    role           NVARCHAR(20)  NOT NULL DEFAULT 'customer',
    created_at     DATETIME      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Users       PRIMARY KEY (user_id),
    CONSTRAINT UQ_Users_Email UNIQUE (email),
    CONSTRAINT UQ_Users_Uname UNIQUE (username),
    CONSTRAINT CK_Users_Role  CHECK (role IN ('customer', 'organizer', 'admin'))
);
GO


-- venue table
-- a venue belongs to one city
-- capacity check so no one enters 0 or negative value

CREATE TABLE Venue (
    venue_id    INT           NOT NULL IDENTITY(1,1),
    venue_name  NVARCHAR(200) NOT NULL,
    address     NVARCHAR(500) NOT NULL,
    venue_type  NVARCHAR(50)  NOT NULL,
    capacity    INT           NOT NULL,
    city_id     INT           NOT NULL,

    CONSTRAINT PK_Venue          PRIMARY KEY (venue_id),
    CONSTRAINT FK_Venue_City     FOREIGN KEY (city_id) REFERENCES City(city_id),
    CONSTRAINT CK_Venue_Capacity CHECK (capacity > 0),
    CONSTRAINT CK_Venue_Type     CHECK (venue_type IN ('stadium', 'theatre', 'auditorium', 'open-air', 'hall', 'arena', 'other'))
);
GO


-- event table
-- linked to venue, category, and the organizer (user)
-- added a status column to track if event is upcoming, ongoing etc
-- end time must always be after start time

CREATE TABLE Event (
    event_id        INT            NOT NULL IDENTITY(1,1),
    title           NVARCHAR(300)  NOT NULL,
    description     NVARCHAR(MAX)  NULL,
    start_datetime  DATETIME       NOT NULL,
    end_datetime    DATETIME       NOT NULL,
    status          NVARCHAR(20)   NOT NULL DEFAULT 'upcoming',
    created_at      DATETIME       NOT NULL DEFAULT GETDATE(),
    venue_id        INT            NOT NULL,
    category_id     INT            NOT NULL,
    organiser_id    INT            NOT NULL,

    CONSTRAINT PK_Event           PRIMARY KEY (event_id),
    CONSTRAINT FK_Event_Venue     FOREIGN KEY (venue_id)     REFERENCES Venue(venue_id),
    CONSTRAINT FK_Event_Category  FOREIGN KEY (category_id)  REFERENCES Event_Category(category_id),
    CONSTRAINT FK_Event_Organiser FOREIGN KEY (organiser_id) REFERENCES Users(user_id),
    CONSTRAINT CK_Event_Dates     CHECK (end_datetime > start_datetime),
    CONSTRAINT CK_Event_Status    CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled'))
);
GO


-- ticket type table
-- each event can have multiple ticket types (vip, general etc)
-- available_quantity should never go below 0 or above total_quantity

CREATE TABLE Ticket_Type (
    ticket_type_id      INT            NOT NULL IDENTITY(1,1),
    type_name           NVARCHAR(100)  NOT NULL,
    price               DECIMAL(10,2)  NOT NULL,
    total_quantity      INT            NOT NULL,
    available_quantity  INT            NOT NULL,
    event_id            INT            NOT NULL,

    CONSTRAINT PK_Ticket_Type           PRIMARY KEY (ticket_type_id),
    CONSTRAINT FK_Ticket_Type_Event     FOREIGN KEY (event_id) REFERENCES Event(event_id),
    CONSTRAINT UQ_Ticket_Type_Per_Event UNIQUE (event_id, type_name),
    CONSTRAINT CK_Ticket_Price          CHECK (price >= 0),
    CONSTRAINT CK_Ticket_Total_Qty      CHECK (total_quantity > 0),
    CONSTRAINT CK_Ticket_Avail_Min      CHECK (available_quantity >= 0),
    CONSTRAINT CK_Ticket_Avail_Max      CHECK (available_quantity <= total_quantity)
);
GO


-- booking table
-- one user books tickets for one event
-- status tracks if the booking is pending, confirmed etc

CREATE TABLE Booking (
    booking_id        INT           NOT NULL IDENTITY(1,1),
    booking_datetime  DATETIME      NOT NULL DEFAULT GETDATE(),
    total_amt         DECIMAL(10,2) NOT NULL,
    booking_status    NVARCHAR(20)  NOT NULL DEFAULT 'pending',
    user_id           INT           NOT NULL,
    event_id          INT           NOT NULL,

    CONSTRAINT PK_Booking        PRIMARY KEY (booking_id),
    CONSTRAINT FK_Booking_User   FOREIGN KEY (user_id)  REFERENCES Users(user_id),
    CONSTRAINT FK_Booking_Event  FOREIGN KEY (event_id) REFERENCES Event(event_id),
    CONSTRAINT CK_Booking_Status CHECK (booking_status IN ('pending', 'confirmed', 'cancelled', 'refunded')),
    CONSTRAINT CK_Booking_Amt    CHECK (total_amt >= 0)
);
GO


-- booking item table
-- a booking can have multiple ticket types
-- storing subtotal here to preserve price at time of booking
-- same ticket type cant appear twice in one booking

CREATE TABLE Booking_Item (
    booking_item_id  INT           NOT NULL IDENTITY(1,1),
    quantity         INT           NOT NULL,
    price_each       DECIMAL(10,2) NOT NULL,
    subtotal         DECIMAL(10,2) NOT NULL,
    booking_id       INT           NOT NULL,
    ticket_type_id   INT           NOT NULL,

    CONSTRAINT PK_Booking_Item            PRIMARY KEY (booking_item_id),
    CONSTRAINT FK_Booking_Item_Booking    FOREIGN KEY (booking_id)     REFERENCES Booking(booking_id),
    CONSTRAINT FK_Booking_Item_TicketType FOREIGN KEY (ticket_type_id) REFERENCES Ticket_Type(ticket_type_id),
    CONSTRAINT UQ_Booking_Item            UNIQUE (booking_id, ticket_type_id),
    CONSTRAINT CK_Booking_Item_Qty        CHECK (quantity >= 1),
    CONSTRAINT CK_Booking_Item_Price      CHECK (price_each >= 0),
    CONSTRAINT CK_Booking_Item_Subtotal   CHECK (subtotal >= 0)
);
GO


-- payment table
-- one booking has exactly one payment
-- unique on booking_id enforces the 1:1 relationship
-- transaction_ref must be unique across all payments

CREATE TABLE Payment (
    payment_id       INT            NOT NULL IDENTITY(1,1),
    transaction_ref  NVARCHAR(200)  NOT NULL,
    payment_method   NVARCHAR(50)   NOT NULL,
    payment_status   NVARCHAR(20)   NOT NULL DEFAULT 'pending',
    paid_amt         DECIMAL(10,2)  NOT NULL,
    paid_at          DATETIME       NULL,
    booking_id       INT            NOT NULL,

    CONSTRAINT PK_Payment          PRIMARY KEY (payment_id),
    CONSTRAINT FK_Payment_Booking  FOREIGN KEY (booking_id)   REFERENCES Booking(booking_id),
    CONSTRAINT UQ_Payment_Booking  UNIQUE (booking_id),
    CONSTRAINT UQ_Payment_TxnRef   UNIQUE (transaction_ref),
    CONSTRAINT CK_Payment_Method   CHECK (payment_method IN ('credit_card', 'debit_card', 'upi', 'net_banking', 'wallet', 'cash')),
    CONSTRAINT CK_Payment_Status   CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    CONSTRAINT CK_Payment_Amt      CHECK (paid_amt >= 0)
);
GO


-- review table
-- users leave reviews for events they attended
-- one review per user per event using composite unique

CREATE TABLE Review (
    review_id    INT           NOT NULL IDENTITY(1,1),
    rating       TINYINT       NOT NULL,
    comment      NVARCHAR(MAX) NULL,
    review_date  DATETIME      NOT NULL DEFAULT GETDATE(),
    user_id      INT           NOT NULL,
    event_id     INT           NOT NULL,

    CONSTRAINT PK_Review            PRIMARY KEY (review_id),
    CONSTRAINT FK_Review_User       FOREIGN KEY (user_id)  REFERENCES Users(user_id),
    CONSTRAINT FK_Review_Event      FOREIGN KEY (event_id) REFERENCES Event(event_id),
    CONSTRAINT UQ_Review_User_Event UNIQUE (user_id, event_id),
    CONSTRAINT CK_Review_Rating     CHECK (rating BETWEEN 1 AND 5)
);
GO


-- -------------------------------------------------------
-- sample data
-- -------------------------------------------------------

INSERT INTO City (city_name, state) VALUES
('Mumbai',    'Maharashtra'),
('Bangalore', 'Karnataka'),
('Delhi',     'Delhi');

INSERT INTO Event_Category (category_name) VALUES
('Music'),
('Sports'),
('Comedy'),
('Technology'),
('Theatre');

-- passwords are hashed in real usage, using placeholders here
INSERT INTO Users (full_name, username, email, password_hash, role) VALUES
('Arjun Sharma',  'arjun_s',  'arjun@example.com',  'hashed_pw_1', 'customer'),
('Priya Mehta',   'priya_m',  'priya@example.com',  'hashed_pw_2', 'organizer'),
('Rohan Das',     'rohan_d',  'rohan@example.com',  'hashed_pw_3', 'customer'),
('Admin User',    'admin_01', 'admin@tbs.com',       'hashed_pw_4', 'admin');

INSERT INTO Venue (venue_name, address, venue_type, capacity, city_id) VALUES
('NSCI Dome',            'Worli, Mumbai',           'arena',      10000, 1),
('Palace Grounds',       'Jayamahal Rd, Bangalore', 'open-air',   15000, 2),
('Siri Fort Auditorium', 'Khel Gaon, Delhi',        'auditorium',  2000, 3);

INSERT INTO Event (title, description, start_datetime, end_datetime, status, venue_id, category_id, organiser_id) VALUES
('Sunburn Festival',      'Biggest EDM festival in India',    '2025-12-20 18:00', '2025-12-20 23:59', 'upcoming',  1, 1, 2),
('Stand-Up Night Mumbai', 'Top comedians live on stage',      '2025-11-10 20:00', '2025-11-10 22:30', 'upcoming',  1, 3, 2),
('TechSummit 2025',       'Annual tech conference Bangalore', '2025-10-05 09:00', '2025-10-05 18:00', 'completed', 2, 4, 2);

INSERT INTO Ticket_Type (type_name, price, total_quantity, available_quantity, event_id) VALUES
('General',  999.00, 5000, 4800, 1),
('VIP',     3999.00,  500,  490, 1),
('Standard', 299.00, 1000,  950, 2),
('Delegate', 499.00,  800,  750, 3),
('Workshop',1499.00,  100,   80, 3);

INSERT INTO Booking (total_amt, booking_status, user_id, event_id) VALUES
(3998.00, 'confirmed', 1, 1),
( 598.00, 'confirmed', 3, 2);

INSERT INTO Booking_Item (quantity, price_each, subtotal, booking_id, ticket_type_id) VALUES
(2,  999.00, 1998.00, 1, 1),
(1, 2000.00, 2000.00, 1, 2),
(2,  299.00,  598.00, 2, 3);

INSERT INTO Payment (transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id) VALUES
('TXN20251001001', 'upi',         'completed', 3998.00, '2025-10-01 14:32:00', 1),
('TXN20251002002', 'credit_card', 'completed',  598.00, '2025-10-02 11:10:00', 2);

INSERT INTO Review (rating, comment, user_id, event_id) VALUES
(5, 'Amazing festival, sound quality was top notch.',   1, 1),
(4, 'Great show, but the venue was a bit too crowded.', 3, 2);
GO
