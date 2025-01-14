--A.
--a) - průměrný počet záznamků v tabulce
SELECT AVG(table_row_count) AS avg_records_per_table
FROM (
    SELECT relname AS table_name, n_live_tup AS table_row_count
    FROM pg_stat_user_tables
) subquery;

--b)
SELECT name, city
FROM airports
WHERE id = (
  SELECT departure_airport
  FROM flights
  GROUP BY departure_airport
  ORDER BY COUNT(departure_airport) DESC
  LIMIT 1
);
--c)
SELECT a.name, COUNT(*) AS total_flights
FROM flights f
INNER JOIN airlines a ON f.airline_id = a.id
GROUP BY a.name
HAVING COUNT(*) > 5
order by total_flights;
--d)
SELECT 
    f1.id AS flight_id,
    f1.flight_number AS parent_flight,
    f2.id AS connected_flight_id,
    f2.flight_number AS connected_flight
FROM 
    flights f1
INNER JOIN 
    flights f2 
ON 
    f1.arrival_airport = f2.departure_airport
WHERE 
    f1.id <> f2.id;
--E.
CREATE VIEW flight_summary AS
SELECT f.flight_number, 
       a1.name AS departure_airport, 
       a2.name AS arrival_airport, 
       al.name AS airline
FROM flights f
JOIN airports a1 ON f.departure_airport = a1.id
JOIN airports a2 ON f.arrival_airport = a2.id
JOIN airlines al ON f.airline_id = al.id;
--F.
CREATE OR REPLACE FUNCTION occupied_capacity(flight_id_param INT)
RETURNS INT AS $$
DECLARE
   occupied_seats INT;
BEGIN
   SELECT COUNT(*) INTO occupied_seats
   FROM tickets
   WHERE flight_id = flight_id_param;

   RETURN occupied_seats;
END;
$$ LANGUAGE plpgsql;

SELECT occupied_capacity(5);
--G.
CREATE OR REPLACE PROCEDURE generate_discounts()
LANGUAGE plpgsql AS $$
DECLARE
   cur CURSOR FOR SELECT id FROM planes;
   rec RECORD;

BEGIN
   OPEN cur;

   LOOP
      FETCH cur INTO rec;

      EXIT WHEN NOT FOUND;

      BEGIN
         INSERT INTO discounts (plane_id, discount)
         VALUES (rec.id, TRUNC(RANDOM() * 20 + 1));

      EXCEPTION
         WHEN OTHERS THEN
            RAISE NOTICE 'Failed to insert discount for plane_id: %', rec.id;
      END;
   END LOOP;

   CLOSE cur;

   RAISE NOTICE 'Discount generation completed successfully.';
END;
$$;

call generate_discounts();
--H.
CREATE OR REPLACE FUNCTION audit_trigger_function() 
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (table_name, operation, user_name, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(NEW));
        RETURN NEW;
    
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD));
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER airports_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON airports
FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

--I.
CREATE OR REPLACE FUNCTION check_and_reserve_seat(flight_id_param INT, passenger_id_param INT, seat_number_param VARCHAR)
RETURNS VOID AS $$
DECLARE
   occupied_seats INT;
   plane_capacity INT;
BEGIN
   BEGIN
      SELECT COUNT(*) INTO occupied_seats
      FROM tickets
      WHERE flight_id = flight_id_param;

      SELECT p.capacity INTO plane_capacity
      FROM planes p
      JOIN flights f ON f.plane_id = p.id
      WHERE f.id = flight_id_param;

      IF occupied_seats >= plane_capacity THEN
         RAISE EXCEPTION 'The plane is full. Cannot reserve a seat for this flight.';
      END IF;

      INSERT INTO tickets (flight_id, passenger_id, seat_number, price)
      VALUES (flight_id_param, passenger_id_param, seat_number_param, 100.00);

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK; -->nefunguje
         RAISE; 
   END;
END;
$$ LANGUAGE plpgsql;

SELECT check_and_reserve_seat(1, 123, '12A');

--J.
CREATE USER username WITH PASSWORD 'password';
DROP USER username;
CREATE ROLE role_name;
DROP ROLE role_name;
GRANT privilege_type ON object TO user_or_role;
----
GRANT CONNECT ON DATABASE airlines TO john_doe;
GRANT SELECT, INSERT ON TABLE airlines TO admin_role;
------
REVOKE SELECT ON TABLE my_table FROM john_doe;
REVOKE ALL PRIVILEGES ON DATABASE my_database FROM admin_role;
------
GRANT admin_role TO john_doe;
-------
REVOKE admin_role FROM john_doe;
--------
GRANT CREATEDB TO john_doe;
--k.
LOCK TABLE airports IN EXCLUSIVE MODE;