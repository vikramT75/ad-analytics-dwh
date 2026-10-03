import pyodbc
import os
import sys
import ingest.config as config

def run_sql_script(conn, filepath):
    print(f"Executing: {filepath}")
    with open(filepath, 'r') as file:
        sql = file.read()
    
    # Split by GO for batches
    batches = [b for b in sql.split('GO\n') if b.strip()]
    
    cursor = conn.cursor()
    for batch in batches:
        try:
            cursor.execute(batch)
        except Exception as e:
            print(f"Error in batch:\n{batch[:100]}...\n{e}")
            raise
    cursor.commit()
    print(f"Successfully executed {filepath}\n")

def main():
    # Connect to master DB
    conn_str_master = config.CONNECTION_STRING.replace(config.DATABASE, 'master')
    conn_str_master = conn_str_master.replace('ODBC Driver 17 for SQL Server', 'SQL Server')
    
    try:
        print("Connecting to master database...")
        conn_master = pyodbc.connect(conn_str_master, autocommit=True)
    except Exception as e:
        print(f"Failed to connect to SQL Server. Ensure your instance '{config.SERVER}' is running.")
        print(f"Error: {e}")
        sys.exit(1)
        
    run_sql_script(conn_master, 'scripts/init_database.sql')
    conn_master.close()
    
    # Connect to DataWarehouse
    conn_str_dw = config.CONNECTION_STRING.replace('ODBC Driver 17 for SQL Server', 'SQL Server')
    print("Connecting to DataWarehouse database...")
    conn = pyodbc.connect(conn_str_dw, autocommit=True)
    
    # Create schema
    scripts_to_run = [
        'scripts/bronze/ddl_bronze.sql',
        'scripts/bronze/proc_load_bronze.sql',
        'scripts/silver/ddl_silver.sql',
        'scripts/silver/proc_load_silver.sql',
        'scripts/gold/ddl_gold.sql',
        'scripts/gold/proc_load_gold.sql',
        'scripts/analytics/report_campaign_performance.sql',
        'scripts/analytics/report_audience_segments.sql',
        'scripts/analytics/report_funnel_metrics.sql',
        'scripts/analytics/report_device_reach.sql'
    ]
    
    for script in scripts_to_run:
        run_sql_script(conn, script)
        
    print("Executing Stored Procedures to load data...")
    
    # Load data
    cursor = conn.cursor()
    print("Loading Bronze...")
    cursor.execute("EXEC bronze.load_bronze;")
    
    print("Loading Silver...")
    cursor.execute("EXEC silver.load_silver;")
    
    print("Loading Gold...")
    cursor.execute("EXEC gold.load_gold;")
    
    print("\nPipeline execution complete!")
    conn.close()

if __name__ == '__main__':
    main()
