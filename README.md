# Olist E-commerce Data Analysis

## 📌 Project Overview
This project analyzes the [Olist Brazilian E-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) using SQL.  
The goal is to uncover insights into **customers, sellers, product categories, payments, and retention trends**.

The analysis focuses on:
- Customer behavior (unique customers, repeat purchases, retention & churn)
- Seller performance (revenue, orders, average order value)
- Product category performance (revenue, reviews, order value)
- Payment methods & installment usage
- Geographic distribution of sales

---

## 🗂 Dataset Description
The Olist dataset is a real-world Brazilian e-commerce dataset with the following key tables:
- `customers` → customer profiles
- `orders` → order details
- `order_items` → products included in each order
- `order_payments` → payment method and installment details
- `order_reviews` → customer review scores
- `products` → product details
- `sellers` → seller profiles
- `product_category_translation` → category names (Portuguese → English)

---

## ⚡ Key Business Questions
1. How many unique customers does Olist have?  
2. What is the repeat purchase rate?  
3. What does retention vs churn look like (cohort analysis)?  
4. Which cities generate the most sales?  
5. Which product categories generate the most revenue?  
6. What are the average review scores per category?  
7. What are the most common payment methods and installments used?  
8. Who are the top-performing sellers?  

---

## 📝 SQL Analysis
All SQL queries are available in [`sql/olist_ecommerce_analysis.sql`](./sql/olist_ecommerce_analysis.sql).  
The script is organized into sections with clear documentation.

---

## 📊 Key Insights
- **Customer Retention**: Only ~10–15% of customers make repeat purchases, highlighting churn challenges.  
- **Cohort Analysis**: Retention drops steeply after the first month, showing the need for loyalty programs.  
- **Top Cities**: São Paulo dominates sales, reflecting urban concentration of e-commerce.  
- **Product Categories**: High-ticket categories (e.g., furniture, appliances) have high average order values.  
- **Revenue Calculation**:  
  - Seller revenue = `SUM(price)`  
  - Customer spend = `SUM(price + freight_value)`  
- **Payments**: Credit card dominates, with many customers using installments.  
- **Sellers**: Revenue is unevenly distributed, with a small number of sellers capturing most sales.  

---

## 🚀 How to Run
1. Load the Olist dataset into MySQL.  
2. Run the script:
   ```sql
   SOURCE sql/olist_ecommerce_analysis.sql;
