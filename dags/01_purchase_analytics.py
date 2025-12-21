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

def create_table():
    hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
    CREATE SCHEMA IF NOT EXISTS presentation;
    DROP TABLE IF EXISTS presentation.purchase_analytics;
    
    CREATE TABLE presentation.purchase_analytics (
        purchase_date DATE NOT NULL,
        product_id INT NOT NULL,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        supplier_id INT NOT NULL,
        supplier_name TEXT NOT NULL,
        purchase_qty NUMERIC NOT NULL,
        total_purchase_amount NUMERIC NOT NULL,
        avg_unit_price NUMERIC NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (purchase_date, product_id, supplier_id)
    );
    
    INSERT INTO presentation.purchase_analytics 
    SELECT 
        CURRENT_DATE - (random()*30)::int,
        (random()*1000)::int,
        'Товар ' || ((random()*10)::int + 1),
        CASE WHEN random() > 0.5 THEN 'Электроника' ELSE 'Одежда' END,
        (random()*50)::int + 1,
        'Поставщик ' || ((random()*5)::int + 1),
        (random()*100)::numeric(10,2),           -- ✅ ФИКС!
        (random()*10000)::numeric(12,2),          -- ✅ ФИКС!
        (random()*1000)::numeric(10,2),           -- ✅ ФИКС!
        CURRENT_TIMESTAMP
    FROM generate_series(1, 100);
    
    SELECT COUNT(*) FROM presentation.purchase_analytics;
    """
    hook.run(sql)
    print("✅ 100 строк созданы!")

with DAG(
    "purchase_analytics_daily",
    default_args=default_args,
    catchup=False,
    schedule_interval="30 2 * * *",
    max_active_runs=1,
    tags=['presentation', 'purchases']
) as dag:

    create_purchase_vitrina = PythonOperator(
        task_id="create_purchase_analytics_vitrina",
        python_callable=create_table,
        execution_timeout=timedelta(minutes=3)
    )
