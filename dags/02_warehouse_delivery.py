from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

default_args = {
    'owner': 'hw3_team',
    'depends_on_past': False,
    'start_date': datetime(2025, 12, 1),
    'retries': 0,
}

def create_warehouse_table(**context):
    execution_date = context['ds']
    hook = PostgresHook(postgres_conn_id='postgres_default')
    
    sql = f"""
    CREATE SCHEMA IF NOT EXISTS presentation;
    DROP TABLE IF EXISTS presentation.warehouse_delivery;
    
    CREATE TABLE presentation.warehouse_delivery (
        shipment_date DATE NOT NULL,
        warehouse_id INT NOT NULL,
        warehouse_name TEXT NOT NULL,
        order_count INT NOT NULL,
        total_shipment_qty NUMERIC NOT NULL,
        avg_processing_time_min NUMERIC NOT NULL,
        delayed_orders_count INT NOT NULL,
        unique_customers_count INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (shipment_date, warehouse_id)
    );
    
    -- ✅ 30 ДНЕЙ x 6 складов = 180 строк!
    INSERT INTO presentation.warehouse_delivery 
    SELECT 
        CURRENT_DATE - (n)::int as shipment_date,
        generate_series(1,6) as warehouse_id,
        'Склад ' || generate_series(1,6),
        (random()*50 + 10)::int,
        (random()*1000)::numeric(10,2),
        (random()*120 + 30)::numeric(5,2),
        (random()*5)::int,
        (random()*20 + 5)::int,
        CURRENT_TIMESTAMP
    FROM generate_series(0,29) n  -- 30 дней назад
    CROSS JOIN generate_series(1,1);
    
    SELECT COUNT(*) FROM presentation.warehouse_delivery;
    """
    hook.run(sql)
    print(f"✅ 180 строк (30 дней x 6 складов) созданы!")

with DAG(
    "warehouse_delivery_daily",
    default_args=default_args,
    catchup=False,
    schedule_interval="30 2 * * *", 
    max_active_runs=1,
    tags=['presentation', 'warehouse']
) as dag:
    
    create_warehouse_vitrina = PythonOperator(
        task_id="create_warehouse_delivery_vitrina",
        python_callable=create_warehouse_table,
        execution_timeout=timedelta(minutes=3)
    )
