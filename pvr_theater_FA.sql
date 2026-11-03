-- =====================================================================
-- PVR Theater Ticket Booking System  |  MySQL Stored Procedures Project
-- Student : <YOUR NAME>
-- File    : PVR_theater_<INITIALS>.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- SECTION 1-4 : TABLE + DATA SETUP (code provided by faculty)
-- (DROP lines added only so the script can be re-run safely)
-- ---------------------------------------------------------------------
create database pvr_theater;
use pvr_theater;

DROP PROCEDURE IF EXISTS sp_BookTicket;
DROP PROCEDURE IF EXISTS sp_CancelBooking;
DROP TABLE IF EXISTS Bookings;
DROP TABLE IF EXISTS Theater;


-- 3.1 Theater Table
CREATE TABLE Theater (
    TheaterID     INT            PRIMARY KEY,
    Name          VARCHAR(100)   NOT NULL,
    TicketType    VARCHAR(20)    NOT NULL,
    Rate          DECIMAL(8,2)   NOT NULL,
    MaxCapacity   INT            NOT NULL,
    BalCapacity   INT            NOT NULL
);

-- 3.2 Bookings Table
CREATE TABLE Bookings (
    BookingID    INT             AUTO_INCREMENT PRIMARY KEY,
    TheaterID    INT             NOT NULL,
    TrxDate      DATETIME        DEFAULT NOW(),
    TicketType   VARCHAR(20)     NOT NULL,
    Qty          INT             NOT NULL,
    Rate         DECIMAL(8,2)    NOT NULL,
    Amount       DECIMAL(10,2)   NOT NULL,
    FOREIGN KEY (TheaterID) REFERENCES Theater(TheaterID)
);

-- Exercise 1: verify table structures
DESCRIBE Theater;
DESCRIBE Bookings;

-- 4. Sample data
INSERT INTO Theater (TheaterID, Name, TicketType, Rate, MaxCapacity, BalCapacity)
VALUES
    (1, 'Grand Cinemas',   'Gold',     350.00, 100, 100),
    (2, 'Grand Cinemas',   'Silver',   200.00, 150, 150),
    (3, 'Starlight Plex',  'Platinum', 500.00,  60,  60),
    (4, 'Starlight Plex',  'Gold',     350.00,  80,  80),
    (5, 'Metro Movies',    'Silver',   180.00, 200, 200),
    (6, 'Metro Movies',    'Gold',     300.00, 120, 120);

-- Exercise 2: verify data
SELECT * FROM Theater;


-- ---------------------------------------------------------------------
-- SECTION 5 : STORED PROCEDURE  sp_BookTicket  (+ Exercise 2A)
-- ---------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_BookTicket (
    IN  p_TheaterID   INT,
    IN  p_TicketType  VARCHAR(20),
    IN  p_Qty         INT,
    OUT p_Message     VARCHAR(255)
)
BEGIN
    -- Step 1: Declare local variables
    DECLARE v_BalCap  INT;
    DECLARE v_Rate    DECIMAL(8,2);
    DECLARE v_Amount  DECIMAL(10,2);
    DECLARE v_ErrMsg  VARCHAR(255);

    -- Step 1a: EXIT ZONE (exception handler)
    -- If anything goes wrong (including our own SIGNAL 45000):
    --   undo everything, capture the error text and hand it back in p_Message
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrMsg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_Message = v_ErrMsg;
    END;

    START TRANSACTION;

    -- Step 2: Fetch rate and balance capacity from Theater
    SELECT BalCapacity, Rate
      INTO v_BalCap, v_Rate
      FROM Theater
     WHERE TheaterID  = p_TheaterID
       AND TicketType = p_TicketType;
							-- locks the row so two people can't book the same seats

    -- Extra safety: no matching theater / ticket type
   IF p_Qty > v_BalCap THEN
        SET v_ErrMsg = CONCAT('INSUFFICIENT CAPACITY. Requested: ', p_Qty,
                              ' | Available: ', v_BalCap);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_ErrMsg;
    ELSE
        -- Step 4: Calculate amount
        SET v_Amount = p_Qty * v_Rate;

        -- Step 5: Insert booking record
        INSERT INTO Bookings
            (TheaterID, TrxDate, TicketType, Qty, Rate, Amount)
        VALUES
            (p_TheaterID, NOW(), p_TicketType, p_Qty, v_Rate, v_Amount);

        -- Step 6: Reduce balance capacity
        UPDATE Theater
           SET BalCapacity = BalCapacity - p_Qty
         WHERE TheaterID  = p_TheaterID
           AND TicketType = p_TicketType;

        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'BOOKING FAILED. Capacity not updated.';
        END IF;

        -- Step 7: Return success message
        SET p_Message = CONCAT(
            'SUCCESS! Booking confirmed. ',
            p_Qty, ' ticket(s) x Rs.', v_Rate, ' = Rs.', v_Amount);

        COMMIT;
    END IF;
