/*
===========================================================
Project     : Superstore Sales Analysis
File        : 04_product_analysis.sql
Author      : Alona Oleksiienko
Database    : PostgreSQL

Description:
Product performance analysis.

Objectives:
- Identify top-performing products
- Analyze product profitability
- Detect loss-making products
- Perform ABC analysis
- Perform Pareto analysis
- Analyze category and subcategory performance
===========================================================
*/


-- Product Overview
SELECT
    COUNT(DISTINCT product_id) AS total_products,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean;


-- Top 10 Products by Revenue
SELECT
    product_id,
    product_name,
    ROUND(SUM(sales), 2) AS total_sales
FROM public.superstore_clean
GROUP BY product_id, product_name
ORDER BY total_sales DESC
LIMIT 10;


-- Top 10 Products by Profit
SELECT
    product_id,
    product_name,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY product_id, product_name
ORDER BY total_profit DESC
LIMIT 10;


-- TOP-10 Loss-Making Products
SELECT
    product_id,
    product_name,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY product_id, product_name
HAVING SUM(profit) < 0
ORDER BY total_profit
LIMIT 10;


-- Category Performance
SELECT
    category,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        SUM(profit) /
        NULLIF(SUM(sales),0) * 100,
        2
    ) AS profit_margin_pct
FROM public.superstore_clean
GROUP BY category
ORDER BY total_sales DESC;


-- Subcategory Performance
SELECT
    sub_category,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY sub_category
ORDER BY total_sales DESC;


-- Product Ranking
WITH product_sales AS
(
    SELECT
        product_id,
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_id, product_name
)

SELECT
    product_id,
    product_name,
    ROUND(total_sales, 2) AS total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
FROM product_sales;


-- Top Product in Each Category
WITH category_products AS
(
    SELECT
        category,
        product_name,
        SUM(sales) AS total_sales,
        ROW_NUMBER() OVER(PARTITION BY category ORDER BY SUM(sales) DESC) AS rn

    FROM public.superstore_clean
    GROUP BY category, product_name
)

SELECT
    category,
    product_name,
    ROUND(total_sales, 2) AS total_sales
FROM category_products
WHERE rn = 1;


-- Products Above Average Sales
WITH product_sales AS
(
    SELECT
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_name
),

overall_avg AS
(
    SELECT
        AVG(total_sales) AS avg_sales
    FROM product_sales
)

SELECT
    product_name,
    ROUND(total_sales, 2) AS total_sales
FROM product_sales
WHERE total_sales >
(
    SELECT avg_sales
    FROM overall_avg
)
ORDER BY total_sales DESC;


/*
===========================================================
ABC ANALYSIS OF PRODUCTS
===========================================================
Purpose:
Classify products into A, B and C categories
based on cumulative sales contribution.
===========================================================
*/


WITH product_sales AS (
    SELECT
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_name
),

sales_ranking AS (
    SELECT
        product_name,
        total_sales,
        SUM(total_sales) OVER (ORDER BY total_sales DESC) AS cumulative_sales,
        SUM(total_sales) OVER () AS overall_sales
    FROM product_sales
),

abc_classification AS (
    SELECT
        product_name,
        total_sales,
        CASE
            WHEN cumulative_sales / overall_sales <= 0.80 THEN 'A'
            WHEN cumulative_sales / overall_sales <= 0.95 THEN 'B'
            ELSE 'C'
        END AS abc_category
    FROM sales_ranking
)

SELECT
    abc_category,
    COUNT(*) AS products_count,
    ROUND(SUM(total_sales)::numeric,2) AS total_sales
FROM abc_classification
GROUP BY abc_category
ORDER BY abc_category;


/*
===========================================================
PARETO ANALYSIS (80/20 RULE)
===========================================================

Purpose:
Identify products that contribute to 80% of total sales.

Business Question:
What percentage of products generates 80%
of total company revenue?

===========================================================
*/

WITH product_sales AS
(
    SELECT
        product_id,
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_id, product_name
),

pareto_analysis AS
(
    SELECT
        product_id,
        product_name,
        total_sales,

        SUM(total_sales) OVER
        (
            ORDER BY total_sales DESC
        ) AS cumulative_sales,

        SUM(total_sales) OVER () AS overall_sales

    FROM product_sales
)

SELECT
    product_id,
    product_name,
    ROUND(total_sales, 2) AS total_sales,

    ROUND(
        cumulative_sales /
        overall_sales * 100,
        2
    ) AS cumulative_sales_pct

FROM pareto_analysis
ORDER BY total_sales DESC;


/*
===========================================================
PARETO SUMMARY
===========================================================
*/

WITH product_sales AS
(
    SELECT
        product_id,
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_id, product_name
),

pareto_analysis AS
(
    SELECT
        product_id,
        product_name,
        total_sales,

        SUM(total_sales) OVER
        (
            ORDER BY total_sales DESC
        ) AS cumulative_sales,

        SUM(total_sales) OVER () AS overall_sales

    FROM product_sales
),

pareto_flag AS
(
    SELECT
        *,
        cumulative_sales / overall_sales AS cumulative_pct
    FROM pareto_analysis
)

SELECT
    COUNT(*) AS products_generating_80pct_sales
FROM pareto_flag
WHERE cumulative_pct <= 0.80;


/*
===========================================================
PARETO SEGMENTATION
===========================================================
*/

WITH product_sales AS
(
    SELECT
        product_id,
        product_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY product_id, product_name
),

pareto_analysis AS
(
    SELECT
        product_id,
        product_name,
        total_sales,

        SUM(total_sales) OVER
        (
            ORDER BY total_sales DESC
        ) AS cumulative_sales,

        SUM(total_sales) OVER () AS overall_sales

    FROM product_sales
)

SELECT

    CASE
        WHEN cumulative_sales / overall_sales <= 0.80
            THEN 'Top 80% Revenue Products'
        ELSE 'Remaining Products'
    END AS pareto_group,

    COUNT(*) AS products_count,

    ROUND(
        SUM(total_sales),
        2
    ) AS total_sales

FROM pareto_analysis
GROUP BY pareto_group;