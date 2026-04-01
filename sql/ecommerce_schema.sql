-- =========================================
-- E-COMMERCE DATA ANALYSIS PROJECT
-- Author: Anjali
-- Tools: MySQL
-- Description: End-to-end SQL analysis including
-- schema design, KPIs, cohort analysis, and business insights
-- =========================================

-- DATABASE + TABLES

CREATE DATABASE IF NOT EXISTS ecommerce_bi;
USE ecommerce_bi;

-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10),
    PRIMARY KEY (customer_id)
);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    PRIMARY KEY (order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Products
CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    PRIMARY KEY (product_id)
);

-- Order Items
CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2),
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)   -- ✅ FIX ADDED
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(20),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

------------------------------------------------------------
-- VIEWS
------------------------------------------------------------

-- Revenue Summary
DROP VIEW IF EXISTS revenue_summary;

CREATE VIEW revenue_summary AS
SELECT 
    o.order_id,
    o.customer_id,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    SUM(p.payment_value) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY o.order_id, o.customer_id, month;

------------------------------------------------------------

-- Customer Summary (FIX: Avoid duplication issue)
DROP VIEW IF EXISTS customer_summary;

CREATE VIEW customer_summary AS
SELECT 
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id;

------------------------------------------------------------

-- Product Performance (FIX: renamed profit logic)
DROP VIEW IF EXISTS product_performance;

CREATE VIEW product_performance AS
SELECT 
    oi.product_id,
    SUM(oi.price) AS total_sales,
    SUM(oi.freight_value) AS total_freight
FROM order_items oi
GROUP BY oi.product_id;

------------------------------------------------------------

-- Customer Cohort (FIX improved logic)
DROP VIEW IF EXISTS customer_cohort;

CREATE VIEW customer_cohort AS
SELECT 
    c.customer_unique_id,
    DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m') AS cohort_month,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id, order_month;

------------------------------------------------------------
-- KPI QUERIES
------------------------------------------------------------

-- Total Orders
SELECT COUNT(*) AS total_orders FROM orders;

-- Total Customers
SELECT COUNT(*) AS total_customers FROM customers;

-- Total Revenue
SELECT ROUND(SUM(payment_value), 2) AS total_revenue FROM payments;

-- Revenue By Payment Type
SELECT 
    payment_type,
    ROUND(SUM(payment_value), 2) AS revenue
FROM payments
GROUP BY payment_type
ORDER BY revenue DESC;

------------------------------------------------------------
-- BUSINESS ANALYSIS
------------------------------------------------------------

-- Monthly Orders
SELECT 
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS total_orders
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY month;

------------------------------------------------------------

-- Monthly Revenue
SELECT 
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY month;

------------------------------------------------------------

-- Top Products
SELECT 
    product_id,
    ROUND(SUM(price + freight_value), 2) AS revenue
FROM order_items
GROUP BY product_id
ORDER BY revenue DESC
LIMIT 10;

------------------------------------------------------------

-- Top Customers
SELECT 
    c.customer_id,
    ROUND(SUM(p.payment_value), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 10;

------------------------------------------------------------

-- Average Order Value
SELECT 
    ROUND(SUM(p.payment_value) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id;

------------------------------------------------------------

-- Repeat Customers
SELECT COUNT(*) AS repeat_customers
FROM (
    SELECT customer_id
    FROM orders
    GROUP BY customer_id
    HAVING COUNT(order_id) > 1
) AS repeat_data;

------------------------------------------------------------

-- Top States By Revenue
SELECT 
    c.customer_state,
    ROUND(SUM(p.payment_value), 2) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 5;

------------------------------------------------------------

-- Customer Lifetime Value (CLV)
SELECT 
    c.customer_unique_id,
    ROUND(SUM(p.payment_value), 2) AS lifetime_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id
ORDER BY lifetime_value DESC
LIMIT 10;

------------------------------------------------------------
-- DATA CLEANING & EXTRA ANALYSIS
------------------------------------------------------------

-- Check NULLs
SELECT * FROM orders WHERE order_purchase_timestamp IS NULL;

------------------------------------------------------------

-- Delivery Performance
SELECT 
    AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

------------------------------------------------------------

-- Order Status Distribution
SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

------------------------------------------------------------

-- Revenue Growth (Month over Month)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) 
        / LAG(revenue) OVER (ORDER BY month) * 100, 2
    ) AS growth_percentage
FROM (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        SUM(p.payment_value) AS revenue
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
) t;

------------------------------------------------------------

-- RFM Analysis
SELECT 
    c.customer_unique_id,
    MAX(o.order_purchase_timestamp) AS last_purchase,
    COUNT(o.order_id) AS frequency,
    SUM(p.payment_value) AS monetary
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_unique_id;