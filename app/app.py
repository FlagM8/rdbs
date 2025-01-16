from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
import random
app = Flask(__name__)

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@postgres_db:5432/airlines'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Models
class Passenger(db.Model):
    __tablename__ = 'passengers'
    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(50), nullable=False)
    last_name = db.Column(db.String(50), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)

class Flight(db.Model):
    __tablename__ = 'flights'
    id = db.Column(db.Integer, primary_key=True)
    flight_number = db.Column(db.String(20), nullable=False)
    plane_id = db.Column(db.Integer, db.ForeignKey('planes.id'))
    airline_id = db.Column(db.Integer, db.ForeignKey('airlines.id'))
    departure_airport = db.Column(db.Integer, db.ForeignKey('airports.id'))
    arrival_airport = db.Column(db.Integer, db.ForeignKey('airports.id'))
    departure_time = db.Column(db.DateTime)
    arrival_time = db.Column(db.DateTime)

class Airline(db.Model):
    __tablename__ = 'airlines'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)

class Airport(db.Model):
    __tablename__ = 'airports'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    city = db.Column(db.String(100), nullable=False)
    country = db.Column(db.String(100), nullable=False)

class Ticket(db.Model):
    __tablename__ = 'tickets'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    flight_id = db.Column(db.Integer, db.ForeignKey('flights.id'))
    passenger_id = db.Column(db.Integer, db.ForeignKey('passengers.id'))
    seat_number = db.Column(db.String(10), nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)

class Baggage(db.Model):
    __tablename__ = 'baggage'
    id = db.Column(db.Integer, primary_key=True)
    ticket_id = db.Column(db.Integer, db.ForeignKey('tickets.id'))
    weight = db.Column(db.Numeric(5, 2), nullable=False)

class Plane(db.Model):
    __tablename__ = 'planes'
    id = db.Column(db.Integer, primary_key=True)
    model = db.Column(db.String(100), nullable=False)
    manufacturer = db.Column(db.String(100), nullable=False)
    capacity = db.Column(db.Integer, nullable=False)

# Routes
@app.route('/')
def login():
    passengers = Passenger.query.all()
    return render_template('login.html', passengers=passengers)

@app.route('/select_user', methods=['POST'])
def select_user():
    user_id = request.form['user_id']
    return redirect(url_for('user_home', user_id=user_id))

@app.route('/user/<int:user_id>')
def user_home(user_id):
    user = db.session.get(Passenger, user_id)
    print(user)
    dep_airport = db.session.query(
        Airport.id.label('dep_airport_id'),
        Airport.name.label('departure_airport'),
        Airport.city.label('departure_city')
    ).subquery('dep_airport')
    
    arr_airport = db.session.query(
        Airport.id.label('arr_airport_id'),
        Airport.name.label('arrival_airport'),
        Airport.city.label('arrival_city')
    ).subquery('arr_airport')

    tickets = db.session.query(
        Ticket.id.label('ticket_id'),
        Ticket.seat_number,
        Ticket.price,
        Flight.flight_number,
        Plane.model.label('plane_name'),
        Airline.name.label('airline_name'),
        dep_airport.c.departure_airport,
        dep_airport.c.departure_city,
        arr_airport.c.arrival_airport,
        arr_airport.c.arrival_city
    ).join(Flight, Ticket.flight_id == Flight.id) \
     .join(Airline, Flight.airline_id == Airline.id) \
     .join(dep_airport, Flight.departure_airport == dep_airport.c.dep_airport_id) \
     .join(arr_airport, Flight.arrival_airport == arr_airport.c.arr_airport_id) \
     .join(Plane, Flight.plane_id == Plane.id) \
     .filter(Ticket.passenger_id == user_id).all()

    return render_template('user_home.html', user=user, tickets=tickets)

"""@app.route('/user/<int:user_id>')
def user_home(user_id):
    user = db.session.get(Passenger, user_id)
    tickets = db.Session.filter_by(Ticket, passenger_id=user_id).all()
    print("User:", user)
    print("Tickets:", tickets)
    return render_template('user_home.html', user=user, tickets=tickets)
"""
"""@app.route('/find_flights/<int:user_id>', methods=['GET', 'POST'])
def find_flights(user_id):
    if request.method == 'POST':
        flight_id = request.form['flight_id']
        seat_number = request.form['seat_number']
        price = request.form['price']
        new_ticket = Ticket(flight_id=flight_id, passenger_id=user_id, seat_number=seat_number, price=price)
        db.session.add(new_ticket)
        db.session.commit()
        return redirect(url_for('user_home', user_id=user_id))s

    flights = Flight.query.all()
    return render_template('find_flights.html', user_id=user_id, flights=flights)"""

@app.route('/logout')
def logout():
    return redirect(url_for('login'))


