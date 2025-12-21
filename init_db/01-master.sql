-- ========================================
-- 01-master.sql → 4 БД + presentation (ЧИСТЫЙ SQL!)
-- ========================================

-- 1. Создаем БД
CREATE DATABASE user_service_db;
CREATE DATABASE order_service_db;
CREATE DATABASE logistics_service_db;
CREATE DATABASE airflow;

-- 2. Presentation в postgres (ПЕРВЫМ!)
CREATE SCHEMA presentation;

CREATE OR REPLACE FUNCTION init_presentation() RETURNS void AS $$
BEGIN
    -- Закупки (100 строк)
    DROP TABLE IF EXISTS presentation.purchase_analytics;
    CREATE TABLE presentation.purchase_analytics (
        purchase_date DATE,
        product_name TEXT,
        category TEXT,
        purchase_qty NUMERIC,
        total_amount NUMERIC
    );
    INSERT INTO presentation.purchase_analytics 
    SELECT 
        CURRENT_DATE - (random()*30)::int,
        'Товар ' || ((random()*10)::int + 1),
        CASE WHEN random() > 0.5 THEN 'Электроника' ELSE 'Одежда' END,
        random()*100,
        random()*10000
    FROM generate_series(1, 100);

    -- Склады (30 строк)
    DROP TABLE IF EXISTS presentation.warehouse_delivery;
    CREATE TABLE presentation.warehouse_delivery (
        shipment_date DATE,
        warehouse_name TEXT,
        order_count INTEGER,
        delayed_count INTEGER
    );
    INSERT INTO presentation.warehouse_delivery 
    SELECT 
        CURRENT_DATE - (random()*7)::int,
        'Склад ' || ((random()*3)::int + 1),
        (random()*50)::int + 10,
        (random()*5)::int
    FROM generate_series(1, 30);
END;
$$ LANGUAGE plpgsql;

SELECT init_presentation();

-- 3. Пользователи (после паузы)
DO $$ BEGIN PERFORM pg_sleep(2); END $$;
\connect user_service_db
CREATE TABLE users (
    user_external_id VARCHAR PRIMARY KEY,
    email VARCHAR,
    first_name VARCHAR,
    status VARCHAR DEFAULT 'active'
);
INSERT INTO users SELECT 
    'user_' || gs, 
    'user' || gs || '@test.com', 
    'Имя' || gs, 
    CASE WHEN gs % 10 = 0 THEN 'inactive' ELSE 'active' END
FROM generate_series(1,1000) gs;

-- 4. Заказы
\connect order_service_db
CREATE TABLE orders (
    order_external_id VARCHAR PRIMARY KEY,
    user_external_id VARCHAR,
    total_amount NUMERIC,
    status VARCHAR DEFAULT 'new'
);
INSERT INTO orders SELECT 
    'order_' || gs, 
    'user_' || ((gs-1) % 1000 + 1),
    random()*10000, 
    CASE WHEN gs % 5 = 0 THEN 'completed' ELSE 'new' END
FROM generate_series(1,1000) gs;

-- 5. Отправления
\connect logistics_service_db
CREATE TABLE shipments (
    shipment_external_id VARCHAR PRIMARY KEY,
    order_external_id VARCHAR,
    status VARCHAR DEFAULT 'new'
);
INSERT INTO shipments SELECT 
    'shipment_' || gs, 
    'order_' || ((gs-1) % 1000 + 1),
    CASE WHEN gs % 3 = 0 THEN 'delivered' ELSE 'new' END
FROM generate_series(1,1000) gs;

-- Финальный лог
\connect postgres
SELECT '✅ HW3 ГОТОВО!' as status;
