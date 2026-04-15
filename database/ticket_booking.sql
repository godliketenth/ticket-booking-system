-- ticket_booking.sql
-- main schema file for the ticket booking system project
-- creates all tables with proper constraints and sample data


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


-- =============================================================
-- SAMPLE DATA — single clean block, correct FK references
--
-- ID reference map:
-- Cities      : 1=Mumbai 2=Bangalore 3=Delhi 4=Kolkata 5=Ahmedabad
--               6=Jaipur 7=Lucknow 8=Kochi 9=Chandigarh 10=Hyderabad 11=Pune
-- Categories  : 1=Music 2=Sports 3=Comedy 4=Technology 5=Theatre
-- Users       : 1=Arjun(C) 2=Priya(O) 3=Rohan(C) 4=Admin 5=Rahul(C)
--               6=Meera(C) 7=Aditya_K(O) 8=Pooja(C) 9=Nikhil(C) 10=Tanya(C)
--               11=Ishaan(C) 12=Divya(C) 13=Siddharth(O) 14=Kavya(C)
--               15=Arnav(C) 16=Shruti(C) 17=Manish(C) 18=Riya(C)
--               19=Harsh(C) 20=Nandini(C) 21=Kunal(O) 22=Preethi(C)
--               23=Aarav(C) 24=Deepika(C)   [C=customer O=organizer]
-- Venues      : 1=NSCI(Mumbai) 2=Palace(Bangalore) 3=SiriFort(Delhi)
--               4=Netaji(Kolkata) 5=SardarPatel(Ahmedabad) 6=JKK(Jaipur)
--               7=Ravindralaya(Lucknow) 8=Bolgatty(Kochi) 9=Tagore(Chandigarh)
--               10=HITEX(Hyderabad) 11=Symbiosis(Pune)
-- Events      : 1-16 (see inserts below)
-- Ticket Types: 1-5 for events 1-3, 6-31 for events 4-16
-- Bookings    : 1-22 (16=pending no payment, 20=cancelled no payment)
-- =============================================================


-- cities (IDs 1-11)
INSERT INTO City (city_name, state) VALUES
('Mumbai',     'Maharashtra'),    -- 1
('Bangalore',  'Karnataka'),      -- 2
('Delhi',      'Delhi'),          -- 3
('Kolkata',    'West Bengal'),    -- 4
('Ahmedabad',  'Gujarat'),        -- 5
('Jaipur',     'Rajasthan'),      -- 6
('Lucknow',    'Uttar Pradesh'),  -- 7
('Kochi',      'Kerala'),         -- 8
('Chandigarh', 'Punjab'),         -- 9
('Hyderabad',  'Telangana'),      -- 10
('Pune',       'Maharashtra');    -- 11


-- categories (IDs 1-5)
INSERT INTO Event_Category (category_name) VALUES
('Music'),       -- 1
('Sports'),      -- 2
('Comedy'),      -- 3
('Technology'),  -- 4
('Theatre');     -- 5


