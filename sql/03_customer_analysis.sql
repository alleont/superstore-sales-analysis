/*
===========================================================
Project     : Superstore Sales Analysis
File        : 03_customer_analysis.sql
Author      : Alona Oleksiienko
Database    : PostgreSQL

Description:
Customer behavior and customer value analysis.

Objectives:
- Identify top customers
- Measure customer profitability
- Analyze customer segments
- Detect repeat customers
- Perform RFM analysis
- Rank customers by business value
===========================================================
*/

-- Total Customer Overview
SELECT
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(SUM(sales)::numeric, 2) AS total_sales,
    ROUND(SUM(profit)::numeric, 2) AS total_profit
FROM public.superstore_clean;


-- Top 10 Customers by Revenue
SELECT
	customer_id,
    customer_name,
    ROUND(SUM(sales), 2) AS total_sales
FROM public.superstore_clean
GROUP BY customer_id, customer_name
ORDER BY total_sales DESC
LIMIT 10;


-- Top 10 Customers by Profit
SELECT
	customer_id,
    customer_name,
    ROUND(SUM(profit), 2) AS total_profit
FROM public.superstore_clean
GROUP BY customer_id, customer_name
ORDER BY total_profit DESC
LIMIT 10;


-- Customer Revenue Ranking
WITH customer_sales AS
(
    SELECT
        customer_id,
        customer_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
)

SELECT
    customer_id,
    customer_name,
    ROUND(total_sales::numeric, 2) AS total_sales,
    RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
FROM customer_sales;


-- Repeat Customers
SELECT
    customer_id,
    customer_name,
    COUNT(DISTINCT order_id) AS total_orders
FROM public.superstore_clean
GROUP BY customer_id, customer_name
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY total_orders DESC;


-- Customer Segment Performance
SELECT
    segment,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(sales)::numeric, 2) AS total_sales,
    ROUND(SUM(profit)::numeric, 2) AS total_profit
FROM public.superstore_clean
GROUP BY segment
ORDER BY total_sales DESC;


-- Customer Lifetime Value (CLV Proxy)
SELECT
    customer_id,
    customer_name,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(sales)::numeric, 2) AS lifetime_sales,
    ROUND(SUM(profit)::numeric, 2) AS lifetime_profit
FROM public.superstore_clean
GROUP BY customer_id, customer_name
ORDER BY lifetime_sales DESC;


-- VIP / Regular / Low Value Customers
WITH customer_sales AS
(
    SELECT
        customer_id,
        customer_name,
        SUM(sales) AS total_sales
    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
)

SELECT
    customer_id,
    customer_name,
    ROUND(total_sales::numeric, 2) AS total_sales,

    CASE
        WHEN total_sales >= 10000 THEN 'VIP'
        WHEN total_sales >= 5000 THEN 'Regular'
        ELSE 'Low Value'
    END AS customer_segment

FROM customer_sales
ORDER BY total_sales DESC;


/*
===========================================================
RFM ANALYSIS - CUSTOMER METRICS
===========================================================
*/

WITH customer_rfm AS
(
    SELECT
        customer_id,
        customer_name,
        MAX(order_date) AS last_order_date,

        (
            SELECT MAX(order_date)
            FROM public.superstore_clean
        ) - MAX(order_date) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        ROUND(SUM(sales), 2) AS monetary

    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
)

SELECT *
FROM customer_rfm
ORDER BY monetary DESC;


/*
===========================================================
RFM SCORING
===========================================================
*/

WITH customer_rfm AS
(
    SELECT
        customer_id,
        customer_name,

        (
            SELECT MAX(order_date)
            FROM public.superstore_clean
        ) - MAX(order_date) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        SUM(sales) AS monetary

    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
),

