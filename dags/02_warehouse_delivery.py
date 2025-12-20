from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator

default_args = {
    'owner': 'hw3_team',
    'depends_on_past': False,
    'start_date': datetime(2025, 12, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    "warehouse_delivery_daily",
    default_args=default_args,
    catchup=False,
    schedule_interval="45 2 * * *",  # 02:45 ежедневно (за вчера)
    max_active_runs=1,
    tags=['presentation', 'warehouse']
) as dag:

    create_warehouse_vitrina = PostgresOperator(
        task_id="create_warehouse_delivery_vitrina",
        postgres_conn_id="postgres_master",
        sql="""
        -- ✅ Витрина 2: Доставка по складам (presentation.warehouse_delivery)
        CREATE TABLE IF NOT EXISTS presentation.warehouse_delivery (
            shipment_date DATE NOT NULL,
            warehouse_id SERIAL,
            warehouse_name TEXT NOT NULL,
            order_count INT NOT NULL,
            total_shipment_qty NUMERIC NOT NULL,
            avg_processing_time_min NUMERIC,
            delayed_orders_count INT DEFAULT 0,
            unique_customers_count INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (shipment_date, warehouse_id)
        );

        -- ✅ Удаляем данные за вчера (избегаем дублей)
        DELETE FROM presentation.warehouse_delivery 
        WHERE shipment_date = CURRENT_DATE - INTERVAL '1 day';

        -- ✅ ETL: из микросервисов → presentation
        INSERT INTO presentation.warehouse_delivery (
            shipment_date, warehouse_id, warehouse_name, order_count,
            total_shipment_qty, avg_processing_time_min, 
            delayed_orders_count, unique_customers_count
        )
        SELECT 
            DATE(s.created_at) as shipment_date,
            w.warehouse_id,
            w.warehouse as warehouse_name,
            COUNT(DISTINCT s.order_external_id) as order_count,
            SUM(s.volume_cubic_cm) as total_shipment_qty,
            AVG(EXTRACT(EPOCH FROM (s.created_at - o.order_date))/60) as avg_processing_time_min,
            COUNT(CASE WHEN s.status = 'delayed' THEN 1 END) as delayed_orders_count,
            COUNT(DISTINCT o.user_external_id) as unique_customers_count
        FROM logistics_service_db.SHIPMENTS s
        JOIN logistics_service_db.WAREHOUSES w ON s.pickup_point_code LIKE w.warehouse_code || '%'
        JOIN order_service_db.ORDERS o ON s.order_external_id = o.order_external_id
        WHERE DATE(s.created_at) = CURRENT_DATE - INTERVAL '1 day'
        GROUP BY DATE(s.created_at), w.warehouse_id, w.warehouse;
        """,
        autocommit=True
    )
