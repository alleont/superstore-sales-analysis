/*
===========================================================
Project      : Superstore Sales Analysis
File         : 02_exploratory_data_analysis.sql
Author       : Alona Oleksiienko
Database     : PostgreSQL

Description:
Exploratory data analysis of Superstore sales dataset.

Objectives:
- Understand overall business performance
- Identify key sales drivers
- Analyze customer behavior
- Analyze product performance
- Identify profit opportunities
===========================================================
*/


/*
===========================================================
BUSINESS OVERVIEW
===========================================================
*/

SELECT
    ROUND(SUM(sales)::numeric, 2) AS total_sales,
    ROUND(SUM(profit)::numeric, 2) AS total_profit,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT product_id) AS total_products,
    ROUND((SUM(profit) / NULLIF(SUM(sales),0) * 100)::numeric, 2) AS profit_margin_pct
FROM public.superstore_clean;


/*
===========================================================
AVERAGE ORDER VALUE
===========================================================
*/

SELECT
    ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS average_order_value
FROM public.superstore_clean;


/*
===========================================================
SALES BY CATEGORY/SUBCATEGORY
===========================================================
*/

SELECT
    category,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY category
ORDER BY total_sales DESC;


SELECT
    sub_category,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY sub_category
ORDER BY total_sales DESC;


/*
===========================================================
GEOGRAPHIC ANALYSIS
===========================================================
*/

-- Region Performance Analysis
SELECT
    region,
    ROUND(SUM(sales), 2) AS sales,
    ROUND(SUM(profit), 2) AS profit,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM public.superstore_clean
GROUP BY region
ORDER BY profit_margin_pct DESC;

-- Top 10 States by Sales
SELECT
    state,
    ROUND(SUM(sales), 2) AS total_sales
FROM public.superstore_clean
GROUP BY state
ORDER BY total_sales DESC
LIMIT 10;

-- Top 10 States by Profit
SELECT
    state,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY state
ORDER BY total_profit DESC
LIMIT 10;


-- Loss-Making States
SELECT
    state,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit
FROM public.superstore_clean
GROUP BY state
HAVING SUM(profit) < 0
ORDER BY total_profit;


/*
===========================================================
TIME SERIES ANALYSIS
===========================================================
*/

-- Sales Trend by Year
SELECT
    EXTRACT(YEAR FROM order_date) AS year,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY year
ORDER BY year;

-- Monthly Sales Trend
SELECT
    DATE_TRUNC('month', order_date)::date AS month,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY month
ORDER BY month;


-- YoY Growth
WITH yearly_sales AS (
    SELECT
        EXTRACT(YEAR FROM order_date) AS year,
        SUM(sales) AS sales
    FROM public.superstore_clean
    GROUP BY year
)

SELECT
    year,
    ROUND(sales::numeric,2) AS sales,
    ROUND((sales - LAG(sales) OVER(ORDER BY year))::numeric, 2) AS growth
FROM yearly_sales;


/*
===========================================================
SHIPMENT ANALYSIS
===========================================================
*/

SELECT
    ship_mode,
    COUNT(*) AS orders_count,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY ship_mode
ORDER BY total_sales DESC;


-- Average Shipping Days
SELECT
    ROUND(AVG(ship_date - order_date), 2) AS avg_shipping_days
FROM public.superstore_clean;