-- users (IDs 1-24)
INSERT INTO Users (full_name, username, email, password_hash, role) VALUES
('S J', 'sidj',      'sidj@example.com',  'pbkdf2:sha256:1000000$QthLu3uQfFPUYtPP$2d0caf969168727d3b80e6c8535313fd6e300e0aceb7360a3bd08d47aa26681a', 'organizer'),
('admin',    'admin1',    'admin@example.com',      'pbkdf2:sha256:1000000$QthLu3uQfFPUYtPP$2d0caf969168727d3b80e6c8535313fd6e300e0aceb7360a3bd08d47aa26681a', 'admin'),
('Arjun Sharma',    'arjun_s',    'arjun@example.com',      'hashed_pw_1',  'customer'),   -- 1
('Priya Mehta',     'priya_m',    'priya@example.com',      'hashed_pw_2',  'organizer'),  -- 2
('Rohan Das',       'rohan_d',    'rohan@example.com',      'hashed_pw_3',  'customer'),   -- 3
('Admin User',      'admin_01',   'admin@tbs.com',           'hashed_pw_4',  'admin'),      -- 4
('Rahul Verma',     'rahul_v',    'rahul.v@example.com',    'hashed_pw_5',  'customer'),   -- 5
('Meera Iyer',      'meera_i',    'meera.i@example.com',    'hashed_pw_6',  'customer'),   -- 6
('Aditya Khanna',   'aditya_k',   'aditya.k@example.com',   'hashed_pw_7',  'organizer'),  -- 7
('Pooja Desai',     'pooja_d',    'pooja.d@example.com',    'hashed_pw_8',  'customer'),   -- 8
('Nikhil Rao',      'nikhil_r',   'nikhil.r@example.com',   'hashed_pw_9',  'customer'),   -- 9
('Tanya Singh',     'tanya_s',    'tanya.s@example.com',    'hashed_pw_10', 'customer'),   -- 10
('Ishaan Malhotra', 'ishaan_m',   'ishaan.m@example.com',   'hashed_pw_11', 'customer'),   -- 11
('Divya Nambiar',   'divya_n',    'divya.n@example.com',    'hashed_pw_12', 'customer'),   -- 12
('Siddharth Joshi', 'sid_j',      'sid.j@example.com',      'hashed_pw_13', 'organizer'),  -- 13
('Kavya Reddy',     'kavya_r',    'kavya.r@example.com',    'hashed_pw_14', 'customer'),   -- 14
('Arnav Gupta',     'arnav_g',    'arnav.g@example.com',    'hashed_pw_15', 'customer'),   -- 15
('Shruti Pillai',   'shruti_p',   'shruti.p@example.com',   'hashed_pw_16', 'customer'),   -- 16
('Manish Tiwari',   'manish_t',   'manish.t@example.com',   'hashed_pw_17', 'customer'),   -- 17
('Riya Chatterjee', 'riya_c',     'riya.c@example.com',     'hashed_pw_18', 'customer'),   -- 18
('Harsh Agarwal',   'harsh_a',    'harsh.a@example.com',    'hashed_pw_19', 'customer'),   -- 19
('Nandini Saxena',  'nandini_s',  'nandini.s@example.com',  'hashed_pw_20', 'customer'),   -- 20
('Kunal Mehta',     'kunal_m',    'kunal.m@example.com',    'hashed_pw_21', 'organizer'),  -- 21
('Preethi Suresh',  'preethi_su', 'preethi.su@example.com', 'hashed_pw_22', 'customer'),   -- 22
('Aarav Shah',      'aarav_sh',   'aarav.sh@example.com',   'hashed_pw_23', 'customer'),   -- 23
('Deepika Bhatia',  'deepika_b',  'deepika.b@example.com',  'hashed_pw_24', 'customer');   -- 24


-- venues (IDs 1-11)
INSERT INTO Venue (venue_name, address, venue_type, capacity, city_id) VALUES
('NSCI Dome',               'Worli, Mumbai',                'arena',       10000,  1),  -- 1
('Palace Grounds',          'Jayamahal Rd, Bangalore',      'open-air',    15000,  2),  -- 2
('Siri Fort Auditorium',    'Khel Gaon, Delhi',             'auditorium',   2000,  3),  -- 3
('Netaji Indoor Stadium',   'Kolkata Gate, Kolkata',        'arena',       12000,  4),  -- 4
('Sardar Patel Stadium',    'Navrangpura, Ahmedabad',       'stadium',     25000,  5),  -- 5
('Jawahar Kala Kendra',     'JLN Marg, Jaipur',             'auditorium',   3000,  6),  -- 6
('Ravindralaya Auditorium', 'Hazratganj, Lucknow',          'auditorium',   2500,  7),  -- 7
('Bolgatty Palace Grounds', 'Mulavukad Island, Kochi',      'open-air',     5000,  8),  -- 8
('Tagore Theatre',          'Sector 18, Chandigarh',        'theatre',      1800,  9),  -- 9
('HITEX Exhibition Centre', 'Madhapur, Hyderabad',          'hall',        20000, 10),  -- 10
('Symbiosis Ground',        'Viman Nagar, Pune',            'open-air',     8000, 11);  -- 11