rfm_scores AS
(
    SELECT

        customer_id,
        customer_name,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER(ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER(ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER(ORDER BY monetary DESC) AS m_score

    FROM customer_rfm
)

SELECT *
FROM rfm_scores;


/*
===========================================================
RFM CUSTOMER SEGMENTS
===========================================================
*/

WITH customer_rfm AS
(
    SELECT
        customer_id,
        customer_name,

        (
            SELECT MAX(order_date)
            FROM public.superstore_clean
        ) - MAX(order_date) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        SUM(sales) AS monetary

    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
),

rfm_scores AS
(
    SELECT

        customer_id,
        customer_name,

        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score

    FROM customer_rfm
)

SELECT

    customer_id,
    customer_name,

    recency_days,
    frequency,
    ROUND(monetary::numeric,2) AS monetary,

    r_score,
    f_score,
    m_score,

    CASE

        WHEN r_score = 5
         AND f_score >= 4
         AND m_score >= 4
        THEN 'Champions'

        WHEN r_score >= 4
         AND f_score >= 3
        THEN 'Loyal Customers'

        WHEN r_score >= 4
         AND f_score <= 2
        THEN 'Potential Loyalists'

        WHEN r_score <= 2
         AND f_score >= 3
        THEN 'At Risk'

        ELSE 'Others'

    END AS customer_segment

FROM rfm_scores
ORDER BY monetary DESC;


/*
===========================================================
RFM SEGMENT SUMMARY
===========================================================
*/

WITH customer_rfm AS
(
    SELECT
        customer_id,
        customer_name,

        (
            SELECT MAX(order_date)
            FROM public.superstore_clean
        ) - MAX(order_date) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        SUM(sales) AS monetary

    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
),

rfm_scores AS
(
    SELECT

        customer_id,
        customer_name,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score

    FROM customer_rfm
),

rfm_segments AS
(
    SELECT

        customer_id,
        customer_name,

        recency_days,
        frequency,
        monetary,

        r_score,
        f_score,
        m_score,

        CASE

            WHEN r_score = 5
             AND f_score >= 4
             AND m_score >= 4
            THEN 'Champions'

            WHEN r_score >= 4
             AND f_score >= 3
            THEN 'Loyal Customers'

            WHEN r_score >= 4
             AND f_score <= 2
            THEN 'Potential Loyalists'

            WHEN r_score <= 2
             AND f_score >= 3
            THEN 'At Risk'

            ELSE 'Others'

        END AS customer_segment

    FROM rfm_scores
)

SELECT
    customer_segment,
    COUNT(*) AS customers_count,
    ROUND(SUM(monetary)::numeric, 2) AS total_sales,
    ROUND(AVG(monetary)::numeric, 2) AS avg_customer_sales
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_sales DESC;


/*
===========================================================
TOP CUSTOMERS IN EACH RFM SEGMENT
===========================================================
*/

WITH customer_rfm AS
(
    SELECT
        customer_id,
        customer_name,

        (
            SELECT MAX(order_date)
            FROM public.superstore_clean
        ) - MAX(order_date) AS recency_days,

        COUNT(DISTINCT order_id) AS frequency,

        SUM(sales) AS monetary

    FROM public.superstore_clean
    GROUP BY customer_id, customer_name
),

rfm_scores AS
(
    SELECT
        customer_id,
        customer_name,
        recency_days,
        frequency,
        monetary,

        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score

    FROM customer_rfm
),

rfm_segments AS
(
    SELECT
        *,
        CASE
            WHEN r_score = 5
             AND f_score >= 4
             AND m_score >= 4
            THEN 'Champions'

            WHEN r_score >= 4
             AND f_score >= 3
            THEN 'Loyal Customers'

            WHEN r_score >= 4
             AND f_score <= 2
            THEN 'Potential Loyalists'

            WHEN r_score <= 2
             AND f_score >= 3
            THEN 'At Risk'

            ELSE 'Others'
        END AS customer_segment
    FROM rfm_scores
)

SELECT
    customer_segment,
    customer_name,
    ROUND(monetary::numeric, 2) AS total_sales,
    RANK() OVER (PARTITION BY customer_segment ORDER BY monetary DESC) AS segment_rank
FROM rfm_segments
ORDER BY customer_segment, segment_rank;