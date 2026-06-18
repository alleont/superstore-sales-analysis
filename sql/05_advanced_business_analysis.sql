/*
===========================================================
Project     : Superstore Sales Analysis
File        : 05_advanced_business_analysis.sql
Author      : Alona Oleksiienko
Database    : PostgreSQL

Description:
Advanced business analysis and profitability insights.

Objectives:
- Analyze discount impact
- Identify profit drivers
- Detect loss-making areas
- Evaluate shipping performance
- Analyze regional profitability
- Build profitability matrix
===========================================================
*/


/*
===========================================================
DISCOUNT IMPACT ON PROFITABILITY
===========================================================
*/

SELECT
    discount,
    COUNT(*) AS orders_count,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit,
    ROUND(AVG(profit),2) AS avg_profit
FROM public.superstore_clean
GROUP BY discount
ORDER BY discount;


/*
===========================================================
DISCOUNT SEGMENTATION
===========================================================
*/

SELECT

    CASE
        WHEN discount = 0
            THEN 'No Discount'

        WHEN discount <= 0.20
            THEN 'Low Discount'

        WHEN discount <= 0.50
            THEN 'Medium Discount'

        ELSE 'High Discount'
    END AS discount_group,

    COUNT(*) AS orders_count,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit

FROM public.superstore_clean
GROUP BY discount_group
ORDER BY total_sales DESC;


/*
===========================================================
LOSS-MAKING ORDERS
===========================================================
*/

SELECT
    order_id,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit
FROM public.superstore_clean
GROUP BY order_id
HAVING SUM(profit) < 0
ORDER BY total_profit;


/*
===========================================================
TOP 10 MOST UNPROFITABLE ORDERS
===========================================================
*/

SELECT
    order_id,
    ROUND(SUM(sales),2) AS total_sales,
    ROUND(SUM(profit),2) AS total_profit
FROM public.superstore_clean
GROUP BY order_id
ORDER BY total_profit
LIMIT 10;


/*
===========================================================
REGIONAL PROFITABILITY
===========================================================
*/

SELECT
    region,

    ROUND(SUM(sales),2) AS total_sales,

    ROUND(SUM(profit),2) AS total_profit,

    ROUND(
        SUM(profit) /
        NULLIF(SUM(sales),0) * 100,
        2
    ) AS profit_margin_pct

FROM public.superstore_clean
GROUP BY region
ORDER BY profit_margin_pct DESC;


/*
===========================================================
STATE PROFITABILITY
===========================================================
*/

SELECT
    state,

    ROUND(SUM(sales),2) AS total_sales,

    ROUND(SUM(profit),2) AS total_profit,

    ROUND(
        SUM(profit) /
        NULLIF(SUM(sales),0) * 100,
        2
    ) AS profit_margin_pct

FROM public.superstore_clean
GROUP BY state
ORDER BY total_profit DESC;


/*
===========================================================
SHIPPING PERFORMANCE
===========================================================
*/

SELECT
    ship_mode,

    COUNT(*) AS orders_count,

    ROUND(SUM(sales),2) AS total_sales,

    ROUND(SUM(profit),2) AS total_profit,

    ROUND(
        AVG(ship_date - order_date),
        2
    ) AS avg_shipping_days

FROM public.superstore_clean
GROUP BY ship_mode
ORDER BY total_sales DESC;


/*
===========================================================
PRODUCT PROFITABILITY MATRIX
===========================================================
*/

WITH product_metrics AS
(
    SELECT
        product_name,

        SUM(sales) AS total_sales,

        SUM(profit) AS total_profit

    FROM public.superstore_clean
    GROUP BY product_name
),

avg_values AS
(
    SELECT
        AVG(total_sales) AS avg_sales,
        AVG(total_profit) AS avg_profit
    FROM product_metrics
)

SELECT

    product_name,

    ROUND(total_sales,2) AS total_sales,

    ROUND(total_profit,2) AS total_profit,

    CASE

        WHEN total_sales >= avg_sales
         AND total_profit >= avg_profit
            THEN 'High Sales / High Profit'

        WHEN total_sales >= avg_sales
         AND total_profit < avg_profit
            THEN 'High Sales / Low Profit'

        WHEN total_sales < avg_sales
         AND total_profit >= avg_profit
            THEN 'Low Sales / High Profit'

        ELSE 'Low Sales / Low Profit'

    END AS profitability_segment

FROM product_metrics
CROSS JOIN avg_values;


/*
===========================================================
CATEGORY PERFORMANCE VS DISCOUNT
===========================================================
*/

SELECT
    category,

    ROUND(AVG(discount),2) AS avg_discount,

    ROUND(SUM(sales),2) AS total_sales,

    ROUND(SUM(profit),2) AS total_profit

FROM public.superstore_clean
GROUP BY category
ORDER BY total_profit DESC;


/*
===========================================================
HIGH DISCOUNT PRODUCTS
===========================================================
*/

SELECT
    product_name,

    ROUND(AVG(discount),2) AS avg_discount,

    ROUND(SUM(profit),2) AS total_profit

FROM public.superstore_clean
GROUP BY product_name
HAVING AVG(discount) >= 0.30
ORDER BY avg_discount DESC;
