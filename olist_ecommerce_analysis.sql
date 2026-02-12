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
-- Total unique customers --> there are 96096 unique customers in the dataset 
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- Year-wise purchase date range --> here we can see that the data for 2016 starts from September, for 2017 it completes for the year while for 2018 it only goes till October. This indicates that the data for 2016 and 2018 is not complete and hence any analysis done on a yearly basis should take this into consideration as it can lead to skewed results. 
SELECT YEAR(order_purchase_timestamp) as year, MIN(DATE(order_purchase_timestamp)) as first_order, MAX(DATE(order_purchase_timestamp)) as last_order FROM orders
GROUP BY YEAR(order_purchase_timestamp)
ORDER BY year;
-- Total unique customers and percentage_active_users by year and state --> the growth is evident but not very conclusive as the data we have for 2016 starts from September, for 2017 it completes for the year while for 2018 it only goes till October. But we can surely say that sau paulo and rio de janeiro are the top states in terms of unique customers and active users with percentage of active users being more than 95%. We have also identified the states with no and low active users which can be a problem as it indicates that there is a lack of customer engagement in these states and olist can focus on improving the customer experience and engagement in these states to increase the percentage of active users.
WITH unique_customer_locations AS (
    SELECT DISTINCT customer_unique_id, customer_id, customer_zip_code_prefix
    FROM customers
),
unique_geo_states AS (
    SELECT DISTINCT geolocation_zip_code_prefix, geolocation_city
    FROM geolocation
),
unique_customer_purchases AS (
    SELECT DISTINCT customer_id, YEAR(order_purchase_timestamp) AS purchase_year, order_status
    FROM orders
)
SELECT 
    p.purchase_year AS year,
    g.geolocation_city AS state, 
    COUNT(u.customer_unique_id) AS unique_customers,
    ROUND(SUM(CASE WHEN p.order_status = 'delivered' THEN 1 ELSE 0 END)*100/COUNT(u.customer_unique_id), 2) AS percentage_active_users
FROM unique_customer_locations u
JOIN unique_geo_states g ON u.customer_zip_code_prefix = g.geolocation_zip_code_prefix
JOIN unique_customer_purchases p ON u.customer_id = p.customer_id
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC, 4 DESC;
-- --------------------------------------------------------------------------------------------------------------------------
-- Repeat purchase rate --> here we can see that the repeat purchase rate is around 0.0132 which is quite low and indicates that a very small percentage of customers are making repeat purchases on the platform. This can be a problem as it indicates that there is a lack of customer loyalty and engagement on the platform, which can lead to a high customer churn rate and low customer lifetime value. Olist can focus on improving the customer experience and engagement to increase the repeat purchase rate and retain more customers on the platform.
DROP TEMPORARY TABLE IF EXISTS subq;
CREATE TEMPORARY TABLE subq AS (
    SELECT 
        MONTHNAME(o.order_purchase_timestamp) as purchase_month,
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customers c
      ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, 1
);
SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 4) AS repeat_purchase_rate
FROM subq;
-- Repeat purchase rate by month --> here we can see that the repeat purchase rate is highest in the month of February and lowest in the month of April, this can be due to various reasons such as seasonality, promotions, holidays etc. but it can be inferred that customers who made their first purchase in may were more likely to make a repeat purchase than customers who made their first purchase in April.
SELECT  purchase_month, COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)*100 / COUNT(*), 4) AS repeat_purchase_percentage
FROM subq
GROUP BY purchase_month 
ORDER BY 4 DESC;
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
/*SELECT 
    cc.cohort_month,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) AS month_number,
    COUNT(DISTINCT c.customer_unique_id) AS active_customers,
    ROUND(COUNT(DISTINCT c.customer_unique_id) * 100/ cs.cohort_size, 2) AS percent_retention,
    ROUND(1 - (COUNT(DISTINCT c.customer_unique_id) * 100 / cs.cohort_size), 2) AS percent_churn
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
GROUP BY cc.cohort_month, month_number, order_month, cs.cohort_size
ORDER BY cc.cohort_month, month_number ;
*/
SELECT 
    cc.cohort_month,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 1 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 1 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