-- events (IDs 1-16)
INSERT INTO Event (title, description, start_datetime, end_datetime, status, venue_id, category_id, organiser_id) VALUES
('Sunburn Festival',            'Biggest EDM festival in India',                  '2025-12-20 18:00', '2025-12-20 23:59', 'upcoming',   1, 1,  2),  -- 1
('Stand-Up Night Mumbai',       'Top comedians live on stage',                    '2025-11-10 20:00', '2025-11-10 22:30', 'upcoming',   1, 3,  2),  -- 2
('TechSummit 2025',             'Annual tech conference Bangalore',               '2025-10-05 09:00', '2025-10-05 18:00', 'completed',  2, 4,  2),  -- 3
('Kolkata Jazz Night',          'Smooth jazz and blues by top artists',           '2025-11-15 19:00', '2025-11-15 22:30', 'completed',  4, 1,  7),  -- 4
('Ahmedabad Marathon 2025',     'City-wide marathon with 5k, 10k and 21k tracks', '2025-12-07 06:00', '2025-12-07 12:00', 'upcoming',  5, 2, 13),  -- 5
('Jaipur Literature Fest',      'Authors, poets and thinkers from across India',  '2026-01-20 10:00', '2026-01-22 18:00', 'upcoming',   6, 5, 21),  -- 6
('Lucknow Comedy Nights',       'Nawabi humour with a modern twist',              '2025-11-28 20:00', '2025-11-28 22:30', 'completed',  7, 3,  7),  -- 7
('Kochi International Film Fest','Screenings and panels on world cinema',         '2025-12-14 10:00', '2025-12-16 22:00', 'upcoming',   8, 5, 13),  -- 8
('Chandigarh Rock Festival',    'Three bands, one epic night of rock',            '2025-12-21 17:00', '2025-12-21 23:30', 'upcoming',   9, 1, 21),  -- 9
('Mumbai Startup Summit',       'Pitches, panels and networking for founders',    '2026-02-10 09:00', '2026-02-10 18:00', 'upcoming',   1, 4,  2),  -- 10
('Bangalore Food & Music Fest', 'Live bands paired with cuisines from 15 states', '2025-12-25 12:00', '2025-12-25 22:00', 'upcoming',   2, 1,  7),  -- 11
('Delhi Comedy Gala',           'New Year special stand-up comedy show',          '2025-12-31 20:30', '2025-12-31 23:30', 'upcoming',   3, 3,  7),  -- 12
('Jaipur Heritage Walk Concert','Classical Rajasthani folk music at Amer Fort',   '2026-01-26 17:00', '2026-01-26 21:00', 'upcoming',   6, 1, 21),  -- 13
('Hyderabad Sports Carnival',   'Amateur sports tournaments across 8 disciplines','2025-11-30 08:00', '2025-11-30 18:00', 'completed', 10, 2, 13),  -- 14
('Kochi Yoga & Wellness Summit','Expert-led yoga sessions and wellness workshops','2026-03-08 07:00', '2026-03-08 13:00', 'upcoming',   8, 5,  2),  -- 15
('Pune Stand-Up Open Mic',      'Fresh voices from the Pune comedy circuit',      '2025-11-20 20:00', '2025-11-20 22:00', 'completed', 11, 3, 13);  -- 16


-- ticket types (IDs 1-31)
INSERT INTO Ticket_Type (type_name, price, total_quantity, available_quantity, event_id) VALUES
('General',          999.00,  5000, 4800,  1),  -- 1
('VIP',             3999.00,   500,  490,  1),  -- 2
('Standard',         299.00,  1000,  950,  2),  -- 3
('Delegate',         499.00,   800,  750,  3),  -- 4
('Workshop',        1499.00,   100,   80,  3),  -- 5
('General',          349.00,  1500, 1100,  4),  -- 6
('Premium',          799.00,   300,  210,  4),  -- 7
('5K Entry',         299.00,  2000, 1650,  5),  -- 8
('10K Entry',        499.00,  1500, 1200,  5),  -- 9
('21K Entry',        799.00,   500,  380,  5),  -- 10
('Day Pass',         599.00,  1000,  820,  6),  -- 11
('Full Festival',    999.00,   500,  390,  6),  -- 12
('Standard',         299.00,   800,  550,  7),  -- 13
('VIP',              699.00,   150,   90,  7),  -- 14
('Single Day',       399.00,   800,  650,  8),  -- 15
('All 3 Days',       899.00,   300,  220,  8),  -- 16
('General',          449.00,  1200, 1000,  9),  -- 17
('Pit Pass',        1299.00,   200,  165,  9),  -- 18
('Delegate',         999.00,   600,  510, 10),  -- 19
('Workshop Add-on',  499.00,   200,  170, 10),  -- 20
('Entry',            199.00,  5000, 4200, 11),  -- 21
('Premium Lounge',   999.00,   300,  240, 11),  -- 22
('Standard',         599.00,   800,  620, 12),  -- 23
('Front Row',       1199.00,   100,   75, 12),  -- 24
('General',          499.00,  1000,  830, 13),  -- 25
('Heritage Box',    1499.00,    80,   55, 13),  -- 26
('Participant',      199.00,  2000, 1400, 14),  -- 27
('Spectator',         99.00,  3000, 2500, 14),  -- 28
('Morning Session',  299.00,   400,  340, 15),  -- 29
('Full Day',         599.00,   200,  165, 15),  -- 30
('Entry',            149.00,   500,  380, 16);  -- 31


