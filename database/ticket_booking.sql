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




-- 6 more cities (IDs 7-12)
INSERT INTO City (city_name, state) VALUES
('Kolkata',    'West Bengal'),
('Ahmedabad',  'Gujarat'),
('Jaipur',     'Rajasthan'),
('Lucknow',    'Uttar Pradesh'),
('Kochi',      'Kerala'),
('Chandigarh', 'Punjab');

-- 20 more users (IDs 9-28)
INSERT INTO Users (full_name, username, email, password_hash, role) VALUES
('Rahul Verma',       'rahul_v',    'rahul.v@example.com',    'hashed_pw_9',  'customer'),   -- 9
('Meera Iyer',        'meera_i',    'meera.i@example.com',    'hashed_pw_10', 'customer'),   -- 10
('Aditya Khanna',     'aditya_k',   'aditya.k@example.com',   'hashed_pw_11', 'organizer'),  -- 11
('Pooja Desai',       'pooja_d',    'pooja.d@example.com',    'hashed_pw_12', 'customer'),   -- 12
('Nikhil Rao',        'nikhil_r',   'nikhil.r@example.com',   'hashed_pw_13', 'customer'),   -- 13
('Tanya Singh',       'tanya_s',    'tanya.s@example.com',    'hashed_pw_14', 'customer'),   -- 14
('Ishaan Malhotra',   'ishaan_m',   'ishaan.m@example.com',   'hashed_pw_15', 'customer'),   -- 15
('Divya Nambiar',     'divya_n',    'divya.n@example.com',    'hashed_pw_16', 'customer'),   -- 16
('Siddharth Joshi',   'sid_j',      'sid.j@example.com',      'hashed_pw_17', 'organizer'),  -- 17
('Kavya Reddy',       'kavya_r',    'kavya.r@example.com',    'hashed_pw_18', 'customer'),   -- 18
('Arnav Gupta',       'arnav_g',    'arnav.g@example.com',    'hashed_pw_19', 'customer'),   -- 19
('Shruti Pillai',     'shruti_p',   'shruti.p@example.com',   'hashed_pw_20', 'customer'),   -- 20
('Manish Tiwari',     'manish_t',   'manish.t@example.com',   'hashed_pw_21', 'customer'),   -- 21
('Riya Chatterjee',   'riya_c',     'riya.c@example.com',     'hashed_pw_22', 'customer'),   -- 22
('Harsh Agarwal',     'harsh_a',    'harsh.a@example.com',    'hashed_pw_23', 'customer'),   -- 23
('Nandini Saxena',    'nandini_s',  'nandini.s@example.com',  'hashed_pw_24', 'customer'),   -- 24
('Kunal Mehta',       'kunal_m',    'kunal.m@example.com',    'hashed_pw_25', 'organizer'),  -- 25
('Preethi Suresh',    'preethi_su', 'preethi.su@example.com', 'hashed_pw_26', 'customer'),   -- 26
('Aarav Shah',        'aarav_sh',   'aarav.sh@example.com',   'hashed_pw_27', 'customer'),   -- 27
('Deepika Bhatia',    'deepika_b',  'deepika.b@example.com',  'hashed_pw_28', 'customer');   -- 28

-- 6 more venues (IDs 7-12)
INSERT INTO Venue (venue_name, address, venue_type, capacity, city_id) VALUES
('Netaji Indoor Stadium',   'Kolkata Gate, Kolkata',          'arena',      12000, 7),   -- 7
('Sardar Patel Stadium',    'Navrangpura, Ahmedabad',         'stadium',    25000, 8),   -- 8
('Jawahar Kala Kendra',     'JLN Marg, Jaipur',               'auditorium',  3000, 9),   -- 9
('Ravindralaya Auditorium', 'Hazratganj, Lucknow',            'auditorium',  2500, 10),  -- 10
('Bolgatty Palace Grounds', 'Mulavukad Island, Kochi',        'open-air',    5000, 11),  -- 11
('Tagore Theatre',          'Sector 18, Chandigarh',          'theatre',     1800, 12);  -- 12

