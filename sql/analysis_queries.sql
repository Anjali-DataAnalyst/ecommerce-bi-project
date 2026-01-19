-- Total Revenue
SELECT ROUND(SUM(payment_value), 2) AS total_revenue
FROM payments;

-- Total Orders
SELECT COUNT(*) AS total_orders
FROM orders;

-- Monthly Orders Trend
SELECT
  DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
  COUNT(*) AS total_orders
FROM orders
GROUP BY month
ORDER BY month;

-- Monthly Revenue Trend
SELECT
  DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
  ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY month
ORDER BY month;

-- Top 10 Product Categories by Revenue
SELECT
  pr.product_category_name,
  ROUND(SUM(p.payment_value), 2) AS revenue
FROM order_items oi
JOIN products pr ON oi.product_id = pr.product_id
JOIN payments p ON oi.order_id = p.order_id
GROUP BY pr.product_category_name
ORDER BY revenue DESC
LIMIT 10;