@app.route('/find_flights/<int:user_id>', methods=['GET', 'POST'])
def find_flights(user_id):
    if request.method == 'POST':
        flight_number = request.form.get('flight_number')
        departure_city = request.form.get('departure_city')
        arrival_city = request.form.get('arrival_city')

        dep_airport = db.session.query(
            Airport.id.label('dep_airport_id'),
            Airport.name.label('departure_airport'),
            Airport.city.label('departure_city')
        ).subquery('dep_airport')
        
        arr_airport = db.session.query(
            Airport.id.label('arr_airport_id'),
            Airport.name.label('arrival_airport'),
            Airport.city.label('arrival_city')
        ).subquery('arr_airport')

        price = ""
        flights= db.session.query(
            Flight.id,
            Flight.plane_id,
            Flight.flight_number,
            Flight.airline_id,
            Plane.capacity.label('plane_capacity'),
            Plane.model.label('plane_name'),
            Airline.name.label('airline_name'),
            dep_airport.c.departure_airport,
            dep_airport.c.departure_city,
            arr_airport.c.arrival_airport,
            arr_airport.c.arrival_city
        ).join(Airline, Flight.airline_id == Airline.id) \
        .join(dep_airport, Flight.departure_airport == dep_airport.c.dep_airport_id) \
        .join(arr_airport, Flight.arrival_airport == arr_airport.c.arr_airport_id) \
        .join(Plane, Flight.plane_id == Plane.id)
#        queryd = db.session.query(Flight, Plane, Airport).join(Plane, Flight.plane_id == Plane.id) 
#        if flight_number:
#            queryd = queryd.filter(Flight.flight_number == flight_number)
#        if departure_city and arrival_city:
#            queryd = queryd.filter(
#                Flight.departure_airport == departure_city,
#                Flight.arrival_airport == arrival_city
#            )
        if flight_number:
            queryd = flights.filter(Flight.flight_number == flight_number)
            flight_results = queryd.all()
        if departure_city and arrival_city:
            dp_id = db.session.query(Airport.id).filter(Airport.name == departure_city).scalar() 
            ar_id = db.session.query(Airport.id).filter(Airport.name == arrival_city).scalar()
            if dp_id and ar_id:
                queryd = flights.filter(
                    Flight.departure_airport == dp_id,
                    Flight.arrival_airport == ar_id
                )
                flight_results = queryd.all()

        #flight_results = db.session.query(Flight, Plane).join(Plane, Flight.flight_number == flight_number) 
        #flight_resultss = db.session.query(Flight).filter(Flight.flight_number == flight_number)

        enriched_flight_results = []
        for flight in flight_results:
            tickets_sold = db.session.query(Ticket).filter(Ticket.flight_id == flight.id).count()
            price = random.randint(100, 1000)  
            availability = "Available" if tickets_sold < flight.plane_capacity else "Full"

            enriched_flight_results.append({
                "id": flight.id,
                "plane_id": flight.plane_id,
                "flight_number": flight.flight_number,
                "airline_id": flight.airline_id,
                "plane_capacity": flight.plane_capacity,
                "plane_name": flight.plane_name,
                "airline_name": flight.airline_name,
                "departure_airport": flight.departure_airport,
                "departure_city": flight.departure_city,
                "arrival_airport": flight.arrival_airport,
                "arrival_city": flight.arrival_city,
                "price": price,
                "availability": availability
            })

        return render_template('find_flights.html', flight_results=enriched_flight_results, cities=get_cities(), user_id=user_id)

    return render_template('find_flights.html', flight_results=None, cities=get_cities(), user_id=user_id)

@app.route('/book_ticket/<int:user_id>', methods=['POST'])
def book_ticket(user_id):
    #user_id = request.form.get('user_id')
    flight_id = request.form.get('flight_id')

    flight = db.session.query(Flight).filter(Flight.id == flight_id).first()
    tickets_sold = db.session.query(Ticket).filter(Ticket.flight_id == flight.id).count()
   # if tickets_sold >= flight.plane.capacity:
   #     return "Flight is full!", 400

    price = random.randint(100, 1000)
    seat_number = ''.join(random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890', k=5))
    max_id = db.session.query(db.func.max(Ticket.id)).scalar() or 0
    new_ticket = Ticket(
        id=max_id + 1,
        passenger_id=user_id,
        flight_id=flight.id,
        price=price,
        seat_number=seat_number
    )
    db.session.add(new_ticket)
    db.session.commit()

    return redirect(url_for('user_home', user_id=user_id))

def get_cities():
    departure_cities = db.session.query(Airport.name).select_from(Flight).join(Airport, Flight.departure_airport == Airport.id).distinct().all()
    
    arrival_cities = db.session.query(Airport.name).select_from(Flight).join(Airport, Flight.arrival_airport == Airport.id).distinct().all()
    
    cities = {city[0] for city in departure_cities + arrival_cities}
    
    return sorted(cities)



if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
