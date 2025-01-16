--A.
--a) - průměrný počet záznamků v tabulce
SELECT AVG(table_row_count) AS avg_records_per_table
FROM (
    SELECT relname AS table_name, n_live_tup AS table_row_count
    FROM pg_stat_user_tables
) subquery;


SELECT AVG(row_count) AS avg_count
FROM (
    SELECT count(*) AS row_count
    FROM airports
    UNION ALL
    SELECT count(*) FROM airlines
    UNION ALL
    SELECT count(*) FROM planes
    UNION ALL
    SELECT count(*) FROM flights
    UNION ALL
    SELECT count(*) FROM passengers
    UNION ALL
    SELECT count(*) FROM tickets
    UNION ALL
    SELECT count(*) FROM baggage
    UNION ALL
    SELECT count(*) FROM discounts
    UNION ALL
    SELECT count(*) FROM audit_log
) AS table_counts;

--b)  - letiště ze kterého se nejvíce odlétá
SELECT name, city
FROM airports
WHERE id = (
  SELECT departure_airport
  FROM flights
  GROUP BY departure_airport
  ORDER BY COUNT(departure_airport) DESC
  LIMIT 1
);
--c)  - Airolinky a jejich počet letů
SELECT a.name, COUNT(*) AS total_flights
FROM flights f
INNER JOIN airlines a ON f.airline_id = a.id
GROUP BY a.name
HAVING COUNT(*) > 5
order by total_flights; 
--d)  - spojené lety (self--join)
--Tato view vrátí dvojice letů, které jsou spojeny tak, že
--příletový letiště prvního letu je odletovým letištěm druhého letu.
SELECT - self join 
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
--E.  - view flight_summary
--Tento view slouží k zobrazení informací o jednotlivých letech.
--Vrací číslo letu, názvy letišt, odletu a příletu a název aerolinky.
CREATE or replace VIEW flight_summary AS
SELECT f.flight_number, 
       a1.name AS departure_airport, 
       a2.name AS arrival_airport, 
       al.name AS airline
FROM flights f
JOIN airports a1 ON f.departure_airport = a1.id
JOIN airports a2 ON f.arrival_airport = a2.id
JOIN airlines al ON f.airline_id = al.id;

SELECT * FROM public.flight_summary;
--F.
--Funkce occupied_capacity( )
--Tato funkce vrací, kolik míst na daném letu je již obsazeno.
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
--G.  - procedura generate_discounts()
--Tato procedura do tabulky discounts vloží náhodné slevy pro jednotlivé letouny.
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
            RAISE NOTICE 'Failed insert discount -plane_id: %', rec.id;
      END;
   END LOOP;

   CLOSE cur;

   RAISE NOTICE 'Discount generation comp)leted successfully.';
END;
$$;

call generate_discounts();
select * from discounts;
--H.  - trigger airports_audit_trigger
--Tento trigger sleduje operace s tabulkou airports a zaznamenává je do tabulky audit_log.
--Pro každou operaci (INSERT, UPDATE, DELETE) se do tabulky audit_log vloží záznam obsahující:
--  - název tabulky (table_name)
--  - typ operace (operation)
--  - jméno uživatele, který operaci provedl (user_name)
--  - data o starém a novém stavu záznamu (old_values, new_values)
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

CREATE or replace TRIGGER airports_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON airports
FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
INSERT INTO airports (id, name, city, country) VALUES (26, 'Heathrow', 'London', 'UK');
--I.
CREATE OR REPLACE PROCEDURE check_and_reserve_seat_proc(
    flight_id_param INT, 
    passenger_id_param INT, 
    seat_number_param VARCHAR,
    price_param DECIMAL
)
LANGUAGE plpgsql AS $$
DECLARE
   occupied_seats INT;
   plane_capacity INT;
   seat_reserved BOOLEAN;
   next_id INT;