-- 13 more events (IDs 8-20)
-- organiser_ids: 11=Aditya, 17=Siddharth, 25=Kunal, 2=Priya, 6=Vikram
INSERT INTO Event (title, description, start_datetime, end_datetime, status, venue_id, category_id, organiser_id) VALUES
('Kolkata Jazz Night',           'Smooth jazz and blues by top artists',             '2025-11-15 19:00', '2025-11-15 22:30', 'completed',  7,  1, 11),  -- 8
('Ahmedabad Marathon 2025',      'City-wide marathon with 5k, 10k, and 21k tracks', '2025-12-07 06:00', '2025-12-07 12:00', 'upcoming',   8,  2, 17),  -- 9
('Jaipur Literature Fest',       'Authors, poets and thinkers from across India',    '2026-01-20 10:00', '2026-01-22 18:00', 'upcoming',   9,  5, 25),  -- 10
('Lucknow Comedy Nights',        'Nawabi humour with a modern twist',                '2025-11-28 20:00', '2025-11-28 22:30', 'completed', 10,  3, 11),  -- 11
('Kochi International Film Fest','Screenings and panels on world cinema',            '2025-12-14 10:00', '2025-12-16 22:00', 'upcoming',  11,  5, 17),  -- 12
('Chandigarh Rock Festival',     'Three bands, one epic night of rock',              '2025-12-21 17:00', '2025-12-21 23:30', 'upcoming',  12,  1, 25),  -- 13
('Mumbai Startup Summit',        'Pitches, panels and networking for founders',      '2026-02-10 09:00', '2026-02-10 18:00', 'upcoming',   1,  4,  2),  -- 14
('Bangalore Food & Music Fest',  'Live bands paired with cuisines from 15 states',  '2025-12-25 12:00', '2025-12-25 22:00', 'upcoming',   2,  1,  6),  -- 15
('Delhi Comedy Gala',            'New Year special stand-up comedy show',            '2025-12-31 20:30', '2025-12-31 23:30', 'upcoming',   3,  3, 11),  -- 16
('Jaipur Heritage Walk Concert', 'Classical Rajasthani folk music at Amer Fort',     '2026-01-26 17:00', '2026-01-26 21:00', 'upcoming',   9,  1, 25),  -- 17
('Hyderabad Sports Carnival',    'Amateur sports tournaments across 8 disciplines', '2025-11-30 08:00', '2025-11-30 18:00', 'completed',  5,  2, 17),  -- 18
('Kochi Yoga & Wellness Summit', 'Expert-led yoga sessions and wellness workshops',  '2026-03-08 07:00', '2026-03-08 13:00', 'upcoming',  11,  5,  2),  -- 19
('Pune Stand-Up Open Mic',       'Fresh voices from the Pune comedy circuit',        '2025-11-20 20:00', '2025-11-20 22:00', 'completed',  4,  3,  6);  -- 20

-- ticket types (IDs 12-37, picking up after batch 2 left off at ID 11)
INSERT INTO Ticket_Type (type_name, price, total_quantity, available_quantity, event_id) VALUES
-- event 8: Kolkata Jazz Night
('General',         349.00,  1500, 1100,  8),  -- 12
('Premium',         799.00,   300,  210,  8),  -- 13
-- event 9: Ahmedabad Marathon
('5K Entry',        299.00,  2000, 1650,  9),  -- 14
('10K Entry',       499.00,  1500, 1200,  9),  -- 15
('21K Entry',       799.00,   500,  380,  9),  -- 16
-- event 10: Jaipur Lit Fest
('Day Pass',        599.00,  1000,  820, 10),  -- 17
('Full Festival',   999.00,   500,  390, 10),  -- 18
-- event 11: Lucknow Comedy Nights
('Standard',        299.00,   800,  550, 11),  -- 19
('VIP',             699.00,   150,   90, 11),  -- 20
-- event 12: Kochi Film Fest
('Single Day',      399.00,   800,  650, 12),  -- 21
('All 3 Days',      899.00,   300,  220, 12),  -- 22
-- event 13: Chandigarh Rock Fest
('General',         449.00,  1200, 1000, 13),  -- 23
('Pit Pass',       1299.00,   200,  165, 13),  -- 24
-- event 14: Mumbai Startup Summit
('Delegate',        999.00,   600,  510, 14),  -- 25
('Workshop Add-on', 499.00,   200,  170, 14),  -- 26
-- event 15: Bangalore Food & Music Fest
('Entry',           199.00,  5000, 4200, 15),  -- 27
('Premium Lounge',  999.00,   300,  240, 15),  -- 28
-- event 16: Delhi Comedy Gala
('Standard',        599.00,   800,  620, 16),  -- 29
('Front Row',      1199.00,   100,   75, 16),  -- 30
-- event 17: Jaipur Heritage Concert
('General',         499.00,  1000,  830, 17),  -- 31
('Heritage Box',   1499.00,    80,   55, 17),  -- 32
-- event 18: Hyderabad Sports Carnival
('Participant',     199.00,  2000, 1400, 18),  -- 33
('Spectator',        99.00,  3000, 2500, 18),  -- 34
-- event 19: Kochi Yoga Summit
('Morning Session', 299.00,   400,  340, 19),  -- 35
('Full Day',        599.00,   200,  165, 19),  -- 36
-- event 20: Pune Open Mic
('Entry',           149.00,   500,  380, 20);  -- 37

