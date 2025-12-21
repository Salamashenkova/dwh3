-- ========================================
-- 01-master.sql → 4 БД + presentation (2025)
-- ========================================

-- 1. Создаем БД (DROP + CREATE)
DROP DATABASE IF EXISTS user_service_db;
DROP DATABASE IF EXISTS order_service_db;
DROP DATABASE IF EXISTS logistics_service_db;
CREATE DATABASE user_service_db;
CREATE DATABASE order_service_db;
CREATE DATABASE logistics_service_db;
CREATE DATABASE airflow;

-- 2. Presentation в postgres (ПЕРВЫМ!)
\c postgres
CREATE SCHEMA IF NOT EXISTS presentation;

-- Presentation витрины (3000 + 180 строк)
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
    CURRENT_DATE - (n)::int,
    (random()*1000)::int,
    'Товар ' || ((random()*10)::int + 1),
    CASE WHEN random() > 0.5 THEN 'Электроника' ELSE 'Одежда' END,
    (random()*50)::int + 1,
    'Поставщик ' || ((random()*5)::int + 1),
    (random()*100)::numeric(10,2),
    (random()*10000)::numeric(12,2),
    (random()*1000)::numeric(10,2),
    CURRENT_TIMESTAMP
FROM generate_series(0,29) n CROSS JOIN generate_series(1,100);

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

INSERT INTO presentation.warehouse_delivery 
SELECT 
    CURRENT_DATE - (n)::int,
    generate_series(1,6),
    'Склад ' || generate_series(1,6),
    (random()*50 + 10)::int,
    (random()*1000)::numeric(10,2),
    (random()*120 + 30)::numeric(5,2),
    (random()*5)::int,
    (random()*20 + 5)::int,
    CURRENT_TIMESTAMP
FROM generate_series(0,29) n CROSS JOIN generate_series(1,1);

-- 3. User Service DB (ПОЛНАЯ СХЕМА)
\c user_service_db
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE public.USERS (
    user_external_id VARCHAR PRIMARY KEY,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    phone VARCHAR,
    date_of_birth DATE,
    registration_date TIMESTAMP,
    status VARCHAR,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.USERS SELECT 
    'user_' || gs,
    'user' || gs || '@test.com',
    'Имя' || gs,
    'Фамилия' || gs,
    '+7(999)123' || LPAD(gs::text, 2, '0') || gs::text,
    CURRENT_DATE - (random()*365*10)::int,
    CURRENT_DATE - (random()*30)::int,
    CASE WHEN random() > 0.95 THEN 'inactive' ELSE 'active' END,
    CURRENT_TIMESTAMP, NULL, true,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,1000) gs;

CREATE TABLE public.USER_ADDRESSES (
    address_id SERIAL PRIMARY KEY,
    address_external_id VARCHAR UNIQUE,
    user_external_id VARCHAR REFERENCES public.USERS(user_external_id),
    address_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    street_address VARCHAR,
    postal_code VARCHAR,
    apartment VARCHAR,
    status VARCHAR,
    change_reason VARCHAR,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.USER_ADDRESSES SELECT 
    'addr_' || gs,
    'user_' || ((gs-1) % 1000 + 1),
    CASE WHEN random() > 0.5 THEN 'home' ELSE 'work' END,
    'Россия', 'Москва', 'Москва',
    'Ленинский проспект ' || gs, '119261', gs::text,
    'active', NULL, CURRENT_TIMESTAMP, NULL, true,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,1500) gs;

