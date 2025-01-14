import csv
import random
from datetime import datetime, timedelta
from faker import Faker

# Initialize Faker
fake = Faker()

# File names
FILES = {
    "airports": "airports.csv",
    "airlines": "airlines.csv",
    "planes": "planes.csv",
    "flights": "flights.csv",
    "passengers": "passengers.csv",
    "tickets": "tickets.csv",
    "baggage": "baggage.csv",
}

# Number of entries per table
NUM_AIRPORTS = 25
NUM_AIRLINES = 10
NUM_PLANES = 30
NUM_FLIGHTS = 1000
NUM_PASSENGERS = 5000
NUM_TICKETS = NUM_FLIGHTS * 150  # 150 passengers per flight on average
NUM_BAGGAGE = int(NUM_TICKETS * 0.7)  # 70% of tickets have baggage

# Helper functions
def generate_airports():
    return [[i, fake.city(), fake.city(), fake.country()] for i in range(1, NUM_AIRPORTS + 1)]

def generate_airlines():
    return [[i, fake.company()] for i in range(1, NUM_AIRLINES + 1)]

def generate_planes():
    return [
        [
            i,
            f"Model-{i}",
            fake.company(),
            random.randint(100, 300),  # Capacity
            random.randint(2000, 15000),  # Range in km
        ]
        for i in range(1, NUM_PLANES + 1)
    ]

def generate_flights(airports, airlines, planes):
    flights = []
    for i in range(1, NUM_FLIGHTS + 1):
        departure_airport, arrival_airport = random.sample(airports, 2)
        departure_time = fake.date_time_this_year()
        arrival_time = departure_time + timedelta(hours=random.randint(1, 12))
        flights.append([
            random.choice(planes)[0],
            i,
            f"FL-{i:04}",
            random.choice(airlines)[0],
            departure_airport[0],
            arrival_airport[0],
            departure_time,
            arrival_time,
        ])
    return flights

def generate_passengers():
    return [
        [
            i,
            fake.first_name(),
            fake.last_name(),
            fake.email()
        ]
        for i in range(1, NUM_PASSENGERS + 1)
    ]

def generate_tickets(flights, passengers):
    tickets = []
    passenger_pool = passengers[:]
    for flight in flights:
        random.shuffle(passenger_pool)
        for j in range(1, random.randint(120, 180)):  # 120-180 passengers per flight
            if not passenger_pool:
                passenger_pool = passengers[:]
            passenger = passenger_pool.pop()
            tickets.append([
                len(tickets) + 1,
                flight[1],  # flight_id
                passenger[0],  # passenger_id
                f"{random.randint(1, 30)}{chr(65 + random.randint(0, 5))}",  # seat number
                round(random.uniform(50, 500), 2),  # price
            ])
    return tickets

def generate_baggage(tickets):
    baggage = []
    for ticket in random.sample(tickets, NUM_BAGGAGE):
        baggage.append([
            len(baggage) + 1,
            ticket[0],  # ticket_id
            round(random.uniform(5, 30), 2),  # weight
        ])
    return baggage

# Write to CSV files
def write_csv(filename, data, headers):
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(data)

# Generate data
airports = generate_airports()
airlines = generate_airlines()
planes = generate_planes()
flights = generate_flights(airports, airlines, planes)
passengers = generate_passengers()
tickets = generate_tickets(flights, passengers)
baggage = generate_baggage(tickets)

# Write data to CSVs
write_csv(FILES["airports"], airports, ["id", "name", "city", "country"])
write_csv(FILES["airlines"], airlines, ["id", "name"])
write_csv(FILES["planes"], planes, ["id", "model", "manufacturer", "capacity", "range_km"])
write_csv(FILES["flights"], flights, ["plane_id", "id", "flight_number", "airline_id", "departure_airport", "arrival_airport", "departure_time", "arrival_time"])
write_csv(FILES["passengers"], passengers, ["id", "first_name", "last_name", "email"])
write_csv(FILES["tickets"], tickets, ["id", "flight_id", "passenger_id", "seat_number", "price"])
write_csv(FILES["baggage"], baggage, ["id", "ticket_id", "weight"])

print("CSV files generated successfully!")