-- bookings (IDs 7-26, picking up after batch 2 left off at 6)
-- user IDs now correctly match named users
INSERT INTO Booking (total_amt, booking_status, user_id, event_id) VALUES
( 698.00, 'confirmed', 18,  8),   -- 7:  Kavya,    Kolkata Jazz Night
( 799.00, 'confirmed', 19,  8),   -- 8:  Arnav,    Kolkata Jazz Night
( 598.00, 'confirmed', 21,  9),   -- 9:  Manish,   Ahmedabad Marathon
( 499.00, 'confirmed', 23,  9),   -- 10: Harsh,    Ahmedabad Marathon
( 999.00, 'confirmed', 24, 10),   -- 11: Nandini,  Jaipur Lit Fest
( 598.00, 'confirmed', 22, 11),   -- 12: Riya,     Lucknow Comedy Nights
( 699.00, 'confirmed', 18, 11),   -- 13: Kavya,    Lucknow Comedy Nights
( 399.00, 'confirmed', 26, 12),   -- 14: Preethi,  Kochi Film Fest
( 898.00, 'confirmed', 27, 13),   -- 15: Aarav,    Chandigarh Rock Fest
( 999.00, 'confirmed', 28, 14),   -- 16: Deepika,  Mumbai Startup Summit
( 398.00, 'confirmed', 15, 15),   -- 17: Ishaan,   Bangalore Food & Music Fest
( 599.00, 'confirmed', 13, 16),   -- 18: Nikhil,   Delhi Comedy Gala
(1199.00, 'confirmed', 26, 16),   -- 19: Preethi,  Delhi Comedy Gala (front row)
( 499.00, 'pending',    8, 17),   -- 20: Kabir,    Jaipur Heritage (pending, no payment)
( 199.00, 'confirmed', 22, 18),   -- 21: Riya,     Hyderabad Sports Carnival
( 299.00, 'confirmed', 24, 19),   -- 22: Nandini,  Kochi Yoga Summit
( 447.00, 'confirmed', 20, 20),   -- 23: Shruti,   Pune Open Mic
( 398.00, 'cancelled', 18, 15),   -- 24: Kavya,    Bangalore Food Fest (cancelled, no payment)
(1299.00, 'confirmed', 19, 13),   -- 25: Arnav,    Chandigarh Rock (pit pass)
(1998.00, 'confirmed', 27, 17);   -- 26: Aarav,    Jaipur Heritage (general + heritage box)