-- bookings (IDs 1-22)
-- booking 16 = pending (no payment row)
-- booking 20 = cancelled (no payment row)
INSERT INTO Booking (total_amt, booking_status, user_id, event_id) VALUES
(3998.00, 'confirmed',  1,  1),   -- 1
( 598.00, 'confirmed',  3,  2),   -- 2
( 698.00, 'confirmed', 14,  4),   -- 3
( 799.00, 'confirmed', 15,  4),   -- 4
( 598.00, 'confirmed', 17,  5),   -- 5
( 499.00, 'confirmed', 19,  5),   -- 6
( 999.00, 'confirmed', 20,  6),   -- 7
( 598.00, 'confirmed', 18,  7),   -- 8
( 699.00, 'confirmed', 14,  7),   -- 9
( 399.00, 'confirmed', 22,  8),   -- 10
( 898.00, 'confirmed', 23,  9),   -- 11
( 999.00, 'confirmed', 24, 10),   -- 12
( 398.00, 'confirmed', 11, 11),   -- 13
( 599.00, 'confirmed',  9, 12),   -- 14
(1199.00, 'confirmed', 22, 12),   -- 15
( 499.00, 'pending',    8, 13),   -- 16 (pending)
( 199.00, 'confirmed', 18, 14),   -- 17
( 299.00, 'confirmed', 20, 15),   -- 18
( 447.00, 'confirmed', 16, 16),   -- 19
( 398.00, 'cancelled', 14, 11),   -- 20 (cancelled)
(1299.00, 'confirmed', 15,  9),   -- 21
(1998.00, 'confirmed', 23, 13);   -- 22


-- booking items
INSERT INTO Booking_Item (quantity, price_each, subtotal, booking_id, ticket_type_id) VALUES
(2,  999.00, 1998.00,  1,  1),   -- booking 1:  2x General Sunburn
(1, 3999.00, 3999.00,  1,  2),   -- booking 1:  1x VIP Sunburn
(2,  299.00,  598.00,  2,  3),   -- booking 2:  2x Standard Stand-Up
(2,  349.00,  698.00,  3,  6),   -- booking 3:  2x General Jazz
(1,  799.00,  799.00,  4,  7),   -- booking 4:  1x Premium Jazz
(2,  299.00,  598.00,  5,  8),   -- booking 5:  2x 5K Marathon
(1,  499.00,  499.00,  6,  9),   -- booking 6:  1x 10K Marathon
(1,  999.00,  999.00,  7, 12),   -- booking 7:  1x Full Festival Jaipur
(2,  299.00,  598.00,  8, 13),   -- booking 8:  2x Standard Lucknow Comedy
(1,  699.00,  699.00,  9, 14),   -- booking 9:  1x VIP Lucknow Comedy
(1,  399.00,  399.00, 10, 15),   -- booking 10: 1x Single Day Film Fest
(2,  449.00,  898.00, 11, 17),   -- booking 11: 2x General Rock Fest
(1,  999.00,  999.00, 12, 19),   -- booking 12: 1x Delegate Startup Summit
(2,  199.00,  398.00, 13, 21),   -- booking 13: 2x Entry Bangalore Food Fest
(1,  599.00,  599.00, 14, 23),   -- booking 14: 1x Standard Delhi Comedy
(1, 1199.00, 1199.00, 15, 24),   -- booking 15: 1x Front Row Delhi Comedy
(1,  499.00,  499.00, 16, 25),   -- booking 16: 1x General Jaipur Heritage (pending)
(1,  199.00,  199.00, 17, 27),   -- booking 17: 1x Participant Hyderabad Sports
(1,  299.00,  299.00, 18, 29),   -- booking 18: 1x Morning Session Yoga
(3,  149.00,  447.00, 19, 31),   -- booking 19: 3x Entry Pune Open Mic
(2,  199.00,  398.00, 20, 21),   -- booking 20: 2x Entry Food Fest (cancelled)
(1, 1299.00, 1299.00, 21, 18),   -- booking 21: 1x Pit Pass Rock Fest
(1,  499.00,  499.00, 22, 25),   -- booking 22: 1x General Jaipur Heritage
(1, 1499.00, 1499.00, 22, 26);   -- booking 22: 1x Heritage Box Jaipur


