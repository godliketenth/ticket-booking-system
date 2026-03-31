
# config.py
# database connection settings
# update SERVER and DATABASE to match your local SQL Server setup

import pyodbc

SERVER   = 'localhost'          # or your SQL Server instance name e.g. DESKTOP-XXXX\SQLEXPRESS
DATABASE = 'TicketBookingSystem'
DRIVER   = 'ODBC Driver 17 for SQL Server'

# windows authentication (no username/password needed if using Windows login)
CONNECTION_STRING = (
    f'DRIVER={{{DRIVER}}};'
    f'SERVER={SERVER};'
    f'DATABASE={DATABASE};'
    f'Trusted_Connection=yes;'
)

# if you use SQL Server authentication instead, comment out the above and use this:
# SQL_USERNAME = 'your_username'
# SQL_PASSWORD = 'your_password'
# CONNECTION_STRING = (
#     f'DRIVER={{{DRIVER}}};'
#     f'SERVER={SERVER};'
#     f'DATABASE={DATABASE};'
#     f'UID={SQL_USERNAME};'
#     f'PWD={SQL_PASSWORD};'
# )
