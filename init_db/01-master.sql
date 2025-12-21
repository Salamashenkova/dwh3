-- ========================================
-- 01-master.sql → 4 БД + presentation (ПО ТЗ!)
-- ========================================

-- 1. Создаем БД (с DROP!)
DROP DATABASE IF EXISTS user_service_db;
DROP DATABASE IF EXISTS order_service_db;
DROP DATABASE IF EXISTS logistics_service_db;
DROP DATABASE IF EXISTS airflow;
CREATE DATABASE user_service_db;
CREATE DATABASE order_service_db;
CREATE DATABASE logistics_service_db;
CREATE DATABASE airflow;

-- 2. Presentation в postgres (9 + 8 полей ПО ТЗ!)
CREATE SCHEMA IF NOT EXISTS presentation;

-- Витрина 1: Аналитика закупок (9 полей)
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
    PRIMARY KEY (purchase_date, product_id, supplier_id)
);

INSERT INTO presentation.purchase_analytics 
SELECT 
    CURRENT_DATE - (n)::int,
    (random()*1000)::int as product_id,
    'Товар ' || ((random()*10)::int + 1),
    CASE WHEN random() > 0.5 THEN 'Электроника' ELSE 'Одежда' END,
    (random()*50)::int + 1 as supplier_id,
    'Поставщик ' || ((random()*5)::int + 1),
    (random()*100)::numeric(10,2),
    (random()*10000)::numeric(12,2),
    (random()*1000)::numeric(10,2)
FROM generate_series(0,29) n CROSS JOIN generate_series(1,100);

-- Витрина 2: Доставка по складам (8 полей)  
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
    PRIMARY KEY (shipment_date, warehouse_id)
);

INSERT INTO presentation.warehouse_delivery 
SELECT 
    CURRENT_DATE - (n)::int,
    generate_series(1,6) as warehouse_id,
    'Склад ' || generate_series(1,6),
    (random()*50 + 10)::int,
    (random()*1000)::numeric(10,2),
    (random()*120 + 30)::numeric(5,2),
    (random()*5)::int,
    (random()*20 + 5)::int
FROM generate_series(0,29) n CROSS JOIN generate_series(1,1);

-- 3. User Service DB (1000 пользователей)
CREATE TABLE user_service_db.public.users (
    user_external_id VARCHAR PRIMARY KEY,
    email VARCHAR,
    first_name VARCHAR,
    status VARCHAR DEFAULT 'active'
);

INSERT INTO user_service_db.public.users 
SELECT 
    'user_' || gs, 
    'user' || gs || '@test.com', 
    'Имя' || gs, 
    CASE WHEN gs % 10 = 0 THEN 'inactive' ELSE 'active' END
FROM generate_series(1,1000) gs;

-- 4. Order Service DB (5000 заказов)
CREATE TABLE order_service_db.public.orders (
    order_external_id VARCHAR PRIMARY KEY,
    user_external_id VARCHAR,
    total_amount NUMERIC,
    status VARCHAR DEFAULT 'new',
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO order_service_db.public.orders 
SELECT 
    'order_' || gs, 
    'user_' || ((gs-1) % 1000 + 1),
    random()*10000, 
    CASE WHEN gs % 5 = 0 THEN 'completed' ELSE 'new' END,
    CURRENT_DATE - (random()*30)::int
FROM generate_series(1,5000) gs;

-- 5. Logistics Service DB (4000 отправлений)
CREATE TABLE logistics_service_db.public.shipments (
    shipment_external_id VARCHAR PRIMARY KEY,
    order_external_id VARCHAR,
    status VARCHAR DEFAULT 'new',
    warehouse_id INT,
    shipment_date DATE
);

INSERT INTO logistics_service_db.public.shipments 
SELECT 
    'shipment_' || gs, 
    'order_' || ((gs-1) % 5000 + 1),
    CASE WHEN gs % 3 = 0 THEN 'delivered' ELSE 'new' END,
    ((gs-1) % 6 + 1) as warehouse_id,
    CURRENT_DATE - ((gs-1)/1000)::int
FROM generate_series(1,4000) gs;

-- Финальный лог
SELECT 
  '✅ HW3 ГОТОВО! (ПО ТЗ)' as status,
  (SELECT COUNT(*) FROM presentation.purchase_analytics) as purchases,
  (SELECT COUNT(*) FROM presentation.warehouse_delivery) as warehouses,
  (SELECT COUNT(*) FROM user_service_db.public.users) as users,
  (SELECT COUNT(*) FROM order_service_db.public.orders) as orders,
  (SELECT COUNT(*) FROM logistics_service_db.public.shipments) as shipments;