END //

DELIMITER ;

-- ---------------------------------------------------------------------
-- SECTION 6 : TESTING  (Exercises 3 and 4)
-- ---------------------------------------------------------------------

-- 6.1 Successful booking #1  (expected: 5 ticket(s) x Rs.350.00 = Rs.1750.00)
CALL sp_BookTicket(1, 'Gold', 5, @msg);
SELECT @msg AS Result;

-- Exercise 3: two more successful bookings
CALL sp_BookTicket(2, 'Silver', 10, @msg);   SELECT @msg AS Result;
CALL sp_BookTicket(6, 'Gold', 4, @msg);      SELECT @msg AS Result;


-- 6.2 Insufficient capacity (expected: INSUFFICIENT CAPACITY. Requested: 999 | Available: 60)
CALL sp_BookTicket(3, 'Platinum', 999, @msg);
SELECT @msg AS Result;

-- 6.3 Verify results
SELECT * FROM Bookings;

SELECT TheaterID, Name, TicketType,
       MaxCapacity, BalCapacity,
       (MaxCapacity - BalCapacity) AS TicketsSold
FROM   Theater;


-- ---------------------------------------------------------------------
-- SECTION 7 : EXERCISE 5 (Extension)  sp_CancelBooking
-- Reverses a booking: restores BalCapacity and removes the booking row
-- ---------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_CancelBooking (
    IN  p_BookingID  INT,
    OUT p_Message    VARCHAR(255)   
)
BEGIN
    DECLARE v_TheaterID  INT           DEFAULT NULL;
    DECLARE v_TicketType VARCHAR(20);
    DECLARE v_Qty        INT;
    DECLARE v_Amount     DECIMAL(10,2);
    DECLARE v_ErrMsg     VARCHAR(255);

    -- EXIT ZONE
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_ErrMsg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_Message = v_ErrMsg;
    END;

    START TRANSACTION;

    -- Find the booking
    SELECT TheaterID, TicketType, Qty, Amount
      INTO v_TheaterID, v_TicketType, v_Qty, v_Amount
      FROM Bookings
     WHERE BookingID = p_BookingID
       FOR UPDATE;

    IF v_TheaterID IS NULL THEN
        ROLLBACK;
        SET v_ErrMsg = CONCAT('CANCELLATION FAILED. Booking ID ', p_BookingID, ' not found.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_ErrMsg;
    ELSE
        -- Give the seats back
        UPDATE Theater
           SET BalCapacity = BalCapacity + v_Qty
         WHERE TheaterID  = v_TheaterID
           AND TicketType = v_TicketType;

        -- Remove the booking record
        DELETE FROM Bookings
         WHERE BookingID = p_BookingID;

        SET p_Message = CONCAT('SUCCESS! Booking ', p_BookingID, ' cancelled. ',
                               v_Qty, ' seat(s) restored. Refund = Rs.', v_Amount);

        COMMIT;
    END IF;
END //

DELIMITER ;

-- Test cancellation: cancel booking 1, then try a booking that doesn't exist
CALL sp_CancelBooking(1, @msg);
SELECT @msg AS Result;

CALL sp_CancelBooking(999, @msg);
SELECT @msg AS Result;

-- Verify capacity was restored
SELECT * FROM Bookings;
SELECT TheaterID, Name, TicketType, MaxCapacity, BalCapacity,
       (MaxCapacity - BalCapacity) AS TicketsSold
FROM   Theater;
