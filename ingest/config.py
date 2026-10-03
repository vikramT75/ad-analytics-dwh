# Database connection configuration
# Update SERVER to your SQL Server instance name
SERVER = 'localhost\\SQLEXPRESS'   # common default; adjust if needed
DATABASE = 'DataWarehouse'
DATA_DIR = r'E:\awat\sql-proj\datasets'

# Connection string for pyodbc with Windows Authentication
CONNECTION_STRING = (
    f'DRIVER={{ODBC Driver 17 for SQL Server}};'
    f'SERVER={SERVER};'
    f'DATABASE={DATABASE};'
    'Trusted_Connection=yes;'
)
