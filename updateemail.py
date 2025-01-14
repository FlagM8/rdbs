import pandas as pd
import random
import string

# Load the data from CSV
df = pd.read_csv('./data/tables/passengers.csv')

# Define a function to add random characters to the start of an email
def add_random_characters(email):
    random_characters = ''.join(random.choice(string.ascii_lowercase) for _ in range(2))
    return random_characters + email

# Apply the function to the email column
df['email'] = df['email'].apply(add_random_characters)

# Save the updated data to a new CSV file
df.to_csv('updated_data.csv', index=False)