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
    "purchase_analytics_daily",
    default_args=default_args,
    catchup=False,
    schedule_interval="30 2 * * *",  # 02:30 ежедневно
    max_active_runs=1,
    tags=['presentation', 'purchases']
) as dag:

    create_purchase_vitrina = PostgresOperator(
        task_id="create_purchase_analytics_vitrina",
        postgres_conn_id="postgres_master",
        sql="""
        -- ✅ Витрина 1: Аналитика закупок (presentation.purchase_analytics)
        CREATE TABLE IF NOT EXISTS presentation.purchase_analytics (
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

        -- ✅ Полное обновление за вчера
        DELETE FROM presentation.purchase_analytics 
        WHERE purchase_date = CURRENT_DATE - INTERVAL '1 day';

        -- ✅ ETL: из DDS → presentation (сырые данные из микросервисов)
        INSERT INTO presentation.purchase_analytics
        SELECT 
            DATE(o.order_date) as purchase_date,
            oi.order_item_id as product_id,
            oi.product_name_snapshot as product_name,
            oi.product_category_snapshot as category,
            o.user_external_id::INT as supplier_id,  -- user_external_id как supplier
            u.first_name || ' ' || u.last_name as supplier_name,
            oi.quantity as purchase_qty,
            oi.total_price as total_purchase_amount,
            oi.unit_price as avg_unit_price
        FROM order_service_db.ORDERS o
        JOIN order_service_db.ORDER_ITEMS oi ON o.order_external_id = oi.order_external_id
        JOIN user_service_db.USERS u ON o.user_external_id = u.user_external_id
        WHERE DATE(o.order_date) = CURRENT_DATE - INTERVAL '1 day';
        """,
        autocommit=True
    )
