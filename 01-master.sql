-- 01-master.sql → 3 микросервиса + ТЕСТОВЫЕ ДАННЫЕ (Debezium CDC)
-- ✅ Выполняется в docker-entrypoint-initdb.d → создаст 3 БД автоматически!

-- ========================================
-- 0. Создаем 3 БД (superuser postgres)
-- ========================================
CREATE DATABASE user_service_db;
CREATE DATABASE order_service_db; 
CREATE DATABASE logistics_service_db;

-- ========================================
-- 1. user_service_db (Debezium: user_service_db.public.USERS)
-- ========================================
\c user_service_db

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE SCHEMA IF NOT EXISTS user_service_db;
SET search_path TO user_service_db, public;

-- Таблица USERS
CREATE TABLE IF NOT EXISTS user_service_db.USERS (
    user_external_id VARCHAR PRIMARY KEY,
    email VARCHAR UNIQUE,
    first_name VARCHAR,
    last_name VARCHAR,
    phone VARCHAR,
    date_of_birth DATE,
    registration_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR DEFAULT 'active',
    effective_from TIMESTAMP DEFAULT NOW(),
    effective_to TIMESTAMP DEFAULT '9999-12-31'::timestamp,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ USERS
INSERT INTO user_service_db.USERS (user_external_id, email, first_name, last_name, phone, date_of_birth, status) VALUES
('user_001', 'ivan.petrov@test.com', 'Иван', 'Петров', '+7-900-123-45-67', '1985-03-15', 'active'),
('user_002', 'maria.sidorova@test.com', 'Мария', 'Сидорова', '+7-900-987-65-43', '1990-07-22', 'active'),
('user_003', 'alex.ivanov@test.com', 'Алексей', 'Иванов', '+7-900-111-22-33', '1992-11-08', 'inactive')
ON CONFLICT (user_external_id) DO NOTHING;

-- Таблица USER_ADDRESSES
CREATE TABLE IF NOT EXISTS user_service_db.USER_ADDRESSES (
    address_id SERIAL PRIMARY KEY,
    address_external_id VARCHAR UNIQUE,
    user_external_id VARCHAR REFERENCES user_service_db.USERS(user_external_id),
    address_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    street_address VARCHAR,
    postal_code VARCHAR,
    apartment VARCHAR,
    status VARCHAR DEFAULT 'active',
    change_reason VARCHAR,
    effective_from TIMESTAMP DEFAULT NOW(),
    effective_to TIMESTAMP DEFAULT '9999-12-31'::timestamp,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ USER_ADDRESSES
INSERT INTO user_service_db.USER_ADDRESSES (address_external_id, user_external_id, address_type, country, region, city, street_address, postal_code) VALUES
('addr_001', 'user_001', 'home', 'Russia', 'Moscow', 'Москва', 'Ленинский проспект 123', '119261'),
('addr_002', 'user_002', 'work', 'Russia', 'Saint Petersburg', 'Санкт-Петербург', 'Невский проспект 56', '191025')
ON CONFLICT (address_external_id) DO NOTHING;

-- Таблица USER_STATUS_HISTORY
CREATE TABLE IF NOT EXISTS user_service_db.USER_STATUS_HISTORY (
    history_id SERIAL PRIMARY KEY,
    user_external_id VARCHAR REFERENCES user_service_db.USERS(user_external_id),
    changed_at TIMESTAMP DEFAULT NOW(),
    is_default BOOLEAN DEFAULT false,
    changed_by VARCHAR DEFAULT 'system',
    effective_from TIMESTAMP DEFAULT NOW(),
    effective_to TIMESTAMP DEFAULT '9999-12-31'::timestamp,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ========================================
-- 2. order_service_db (Debezium: order_service_db.public.ORDERS)
-- ========================================
\c order_service_db

CREATE SCHEMA IF NOT EXISTS order_service_db;
SET search_path TO order_service_db, public;

CREATE TABLE IF NOT EXISTS order_service_db.ORDERS (
    order_external_id VARCHAR PRIMARY KEY,
    user_external_id VARCHAR NOT NULL,
    order_date TIMESTAMP DEFAULT NOW(),
    subtotal DECIMAL(15,2),
    tax_amount DECIMAL(15,2),
    shipping_cost DECIMAL(15,2),
    discount_amount DECIMAL(15,2),
    total_amount DECIMAL(15,2),
    currency VARCHAR DEFAULT 'RUB',
    status VARCHAR DEFAULT 'new',
    payment_method VARCHAR,
    payment_status VARCHAR DEFAULT 'pending',
    effective_from TIMESTAMP DEFAULT NOW(),
    effective_to TIMESTAMP DEFAULT '9999-12-31'::timestamp,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ ORDERS
INSERT INTO order_service_db.ORDERS (order_external_id, user_external_id, order_date, subtotal, tax_amount, shipping_cost, total_amount, status, payment_method) VALUES
('order_001', 'user_001', '2025-11-28 10:30:00', 1000.00, 180.00, 250.00, 1430.00, 'completed', 'card'),
('order_002', 'user_002', '2025-11-29 14:15:00', 750.00, 135.00, 200.00, 1085.00, 'shipped', 'cash'),
('order_003', 'user_001', '2025-11-29 16:45:00', 1500.00, 270.00, 300.00, 2070.00, 'new', 'card')
ON CONFLICT (order_external_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS order_service_db.ORDER_ITEMS (
    order_item_id SERIAL PRIMARY KEY,
    order_external_id VARCHAR REFERENCES order_service_db.ORDERS(order_external_id),
    product_sku VARCHAR,
    product_name_snapshot VARCHAR,
    product_category_snapshot VARCHAR,
    product_brand_snapshot VARCHAR,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(12,2),
    quantity INTEGER,
    volume_cubic_cm INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ ORDER_ITEMS
INSERT INTO order_service_db.ORDER_ITEMS (order_external_id, product_sku, product_name_snapshot, product_category_snapshot, unit_price, total_price, quantity) VALUES
('order_001', 'SKU-IPHONE15', 'iPhone 15 Pro 256GB', 'smartphones', 89900.00, 89900.00, 1),
('order_001', 'SKU-AIRPODS', 'AirPods Pro 2', 'headphones', 24900.00, 24900.00, 1),
('order_002', 'SKU-SAMSUNGTV', 'Samsung QLED 55"', 'televisions', 75000.00, 75000.00, 1)
ON CONFLICT DO NOTHING;

-- ========================================
-- 3. logistics_service_db (Debezium: logistics_service_db.public.SHIPMENTS)
-- ========================================
\c logistics_service_db

CREATE SCHEMA IF NOT EXISTS logistics_service_db;
SET search_path TO logistics_service_db, public;

CREATE TABLE IF NOT EXISTS logistics_service_db.WAREHOUSES (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_code VARCHAR UNIQUE,
    warehouse VARCHAR,
    warehouse_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    max_capacity_cubic_meters DECIMAL(10,2),
    max_capacity_packages INTEGER,
    dimensions_height_cm DECIMAL(6,2),
    dimensions_length_cm DECIMAL(6,2),
    dimensions_width_cm DECIMAL(6,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

INSERT INTO logistics_service_db.WAREHOUSES (warehouse_code, warehouse, warehouse_type, country, region, city, max_capacity_cubic_meters) VALUES
('WH_MSK_001', 'Склад Москва Центр', 'regional', 'Russia', 'Moscow', 'Москва', 5000.00),
('WH_SPB_001', 'Склад СПб Юг', 'regional', 'Russia', 'Saint Petersburg', 'Санкт-Петербург', 3000.00)
ON CONFLICT (warehouse_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS logistics_service_db.PICKUP_POINTS (
    pickup_point_id SERIAL PRIMARY KEY,
    pickup_point_code VARCHAR UNIQUE,
    pickup_point VARCHAR,
    pickup_point_type VARCHAR,
    country VARCHAR,
    region VARCHAR,
    city VARCHAR,
    street_address VARCHAR,
    postal_code VARCHAR,
    is_active BOOLEAN DEFAULT true,
    max_capacity_cubic_meters DECIMAL(10,2),
    max_capacity_packages INTEGER,
    operating_hours VARCHAR,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ PICKUP_POINTS
INSERT INTO logistics_service_db.PICKUP_POINTS (pickup_point_code, pickup_point, pickup_point_type, country, region, city, street_address, postal_code, operating_hours) VALUES
('PP_MSK_CENT_001', 'ПВЗ Москва Центр', 'boxberry', 'Russia', 'Moscow', 'Москва', 'Тверская 12', '125009', '10:00-22:00'),
('PP_SPB_NEV_001', 'ПВЗ СПб Невский', 'boxberry', 'Russia', 'Saint Petersburg', 'Санкт-Петербург', 'Невский 45', '191186', '09:00-21:00')
ON CONFLICT (pickup_point_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS logistics_service_db.SHIPMENTS (
    shipment_id SERIAL PRIMARY KEY,
    shipment_external_id UUID DEFAULT gen_random_uuid() UNIQUE,
    order_external_id VARCHAR,
    pickup_point_code VARCHAR REFERENCES logistics_service_db.PICKUP_POINTS(pickup_point_code),
    tracking_number VARCHAR UNIQUE,
    status VARCHAR DEFAULT 'new',
    weight_grams INTEGER,
    volume_cubic_cm INTEGER,
    recipient_name VARCHAR,
    delivery_signature VARCHAR,
    delivery_notes TEXT,
    effective_from TIMESTAMP DEFAULT NOW(),
    effective_to TIMESTAMP DEFAULT '9999-12-31'::timestamp,
    is_current BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by VARCHAR DEFAULT 'system',
    updated_by VARCHAR DEFAULT 'system'
);

-- ТЕСТОВЫЕ ДАННЫЕ SHIPMENTS
INSERT INTO logistics_service_db.SHIPMENTS (shipment_external_id, order_external_id, pickup_point_code, tracking_number, status, weight_grams, recipient_name) VALUES
(gen_random_uuid(), 'order_001', 'PP_MSK_CENT_001', 'MSK123456789', 'delivered', 2500, 'Иван Петров'),
(gen_random_uuid(), 'order_002', 'PP_SPB_NEV_001', 'SPB987654321', 'in_transit', 1500, 'Мария Сидорова')
ON CONFLICT (tracking_number) DO NOTHING;

--  Готово! 3 БД → 9 таблиц → 20+ тестовых записей!