CREATE TABLE public.USER_STATUS_HISTORY (
    history_id SERIAL PRIMARY KEY,
    user_external_id VARCHAR REFERENCES public.USERS(user_external_id),
    changed_at TIMESTAMP,
    is_default BOOLEAN,
    changed_by VARCHAR,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

-- 4. Order Service DB (ПОЛНАЯ СХЕМА)
\c order_service_db
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE public.ORDERS (
    order_external_id VARCHAR PRIMARY KEY,
    user_external_id VARCHAR NOT NULL,
    order_date TIMESTAMP,
    subtotal DECIMAL,
    tax_amount DECIMAL,
    shipping_cost DECIMAL,
    discount_amount DECIMAL,
    total_amount DECIMAL,
    currency VARCHAR,
    status VARCHAR,
    payment_method VARCHAR,
    payment_status VARCHAR,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.ORDERS SELECT 
    'order_' || gs,
    'user_' || ((gs-1) % 1000 + 1),
    CURRENT_DATE - (random()*30)::int + (random()*24)::int/24,
    random()*5000, random()*500, random()*1000, random()*1000,
    random()*10000, 'RUB',
    CASE random() * 5::int WHEN 0 THEN 'new' WHEN 1 THEN 'paid' 
        WHEN 2 THEN 'shipped' WHEN 3 THEN 'delivered' ELSE 'cancelled' END,
    CASE random() > 0.7 THEN 'paid' ELSE 'pending' END,
    CURRENT_TIMESTAMP, NULL, true,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,5000) gs;

CREATE TABLE public.ORDER_ITEMS (
    order_item_id SERIAL PRIMARY KEY,
    order_external_id VARCHAR REFERENCES public.ORDERS(order_external_id),
    product_sku VARCHAR,
    product_name_snapshot VARCHAR,
    product_category_snapshot VARCHAR,
    product_brand_snapshot VARCHAR,
    unit_price DECIMAL,
    total_price DECIMAL,
    quantity INTEGER,
    volume_cubic_cm INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.ORDER_ITEMS SELECT 
    'order_' || ((gs-1) / 5 + 1),
    'SKU-' || gs,
    'Товар ' || ((gs % 50) + 1),
    CASE WHEN random() > 0.5 THEN 'Электроника' ELSE 'Одежда' END,
    'Brand' || ((gs % 10) + 1),
    random()*2000, random()*5000,
    (random()*5 + 1)::int, (random()*10000)::int,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,15000) gs;

CREATE TABLE public.ORDER_STATUS_HISTORY (
    history_id SERIAL PRIMARY KEY,
    order_external_id VARCHAR REFERENCES public.ORDERS(order_external_id),
    old_status VARCHAR,
    new_status VARCHAR,
    change_reason VARCHAR,
    changed_at TIMESTAMP,
    changed_by VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

-- 5. Logistics Service DB (ПОЛНАЯ СХЕМА)
\c logistics_service_db
CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE public.WAREHOUSES (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_code VARCHAR UNIQUE,
    warehouse VARCHAR,
    warehouse_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    max_capacity_cubic_meters DECIMAL,
    max_capacity_packages INTEGER,
    dimensions_height_cm DECIMAL,
    dimensions_length_cm DECIMAL,
    dimensions_width_cm DECIMAL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.WAREHOUSES SELECT 
    gs, 'WH-' || LPAD(gs::text, 3, '0'),
    'Склад ' || gs,
    CASE WHEN gs <= 3 THEN 'central' ELSE 'regional' END,
    'Россия', 'Московская область', 'Москва',
    random()*10000, (random()*50000 + 10000)::int,
    random()*500 + 200, random()*1000 + 500, random()*300 + 200,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,10) gs;

CREATE TABLE public.PICKUP_POINTS (
    pickup_point_id SERIAL PRIMARY KEY,
    pickup_point_code VARCHAR UNIQUE,
    pickup_point VARCHAR,
    pickup_point_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    street_address VARCHAR,
    postal_code VARCHAR,
    is_active BOOLEAN,
    max_capacity_cubic_meters DECIMAL,
    max_capacity_packages INTEGER,
    operating_hours VARCHAR,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.PICKUP_POINTS SELECT 
    gs, 'PP-' || LPAD(gs::text, 4, '0'),
    'ПВЗ ' || gs,
    CASE random() * 3::int WHEN 0 THEN 'boxberry' WHEN 1 THEN 'pickpoint' ELSE 'sdeK' END,
    'Россия', 'Москва', 'Москва',
    'ул. Тестовая ' || gs, '1190' || LPAD(gs::text, 2, '0'),
    random() > 0.05, random()*50, (random()*1000 + 100)::int,
    '10:00-22:00',
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,100) gs;

CREATE TABLE public.SHIPMENTS (
    shipment_id SERIAL PRIMARY KEY,
    shipment_external_id VARCHAR PRIMARY KEY DEFAULT 'shipment_' || generate_series(1,4000),
    order_external_id VARCHAR,
    pickup_point_code VARCHAR REFERENCES public.PICKUP_POINTS(pickup_point_code),
    tracking_number VARCHAR,
    status VARCHAR,
    weight_grams INTEGER,
    volume_cubic_cm INTEGER,
    recipient_name VARCHAR,
    delivery_signature VARCHAR,
    delivery_notes TEXT,
    effective_from TIMESTAMP,
    effective_to TIMESTAMP,
    is_current BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR,
    updated_by VARCHAR
);

INSERT INTO public.SHIPMENTS SELECT 
    'order_' || ((gs-1) % 5000 + 1),
    'PP-' || LPAD(((gs-1) % 100 + 1)::text, 4, '0'),
    'TN-' || LPAD(gs::text, 8, '0'),
    CASE random() * 4::int WHEN 0 THEN 'new' WHEN 1 THEN 'picked' 
        WHEN 2 THEN 'shipped' WHEN 3 THEN 'delivered' ELSE 'cancelled' END,
    (random()*5000 + 100)::int, (random()*50000 + 1000)::int,
    'Получатель ' || gs, NULL, NULL,
    CURRENT_TIMESTAMP, NULL, true,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'system', 'system'
FROM generate_series(1,4000) gs;

-- Финальный лог
\c postgres
SELECT 
  '✅ HW3 ГОТОВО! (БЕЗ cohort)' as status,
  (SELECT COUNT(*) FROM presentation.purchase_analytics) as purchases,
  (SELECT COUNT(*) FROM presentation.warehouse_delivery) as warehouses,
  (SELECT COUNT(*) FROM user_service_db.public.USERS) as users,
  (SELECT COUNT(*) FROM order_service_db.public.ORDERS) as orders,
  (SELECT COUNT(*) FROM logistics_service_db.public.SHIPMENTS) as shipments;