-- payments (no row for booking 16 or booking 20)
INSERT INTO Payment (transaction_ref, payment_method, payment_status, paid_amt, paid_at, booking_id) VALUES
('TXN20251001001', 'upi',         'completed', 3998.00, '2025-10-01 14:32:00',  1),
('TXN20251002001', 'credit_card', 'completed',  598.00, '2025-10-02 11:10:00',  2),
('TXN20251114001', 'upi',         'completed',  698.00, '2025-11-14 20:10:00',  3),
('TXN20251114002', 'credit_card', 'completed',  799.00, '2025-11-14 20:45:00',  4),
('TXN20251129001', 'debit_card',  'completed',  598.00, '2025-11-29 09:15:00',  5),
('TXN20251129002', 'upi',         'completed',  499.00, '2025-11-29 09:55:00',  6),
('TXN20251228001', 'net_banking', 'completed',  999.00, '2025-12-28 11:30:00',  7),
('TXN20251127001', 'wallet',      'completed',  598.00, '2025-11-27 18:20:00',  8),
('TXN20251127002', 'credit_card', 'completed',  699.00, '2025-11-27 18:55:00',  9),
('TXN20251209001', 'upi',         'completed',  399.00, '2025-12-09 14:00:00', 10),
('TXN20251210001', 'debit_card',  'completed',  898.00, '2025-12-10 16:30:00', 11),
('TXN20260115001', 'net_banking', 'completed',  999.00, '2026-01-15 10:00:00', 12),
('TXN20251219001', 'upi',         'completed',  398.00, '2025-12-19 12:45:00', 13),
('TXN20251220001', 'credit_card', 'completed',  599.00, '2025-12-20 09:00:00', 14),
('TXN20251220002', 'wallet',      'completed', 1199.00, '2025-12-20 09:30:00', 15),
('TXN20251129003', 'cash',        'completed',  199.00, '2025-11-29 07:45:00', 17),
('TXN20260220001', 'debit_card',  'completed',  299.00, '2026-02-20 08:00:00', 18),
('TXN20251119001', 'upi',         'completed',  447.00, '2025-11-19 19:00:00', 19),
('TXN20251211001', 'credit_card', 'completed', 1299.00, '2025-12-11 17:20:00', 21),
('TXN20260121001', 'net_banking', 'completed', 1998.00, '2026-01-21 13:15:00', 22);


-- reviews
INSERT INTO Review (rating, comment, user_id, event_id) VALUES
(5, 'Amazing festival, sound quality was top notch.',                    1,  1),
(4, 'Great show but the venue was a bit too crowded.',                   3,  2),
(5, 'Jazz Night was phenomenal. The saxophone set was unforgettable.',  14,  4),
(4, 'Great atmosphere. Parking was a bit of a hassle though.',          15,  4),
(5, 'Lucknow Comedy Night had me in tears. Brilliant lineup.',          18,  7),
(3, 'Decent show but some acts ran way too long.',                      14,  7),
(5, 'Sports Carnival was incredibly well organised.',                   18, 14),
(4, 'Pune Open Mic had some really fresh talent. Will come again.',     16, 16);
GO

-- fix_tickets_sold_view.sql
-- Fixes vw_OrganizerEventStats to calculate tickets_sold from actual
-- Booking_Item records instead of relying on available_quantity diff.
-- Run against the existing TicketBookingSystem database.

USE TicketBookingSystem;
GO

-- Drop and recreate the view
DROP VIEW IF EXISTS vw_OrganizerEventStats;
GO

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

PRINT '=== vw_OrganizerEventStats view fixed ===';
GO

-- add_indian_cities.sql
-- Run this against an existing TicketBookingSystem database
-- to add 64 new cities across India.
-- Uses a safe INSERT that skips cities that already exist.

USE TicketBookingSystem;
GO

