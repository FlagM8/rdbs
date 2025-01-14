CREATE TABLE airports (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL
);

CREATE TABLE airlines (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE planes (
    id SERIAL PRIMARY KEY,
    model VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    capacity INT NOT NULL,
    range_km INT NOT NULL
);

CREATE TABLE flights (
    plane_id INT REFERENCES planes(id),
    id SERIAL PRIMARY KEY,
    flight_number VARCHAR(20) NOT NULL,
    airline_id INT REFERENCES airlines(id),
    departure_airport INT REFERENCES airports(id),
    arrival_airport INT REFERENCES airports(id),
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP
);


CREATE TABLE passengers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    flight_id INT REFERENCES flights(id),
    passenger_id INT REFERENCES passengers(id),
    seat_number VARCHAR(10) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

CREATE TABLE baggage (
    id SERIAL PRIMARY KEY,
    ticket_id INT REFERENCES tickets(id),
    weight NUMERIC(5, 2) NOT NULL
);

CREATE TABLE discounts (
    id SERIAL PRIMARY KEY,
    plane_id INT REFERENCES planes(id),
    discount NUMERIC(5, 2) NOT NULL
);

CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    operation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_name VARCHAR(100),
    old_values JSONB,
    new_values JSONB
);

COPY airports(id, name, city, country)
FROM '/tables/airports.csv'
DELIMITER ','
CSV HEADER;

COPY airlines(id, name)
FROM '/tables/airlines.csv'
DELIMITER ','
CSV HEADER;

COPY planes(id, model, manufacturer, capacity, range_km)
FROM '/tables/planes.csv'
DELIMITER ','
CSV HEADER;

COPY flights(plane_id, id, flight_number, airline_id, departure_airport, arrival_airport, departure_time, arrival_time)
FROM '/tables/flights.csv'
DELIMITER ','
CSV HEADER;

COPY passengers(id, first_name, last_name, email)
FROM '/tables/passengers.csv'
DELIMITER ','
CSV HEADER;

COPY tickets(id, flight_id, passenger_id, seat_number, price)
FROM '/tables/tickets.csv'
DELIMITER ','
CSV HEADER;

COPY baggage(id, ticket_id, weight)
FROM '/tables/baggage.csv'
DELIMITER ','
CSV HEADER;