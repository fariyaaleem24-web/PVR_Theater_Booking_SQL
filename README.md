# PVR Theater Booking SQL

MySQL stored procedures for a theater ticket booking system. This project covers table design, sample data, a booking procedure with transaction handling, and a cancellation procedure.

## Tables
- **Theater**: theaters, ticket types, rate, maximum capacity and balance capacity
- **Bookings**: each ticket sale, linked to a theater by `TheaterID`

## Stored procedures
- **`sp_BookTicket`**: checks that enough seats are available, calculates the amount, saves the booking and reduces the balance capacity. It uses a transaction, an exit handler with `ROLLBACK`, and `SIGNAL SQLSTATE '45000'` to raise an error when capacity is insufficient.
- **`sp_CancelBooking`**: finds a booking, restores the seats to the theater, removes the booking record and returns a message. It reports an error if the booking ID does not exist.

## How to run
1. Open MySQL Workbench and connect to your local server.
2. Open `pvr_theater_FA.sql`.
3. Run the whole script with Ctrl+Shift+Enter. It creates the database `pvr_theater`, the tables, the sample data and both procedures, then runs the tests.

## Test cases
- A valid booking returns `SUCCESS! Booking confirmed...` with the total amount.
- Requesting more seats than available returns `INSUFFICIENT CAPACITY. Requested: 999 | Available: 60`, and nothing is saved.
- Cancelling an existing booking restores its seats; cancelling a missing booking returns `CANCELLATION FAILED`.

## Technologies
MySQL, MySQL Workbench

## Sample output
Screenshots of the test results will be added here.