-- Insert cities only if they don't already exist (uses NOT EXISTS check)
INSERT INTO City (city_name, state)
SELECT city_name, state FROM (VALUES
    ('Chennai',            'Tamil Nadu'),
    ('Goa',                'Goa'),
    ('Indore',             'Madhya Pradesh'),
    ('Bhopal',             'Madhya Pradesh'),
    ('Patna',              'Bihar'),
    ('Bhubaneswar',        'Odisha'),
    ('Guwahati',           'Assam'),
    ('Dehradun',           'Uttarakhand'),
    ('Shimla',             'Himachal Pradesh'),
    ('Ranchi',             'Jharkhand'),
    ('Raipur',             'Chhattisgarh'),
    ('Thiruvananthapuram', 'Kerala'),
    ('Coimbatore',         'Tamil Nadu'),
    ('Madurai',            'Tamil Nadu'),
    ('Mysore',             'Karnataka'),
    ('Mangalore',          'Karnataka'),
    ('Visakhapatnam',      'Andhra Pradesh'),
    ('Vijayawada',         'Andhra Pradesh'),
    ('Nagpur',             'Maharashtra'),
    ('Nashik',             'Maharashtra'),
    ('Aurangabad',         'Maharashtra'),
    ('Surat',              'Gujarat'),
    ('Vadodara',           'Gujarat'),
    ('Rajkot',             'Gujarat'),
    ('Varanasi',           'Uttar Pradesh'),
    ('Agra',               'Uttar Pradesh'),
    ('Kanpur',             'Uttar Pradesh'),
    ('Noida',              'Uttar Pradesh'),
    ('Ghaziabad',          'Uttar Pradesh'),
    ('Prayagraj',          'Uttar Pradesh'),
    ('Gurugram',           'Haryana'),
    ('Faridabad',          'Haryana'),
    ('Amritsar',           'Punjab'),
    ('Ludhiana',           'Punjab'),
    ('Jalandhar',          'Punjab'),
    ('Udaipur',            'Rajasthan'),
    ('Jodhpur',            'Rajasthan'),
    ('Kota',               'Rajasthan'),
    ('Jammu',              'Jammu & Kashmir'),
    ('Srinagar',           'Jammu & Kashmir'),
    ('Gangtok',            'Sikkim'),
    ('Shillong',           'Meghalaya'),
    ('Imphal',             'Manipur'),
    ('Agartala',           'Tripura'),
    ('Aizawl',             'Mizoram'),
    ('Kohima',             'Nagaland'),
    ('Itanagar',           'Arunachal Pradesh'),
    ('Dibrugarh',          'Assam'),
    ('Silchar',            'Assam'),
    ('Panaji',             'Goa'),
    ('Navi Mumbai',        'Maharashtra'),
    ('Thane',              'Maharashtra'),
    ('Kolhapur',           'Maharashtra'),
    ('Pondicherry',        'Puducherry'),
    ('Port Blair',         'Andaman & Nicobar'),
    ('Daman',              'Dadra & Nagar Haveli and Daman & Diu'),
    ('Haridwar',           'Uttarakhand'),
    ('Rishikesh',          'Uttarakhand'),
    ('Dharamshala',        'Himachal Pradesh'),
    ('Manali',             'Himachal Pradesh'),
    ('Tirupati',           'Andhra Pradesh'),
    ('Warangal',           'Telangana'),
    ('Hubli',              'Karnataka'),
    ('Belgaum',            'Karnataka')
) AS NewCities(city_name, state)
WHERE NOT EXISTS (
    SELECT 1 FROM City c
    WHERE c.city_name = NewCities.city_name
      AND c.state     = NewCities.state
);

PRINT '=== Indian cities migration completed ===';
GO



select * from users where ;
select * from Booking;

-- schema_migration.sql
-- run this AFTER ticket_booking.sql, views.sql, stored_procedures.sql, triggers.sql
-- adds columns and views needed for organizer dashboard + admin analytics
-- NOTE: commission rate is configured in backend/config.py (no extra tables needed)

USE TicketBookingSystem;
GO


-- ═══════════════════════════════════════════════════════════════
-- 1. Add is_active column to Users for soft delete
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE Users
ADD is_active BIT NOT NULL DEFAULT 1;
GO


-- ═══════════════════════════════════════════════════════════════
-- 2. Add image_url to Event (optional poster)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE Event
ADD image_url NVARCHAR(500) NULL;
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
