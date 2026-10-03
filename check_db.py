import pyodbc
import ingest.config as config

def main():
    conn_str_dw = config.CONNECTION_STRING.replace('ODBC Driver 17 for SQL Server', 'SQL Server')
    try:
        conn = pyodbc.connect(conn_str_dw, autocommit=True)
        print("Success: Database connection is working properly!")
        conn.close()
    except Exception as e:
        print(f"Error connecting to database: {e}")

if __name__ == '__main__':
    main()