'%)' ) AS month_1,
    CONCAT( COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 2 THEN c.customer_unique_id END),
    ' (',
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 2 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), '%)'
) AS month_2,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 3 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 3 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_3,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 4 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 4 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_4,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 5 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 5 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_5,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 6 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 6 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_6,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 7 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 7 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_7,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 8 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 8 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_8,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 9 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 9 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_9,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 10 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 10 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_10,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 11 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 11 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_11,
    CONCAT(
    COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 12 THEN c.customer_unique_id END), 
    ' (', 
    ROUND(COUNT(DISTINCT CASE WHEN TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT(cc.cohort_month, '-01'), '%Y-%m-%d'), o.order_purchase_timestamp) = 12 THEN c.customer_unique_id END) * 100.0 / cohort_size, 2), 
    '%)'
) AS month_12

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
GROUP BY cc.cohort_month, cs.cohort_size
ORDER BY cc.cohort_month ;
SELECT * FROM cohort_retention_churn;
-- ====================================================================================================================================================================================================================================================================================================================================================================================================================================
-- product category analysis (by revenue, order count and AOV) --> here we can see that the most popular category is "bed_bath_table" followed by "health_beauty" and "sports_leisure", we can also note that these categories are not only popular but also yield a high revenue. We can also observe that auto, cool_stuff and housewares contribute the least to the revenue due to low AOV and a mediocre order count.
SELECT pt.product_category_name_english, count(o.order_id) AS order_count , sum(o.price+o.freight_value) as net_revenue_generated, (sum(o.price)/count(o.order_id)) as Avg_order_value
FROM order_items o
JOIN products p ON o.product_id = p.product_id
JOIN product_category_translation pt ON pt.product_category_name = p.product_category_name
GROUP BY pt.product_category_name_english
ORDER BY 3 DESC;
-- product category analysis (by reviews)--> it can be seen here that 'cds_dvds_musicals' and 'fashion_childrens_clothes' despite the high ratings don't contribut much to the net revenue due to low order count & 'security_and_services' and 'diapers_and_hygiene' have the poorest ratings and also contribute very less to the revenue again due to low order frequency. Now, 'diapers_and_hygiene' having the second lowest average review_score and the low order count can be a problem as poor reviews in this category can correlate to poor quality of products and order count should increase if we onload better quality products onto the platform. It can also be seen that the products bringing in the most revenue have an average_review_score of ~4/5.
SELECT pt.product_category_name_english, ROUND(AVG(r.review_score),2) as Average_Score, COUNT(review_id) as review_count, COUNT(o.order_id) AS order_count , ROUND(SUM(o.price+o.freight_value),2) as net_revenue_generated
FROM products p
JOIN order_items o ON o.product_id = p.product_id
JOIN order_reviews r  ON r.order_id = o.order_id
JOIN product_category_translation pt ON pt.product_category_name = p.product_category_name
GROUP BY product_category_name_english
ORDER BY 2 DESC;
-- product category analysis --> correlation between review score and GMV --> calculation for 'security_and_services' is not significant due to low order count but for the rest, we can see a bifurcation of categories having positive and negative coorelation which can be helpful in classifying categories that are more review score sensitive and the ones that are not. For example, 'diapers_and_hygiene' has a strong positive correlation between review score and GMV which indicates that improving the quality of products in this category can lead to an increase in revenue. On the other hand, 'cds_dvds_musicals' has a strong negative correlation which indicates that improving the review score of products in this category may not necessarily lead to an increase in revenue. This analysis can help in prioritising efforts to improve product quality and customer satisfaction in categories that are more review score sensitive.
SELECT pt.product_category_name_english,((COUNT(*)*SUM(r.review_score*(o.price+o.freight_value))-SUM(r.review_score)*SUM(o.price+o.freight_value))/SQRT(((COUNT(*)*SUM(r.review_score*r.review_score)-SUM(r.review_score)*SUM(r.review_score))*(COUNT(*)*SUM((o.price+o.freight_value)*(o.price+o.freight_value))-SUM(o.price+o.freight_value)*SUM(o.price+o.freight_value))))) AS correlation_between_review_score_and_GMV
FROM products p
JOIN order_items o ON o.product_id = p.product_id
INNER JOIN order_reviews r  ON r.order_id = o.order_id
JOIN product_category_translation pt ON pt.product_category_name = p.product_category_name
GROUP BY product_category_name_english
ORDER BY 2 DESC;
-- ===============================================================================================================================================================================================================================================================================================================================================================================================================================
-- What are the most common payment methods? --> here we can see that the most common payment method is credit card as it skews the distribution with a ~73% share of payments. This indicates that a significant portion of customers prefer using credit cards for their transactions on the platform, which could be due to factors such as convenience, rewards programs, or the ability to pay in installments.
select payment_type, COUNT(order_id) as no_of_payments, (COUNT(order_id)*100/(SELECT COUNT(order_id) FROM order_payments)) as percentage_share_of_payments 
FROM order_payments GROUP BY payment_type ORDER BY no_of_payments DESC;
-- How many installments do customers usually prefer? --> here we can see that the most commoon number of installments is 1, nearly 80% of the orders were made for installments options in and under 4 months and more than 50% of revenue was made with payments made in installments in and under 3 months - so we can infer that customers don't explicitely prefer credit cards for the option of installments but for someother reason as the distribution of installments is more skewed towards 1 installment than the distribution of payment types is skewed towards credit cards. This also indicates that customers prefer to pay in full rather than in installments, which could be due to factors such as avoiding interest charges or simply preferring to complete their payment in one transaction. However, it's worth noting that a significant portion of customers do choose to pay in installments, which suggests that offering this option can be beneficial for attracting and retaining customers who may prefer this payment method.
SELECT payment_installments, count(order_id) as no_of_payments, ROUND((COUNT(order_id)*100/(SELECT COUNT(order_id) FROM order_payments)), 2) as percentage_share_of_installments, ROUND((SUM(payment_value)*100/(SELECT SUM(payment_value) FROM order_payments)), 2) as percentage_share_of_revenue_from_installments, ROUND(SUM((COUNT(order_id)*100/(SELECT COUNT(order_id) FROM order_payments)))OVER (ORDER BY payment_installments),2) AS cumulative_percentage_of_revenue_from_installments
FROM order_payments GROUP BY payment_installments ORDER BY no_of_payments DESC;
-- How many installments do customers usually prefer (product_category_wise)? --> nothing significant can be inferred from this analysis as the distribution excpet for some more expensive categories having a bit larger average installment 
SELECT pt.product_category_name_english AS product_category,ROUND(AVG(op.payment_installments), 2) AS avg_installments
FROM order_items o
JOIN (SELECT order_id, AVG(payment_installments) as payment_installments FROM order_payments GROUP BY order_id ) AS op ON o.order_id = op.order_id -- we use the subquery here for average_installments as without it the query took almost 1m 30s to execute and with it the query took almost 5s.
JOIN products p ON o.product_id = p.product_id
JOIN product_category_translation pt ON p.product_category_name = pt.product_category_name
GROUP BY 1
ORDER BY 2 DESC;
-- ======================================================================
-- "sellers" analysis --> here we've found out our top sellers by their ids and have also discovered that the revenue distribution by seller is highly fragmented and hence olist has democratised the e-commerce market and is sitting on low risk due to not having most of it's GMV by only a small chunk of sellers (pareto distributed). we've also found out that sellers with an average review score in the range of 1-2.5 mostly have net_orders in a single digit and net revenue is also low and the top sellers mostly have their average rating greater than 3.5, there are also a lot of outliers in the data.
SELECT seller_id, ROUND(AVG(r.review_score),2) as Average_Score, COUNT(r.review_id) as review_count, SUM(o.price) as Net_Revenue_by_seller, count(o.order_id) as net_orders, ROUND((sum(o.price)/count(o.order_id)), 2) as Avg_order_value, ROUND((count(o.order_id)*100/(SELECT DISTINCT COUNT(order_id) FROM order_items)), 2) as percentage_of_total_orders, ROUND((sum(o.price)*100/(SELECT SUM(price) FROM order_items)), 2) as percentage_of_total_revenue, SUM(ROUND((sum(o.price)*100/(SELECT SUM(price) FROM order_items)), 2)) OVER (ORDER BY SUM(price) DESC) AS cumulative_revenue_percentage
FROM order_items o
JOIN order_reviews r  ON r.order_id = o.order_id
GROUP BY o.seller_id
ORDER BY 9 ASC;
