from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

default_args = {
    'owner': 'hw3_team',
    'depends_on_past': False,
    'start_date': datetime(2025, 12, 1),
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
}

def create_warehouse_table():
    hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
    -- ✅ Создаём схему (если нет)
    CREATE SCHEMA IF NOT EXISTS presentation;
    
    -- ✅ Удаляем старую таблицу + СБРОС sequence!
    DROP TABLE IF EXISTS presentation.warehouse_delivery;
    DROP SEQUENCE IF EXISTS presentation.warehouse_delivery_warehouse_id_seq;
    
    -- ✅ Создаём новую таблицу
    CREATE TABLE presentation.warehouse_delivery (
        shipment_date DATE NOT NULL,
        warehouse_id SERIAL PRIMARY KEY,
        warehouse_name TEXT NOT NULL,
        order_count INT NOT NULL,
        total_shipment_qty NUMERIC NOT NULL,
        avg_processing_time_min NUMERIC,
        delayed_orders_count INT DEFAULT 0,
        unique_customers_count INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ✅ Вставляем 50 строк для Grafana (пусть SERIAL сам генерирует ID!)
    INSERT INTO presentation.warehouse_delivery (
        shipment_date, warehouse_name, order_count, total_shipment_qty,
        avg_processing_time_min, delayed_orders_count, unique_customers_count, created_at
    ) 
    SELECT 
        CURRENT_DATE - (random()*7)::int,
        'Склад ' || ((random()*3)::int + 1),
        (random()*50)::int + 10,
        (random()*10000)::numeric(12,2),
        (random()*120)::numeric(8,2),
        (random()*5)::int,
        (random()*20)::int + 5,
        CURRENT_TIMESTAMP
    FROM generate_series(1, 50);

    -- ✅ Проверяем результат
    SELECT COUNT(*) FROM presentation.warehouse_delivery;
    """
    hook.run(sql)
    print("✅ 50 строк созданы в presentation.warehouse_delivery!")

with DAG(
    "warehouse_delivery_daily",
    default_args=default_args,
    catchup=False,
    schedule_interval="45 2 * * *",
    max_active_runs=1,
    tags=['presentation', 'warehouse']
) as dag:

    create_warehouse_vitrina = PythonOperator(
        task_id="create_warehouse_delivery_vitrina",
        python_callable=create_warehouse_table,
        execution_timeout=timedelta(minutes=3)
    )
