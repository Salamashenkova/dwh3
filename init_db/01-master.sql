-- ========================================
-- 01-master.sql → 3 БД + 1000 данных (100% работает!)
-- ========================================

-- 1. Создаем БД (БЕЗ IF NOT EXISTS!)
CREATE DATABASE user_service_db;
CREATE DATABASE order_service_db;
CREATE DATABASE logistics_service_db;
CREATE DATABASE airflow;

-- 2. Пользователи (user_service_db)
\connect user_service_db

CREATE TABLE IF NOT EXISTS users (
    user_external_id VARCHAR PRIMARY KEY,
    email VARCHAR,
    first_name VARCHAR,
    status VARCHAR DEFAULT 'active'
);

INSERT INTO users (user_external_id, email, first_name, status)
SELECT 
    'user_' || generate_series,
    'user' || generate_series || '@test.com',
    'Имя' || generate_series,
    CASE WHEN generate_series % 10 = 0 THEN 'inactive' ELSE 'active' END
FROM generate_series(1,1000)
ON CONFLICT DO NOTHING;

-- 3. Заказы (order_service_db)
\connect order_service_db

CREATE TABLE IF NOT EXISTS orders (
    order_external_id VARCHAR PRIMARY KEY,
    user_external_id VARCHAR,
    total_amount DECIMAL(10,2),
    status VARCHAR DEFAULT 'new'
);

INSERT INTO orders (order_external_id, user_external_id, total_amount, status)
SELECT 
    'order_' || generate_series,
    'user_' || ((generate_series-1) % 1000 + 1),
    random() * 10000,
    CASE WHEN generate_series % 5 = 0 THEN 'completed' ELSE 'new' END
FROM generate_series(1,1000)
ON CONFLICT DO NOTHING;

-- 4. Отправления (logistics_service_db)
\connect logistics_service_db

CREATE TABLE IF NOT EXISTS shipments (
    shipment_external_id VARCHAR PRIMARY KEY,
    order_external_id VARCHAR,
    status VARCHAR DEFAULT 'new',
    weight_grams INTEGER
);

INSERT INTO shipments (shipment_external_id, order_external_id, status, weight_grams)
SELECT 
    'shipment_' || generate_series,
    'order_' || generate_series,
    CASE WHEN generate_series % 3 = 0 THEN 'delivered' ELSE 'new' END,
    1000 + (generate_series % 5000)
FROM generate_series(1,1000)
ON CONFLICT DO NOTHING;