BEGIN
   SELECT COUNT(*) INTO occupied_seats
   FROM tickets
   WHERE flight_id = flight_id_param;

   SELECT p.capacity INTO plane_capacity
   FROM planes p
   JOIN flights f ON f.plane_id = p.id
   WHERE f.id = flight_id_param;

   SELECT EXISTS(
      SELECT 1
      FROM tickets
      WHERE flight_id = flight_id_param AND seat_number = seat_number_param
   ) INTO seat_reserved;

   IF occupied_seats >= plane_capacity THEN
      RAISE EXCEPTION 'The plane is full. Cannot reserve a seat for this flight.';
   ELSIF seat_reserved THEN
      RAISE EXCEPTION 'Seat % is already reserved on flight %.', seat_number_param, flight_id_param;
   END IF;

   SELECT COALESCE(MAX(id), 0) + 1 INTO next_id FROM tickets;

   INSERT INTO tickets (id, flight_id, passenger_id, seat_number, price)
   VALUES (next_id, flight_id_param, passenger_id_param, seat_number_param, price_param);


   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      RAISE NOTICE 'Error: %', SQLERRM;
      ROLLBACK;
END;
$$;

CREATE OR REPLACE PROCEDURE check_and_reserve_seat_proc(
    flight_id_param INT, 
    passenger_id_param INT, 
    seat_number_param VARCHAR,
    price_param DECIMAL
)
LANGUAGE plpgsql AS $$
DECLARE
   occupied_seats INT;
   plane_capacity INT;
   seat_reserved BOOLEAN;
   new_ticket_id INT;
BEGIN
   -- Kontrola plnosti
   SELECT COUNT(*) INTO occupied_seats
   FROM tickets
   WHERE flight_id = flight_id_param;

   -- kap letadla
   SELECT p.capacity INTO plane_capacity
   FROM planes p
   JOIN flights f ON f.plane_id = p.id
   WHERE f.id = flight_id_param;

   -- kontrola sedadla
   SELECT EXISTS(
      SELECT 1
      FROM tickets
      WHERE flight_id = flight_id_param AND seat_number = seat_number_param
   ) INTO seat_reserved;

   -- v pripade nesplneni podminek chyba
   IF occupied_seats >= plane_capacity THEN
      RAISE EXCEPTION 'The plane is full. Cannot reserve a seat for this flight.';
   ELSIF seat_reserved THEN
      RAISE EXCEPTION 'Seat % is already reserved on flight %.', seat_number_param, flight_id_param;
   END IF;

   -- kvuli me blbosti manualni id
   SELECT COALESCE(MAX(id), 0) + 1 INTO new_ticket_id FROM tickets;

   -- pridat ticket
   INSERT INTO tickets (id, flight_id, passenger_id, seat_number, price)
   VALUES (new_ticket_id, flight_id_param, passenger_id_param, seat_number_param, price_param);

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE NOTICE 'Error: %', SQLERRM;
END;
$$;

call check_and_reserve_seat_proc(1, 123, '12A');
--Z. index
CREATE INDEX IF NOT EXISTS idx_email2
ON passengers(emails);

EXPLAIN ANALYZE SELECT * FROM passengers WHERE email = 'msmichaelsantos@example.org';
EXPLAIN SELECT * FROM passengers WHERE email = 'msmichaelsantos@example.org';
insert into passengers values(5001,'David','Hall', 'msmichaelsantos@example.org')
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
-- Exkluzivní lock na celou tabulku
LOCK TABLE passengers IN EXCLUSIVE MODE;

-- Sdílený lock na celou tabulku
LOCK TABLE passengers IN SHARE MODE;

-- Access exclusive lock - pouze cteni dokud lock neni odstranen
LOCK TABLE passengers IN ACCESS EXCLUSIVE MODE;
BEGIN;
LOCK TABLE passengers IN ROW EXCLUSIVE MODE;
SELECT * FROM passengers WHERE id = 1;
COMMIT;

-- Row share lock on a specific row
BEGIN;
LOCK TABLE passengers IN ROW SHARE MODE;
SELECT * FROM passengers WHERE id = 1;
COMMIT;
-------
ALTER ROLE read_only_role WITH SUPERUSER;