-- booking items
-- ticket_type_id values now match the corrected IDs above
INSERT INTO Booking_Item (quantity, price_each, subtotal, booking_id, ticket_type_id) VALUES
(2,  349.00,  698.00,  7, 12),  -- booking 7:  2x General Jazz (tt=12)
(1,  799.00,  799.00,  8, 13),  -- booking 8:  1x Premium Jazz (tt=13)
(2,  299.00,  598.00,  9, 14),  -- booking 9:  2x 5K Marathon (tt=14)
(1,  499.00,  499.00, 10, 15),  -- booking 10: 1x 10K Marathon (tt=15)
(1,  999.00,  999.00, 11, 18),  -- booking 11: 1x Full Festival Jaipur (tt=18)
(2,  299.00,  598.00, 12, 19),  -- booking 12: 2x Standard Lucknow Comedy (tt=19)
(1,  699.00,  699.00, 13, 20),  -- booking 13: 1x VIP Lucknow Comedy (tt=20)
(1,  399.00,  399.00, 14, 21),  -- booking 14: 1x Single Day Film Fest (tt=21)
(2,  449.00,  898.00, 15, 23),  -- booking 15: 2x General Rock Fest (tt=23)
(1,  999.00,  999.00, 16, 25),  -- booking 16: 1x Delegate Startup Summit (tt=25)
(2,  199.00,  398.00, 17, 27),  -- booking 17: 2x Entry Food Fest (tt=27)
(1,  599.00,  599.00, 18, 29),  -- booking 18: 1x Standard Comedy Gala (tt=29)
(1, 1199.00, 1199.00, 19, 30),  -- booking 19: 1x Front Row Comedy Gala (tt=30)
(1,  499.00,  499.00, 20, 31),  -- booking 20: 1x General Jaipur Heritage (tt=31) [pending]
(1,  199.00,  199.00, 21, 33),  -- booking 21: 1x Participant Sports Carnival (tt=33)
(1,  299.00,  299.00, 22, 35),  -- booking 22: 1x Morning Session Yoga (tt=35)
(3,  149.00,  447.00, 23, 37),  -- booking 23: 3x Entry Open Mic (tt=37)
(2,  199.00,  398.00, 24, 27),  -- booking 24: 2x Entry Food Fest (tt=27) [cancelled]
(1, 1299.00, 1299.00, 25, 24),  -- booking 25: 1x Pit Pass Rock Fest (tt=24)
(1,  499.00,  499.00, 26, 31),  -- booking 26: 1x General Jaipur Heritage (tt=31)
(1, 1499.00, 1499.00, 26, 32);  -- booking 26: 1x Heritage Box (tt=32)

-- payments
-- booking 20 (pending) and booking 24 (cancelled) intentionally have no payment
-- TXN refs are all unique across all 3 batches
INSERT INTO Payment (transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id) VALUES
('TXN20251114001', 'upi',          'completed',   698.00, '2025-11-14 20:10:00',  7),
('TXN20251114002', 'credit_card',  'completed',   799.00, '2025-11-14 20:45:00',  8),
('TXN20251130001', 'debit_card',   'completed',   598.00, '2025-11-29 09:15:00',  9),
('TXN20251130002', 'upi',          'completed',   499.00, '2025-11-29 09:55:00', 10),
('TXN20251228001', 'net_banking',  'completed',   999.00, '2025-12-28 11:30:00', 11),
('TXN20251127001', 'wallet',       'completed',   598.00, '2025-11-27 18:20:00', 12),
('TXN20251127002', 'credit_card',  'completed',   699.00, '2025-11-27 18:55:00', 13),
('TXN20251209001', 'upi',          'completed',   399.00, '2025-12-09 14:00:00', 14),
('TXN20251210002', 'debit_card',   'completed',   898.00, '2025-12-10 16:30:00', 15),  -- note: 002 not 001 (001 used in batch 2)
('TXN20260115001', 'net_banking',  'completed',   999.00, '2026-01-15 10:00:00', 16),
('TXN20251219001', 'upi',          'completed',   398.00, '2025-12-19 12:45:00', 17),
('TXN20251220001', 'credit_card',  'completed',   599.00, '2025-12-20 09:00:00', 18),
('TXN20251220002', 'wallet',       'completed',  1199.00, '2025-12-20 09:30:00', 19),
('TXN20251129001', 'cash',         'completed',   199.00, '2025-11-29 07:45:00', 21),
('TXN20260220001', 'debit_card',   'completed',   299.00, '2026-02-20 08:00:00', 22),
('TXN20251119001', 'upi',          'completed',   447.00, '2025-11-19 19:00:00', 23),
('TXN20251211001', 'credit_card',  'completed',  1299.00, '2025-12-11 17:20:00', 25),
('TXN20260121001', 'net_banking',  'completed',  1998.00, '2026-01-21 13:15:00', 26);

-- reviews
-- only for completed events (8, 11, 18, 20) by users who have confirmed bookings
INSERT INTO Review (rating, comment, user_id, event_id) VALUES
(5, 'Jazz Night was phenomenal. The saxophone set was unforgettable.',        18,  8),  -- Kavya  ✓
(4, 'Great atmosphere. Parking was a bit of a hassle though.',                19,  8),  -- Arnav  ✓
(5, 'Lucknow Comedy Night had me in tears. Brilliant lineup.',                22, 11),  -- Riya   ✓
(3, 'Decent show but some acts ran way too long.',                            18, 11),  -- Kavya  ✓
(5, 'Sports Carnival was incredibly well organised.',                         22, 18),  -- Riya   ✓
(4, 'Pune Open Mic had some really fresh talent. Will come again.',           20, 20);  -- Shruti ✓
GO