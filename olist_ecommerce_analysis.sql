/* ======================================================================
   Title: Olist E-commerce Analysis
   Author: Araadhye Bisht

   About:
   This project analyzes the Olist Brazilian E-commerce dataset to uncover 
   insights into customer behavior, seller performance, product categories, 
   payment methods, and retention trends. It covers key metrics like repeat 
   purchase rate, cohort-based retention & churn, top cities by sales, 
   product category performance, and average order values. The goal is to 
   provide actionable business intelligence that can help improve customer 
   loyalty, optimize seller strategies, and drive revenue growth.
   ====================================================================== */
USE olist;
SHOW TABLES;
-- ----------------------------------------------------------------------
-- Total unique customers
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;
-- ----------------------------------------------------------------------
-- Repeat purchase rate
SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS repeat_purchase_rate
FROM (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customers c
      ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'           -- keep consistent with cohort logic
    GROUP BY c.customer_unique_id
) AS subq;
-- ======================================================================
-- Cohort Analysis (Retention & Churn)
DROP VIEW IF EXISTS customer_first_order;
DROP VIEW IF EXISTS customer_cohort;
DROP VIEW IF EXISTS cohort_retention_churn;

CREATE OR REPLACE VIEW customer_first_order AS
SELECT 
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_order_date
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;
-- ----------------------------------------------------------------------
CREATE OR REPLACE VIEW customer_cohort AS
SELECT 
    cf.customer_unique_id,
    DATE_FORMAT(cf.first_order_date, '%Y-%m') AS cohort_month
FROM customer_first_order cf;
-- ----------------------------------------------------------------------
DROP VIEW IF EXISTS cohort_retention_churn;

CREATE VIEW cohort_retention_churn AS
SELECT 
    cc.cohort_month,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT c.customer_unique_id) AS active_customers,
    COUNT(DISTINCT c.customer_unique_id) * 1.0 / cs.cohort_size AS retention_rate,
    1 - (COUNT(DISTINCT c.customer_unique_id) * 1.0 / cs.cohort_size) AS churn_rate
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN customer_cohort cc ON cc.customer_unique_id = c.customer_unique_id
JOIN (
    SELECT DATE_FORMAT(first_order_date, '%Y-%m') AS cohort_month,
           COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_first_order
    GROUP BY DATE_FORMAT(first_order_date, '%Y-%m')
) cs ON cc.cohort_month = cs.cohort_month
WHERE o.order_status = 'delivered'
GROUP BY cc.cohort_month, order_month, cs.cohort_size
ORDER BY cc.cohort_month, order_month;

SELECT * FROM cohort_retention_churn;
-- ======================================================================
-- Top Cities By Sales
SELECT s.seller_city, count(*) AS sales_by_city
FROM order_items o
JOIN sellers s ON o.seller_id= s.seller_id
GROUP BY s.seller_city
ORDER BY sales_by_city DESC;
-- ======================================================================
-- product category analysis
SELECT pt.product_category_name_english, count(o.order_id) AS order_count , sum(o.price+o.freight_value) as net_revenue_generated, (sum(o.price)/count(o.order_id)) as Avg_order_value
FROM order_items o
JOIN products p ON o.product_id = p.product_id
JOIN product_category_translation pt ON pt.product_category_name = p.product_category_name
GROUP BY pt.product_category_name_english
ORDER BY net_revenue_generated DESC;

SELECT pt.product_category_name_english, ROUND(AVG(r.review_score),2) as Average_Score
FROM products p
JOIN order_items o ON o.product_id = p.product_id
JOIN order_reviews r  ON r.order_id = o.order_id
JOIN product_category_translation pt ON pt.product_category_name = p.product_category_name
GROUP BY product_category_name_english
ORDER BY Average_Score DESC;
-- =======================================================================
-- What are the most common payment methods?
select payment_type, count(order_id) as no_of_payments from order_payments group by payment_type order by no_of_payments DESC;
-- How many installments do customers usually use (product_category_wise)?
SELECT pt.product_category_name_english AS product_category,ROUND(AVG(op.payment_installments), 2) AS avg_installments
FROM orders o
JOIN order_payments op ON o.order_id = op.order_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pt ON p.product_category_name = pt.product_category_name
GROUP BY pt.product_category_name_english
ORDER BY avg_installments DESC;
-- ======================================================================
-- "sellers" analysis
SELECT seller_id, SUM(price) as Net_Revenue_by_seller, count(order_id) as net_orders, (sum(price)/count(order_id)) as Avg_order_value
FROM order_items o
GROUP BY seller_id
ORDER BY Net_Revenue_by_seller DESC;