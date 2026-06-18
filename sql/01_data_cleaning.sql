/*
===========================================================
 Project      : Superstore Sales Analysis
 File         : 01_data_cleaning.sql
 Author       : Alona Oleksiienko
 Description  : Data cleaning and validation process for
                Superstore dataset before analysis.

 Dataset      : Sample Superstore
 Rows         : 9,994
 Columns      : 21
===========================================================
*/


/*
===========================================================
STEP 1. CREATE BACKUP TABLE
===========================================================

Purpose:
Create a copy of the original dataset to preserve raw data.
All transformations will be performed on the copied table.
*/


DROP TABLE IF EXISTS public.superstore_raw;

CREATE TABLE public.superstore_raw AS
SELECT *
FROM public.superstore;


/*
===========================================================
STEP 2. CHECKING THE TABLE STRUCTURE
===========================================================

Purpose: Check column data types before cleaning.
*/


SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE LOWER(table_name) = 'superstore_raw';


/*
===========================================================
STEP 3. INITIAL DATA INSPECTION
===========================================================

Purpose: Check dataset size before cleaning.
Expected result: 9994 rows
*/


SELECT COUNT(*) AS total_rows
FROM public.superstore_raw;


/*
===========================================================
STEP 4. CHECK FOR MISSING VALUES
===========================================================

Purpose: Validate business-critical columns.
Expected result: 0 missing values.
*/


SELECT
	SUM(CASE WHEN "Order ID" IS NULL THEN 1 ELSE 0 END) AS order_id_nulls,
	SUM(CASE WHEN "Order Date" IS NULL THEN 1 ELSE 0 END) AS order_date_nulls,
	SUM(CASE WHEN "Customer ID" IS NULL THEN 1 ELSE 0 END) AS customer_id_nulls,
	SUM(CASE WHEN "Product ID" IS NULL THEN 1 ELSE 0 END) AS product_id_nulls,
	SUM(CASE WHEN "Sales" IS NULL THEN 1 ELSE 0 END) AS sales_nulls,
	SUM(CASE WHEN "Quantity" IS NULL THEN 1 ELSE 0 END) AS quantity_nulls,
	SUM(CASE WHEN "Profit" IS NULL THEN 1 ELSE 0 END) AS profit_nulls
FROM public.superstore_raw;


/*
===========================================================
STEP 5. CHECK FOR FULL DUPLICATE RECORDS
===========================================================

Purpose: Identify fully duplicated records in the dataset.
Expected result: 0 duplicate rows.
*/


WITH duplicate_check AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                "Row ID",
                "Order ID",
                "Order Date",
                "Ship Date",
                "Ship Mode",
                "Customer ID",
                "Customer Name",
                "Segment",
                "Country",
                "City",
                "State",
                "Postal Code",
                "Region",
                "Product ID",
                "Category",
                "Sub-Category",
                "Product Name",
                "Sales",
                "Quantity",
                "Discount",
                "Profit"
            ORDER BY "Row ID"
        ) AS rn
    FROM public.superstore_raw
)

SELECT COUNT(*) AS duplicate_rows
FROM duplicate_check
WHERE rn > 1;


/*
===========================================================
STEP 6. CREATE CLEAN TABLE
===========================================================

Purpose: Standardize column names using snake_case convention.
*/


DROP TABLE IF EXISTS public.superstore_clean;

CREATE TABLE public.superstore_clean AS
SELECT
    "Row ID" AS row_id,
    "Order ID" AS order_id,
    "Order Date" AS order_date,
    "Ship Date" AS ship_date,
    "Ship Mode" AS ship_mode,
    "Customer ID" AS customer_id,
    "Customer Name" AS customer_name,
    "Segment" AS segment,
    "Country" AS country,
    "City" AS city,
    "State" AS state,
    "Postal Code" AS postal_code,
    "Region" AS region,
    "Product ID" AS product_id,
    "Category" AS category,
    "Sub-Category" AS sub_category,
    "Product Name" AS product_name,
    "Sales" AS sales,
    "Quantity" AS quantity,
    "Discount" AS discount,
    "Profit" AS profit
FROM public.superstore_raw;

-- checking uniqueness of row_id
SELECT
    row_id,
    COUNT(*) AS duplicate_count
FROM public.superstore_clean
GROUP BY row_id
HAVING COUNT(*) > 1;

-- adding primary key to the table superstore_clean
ALTER TABLE public.superstore_clean
ADD PRIMARY KEY (row_id);

/*
===========================================================
STEP 7. CONVERT DATE COLUMNS
===========================================================

Purpose: Transform text-based dates into PostgreSQL DATE format.
*/


SELECT order_date, ship_date
FROM public.superstore_clean
LIMIT 5;

ALTER TABLE public.superstore_clean
ALTER COLUMN order_date
TYPE DATE
USING TO_DATE(order_date,'MM/DD/YYYY');

ALTER TABLE public.superstore_clean
ALTER COLUMN ship_date
TYPE DATE
USING TO_DATE(ship_date,'MM/DD/YYYY');


/*
===========================================================
STEP 8. STANDARDIZE DATA TYPES OF VALUES
===========================================================

Purpose: Replacing data types with the appropriate data types 
         according to SQL best practice.
*/


ALTER TABLE public.superstore_clean
ALTER COLUMN sales TYPE DECIMAL(12,2);

ALTER TABLE public.superstore_clean
ALTER COLUMN profit TYPE DECIMAL(12,2);

ALTER TABLE public.superstore_clean
ALTER COLUMN discount TYPE DECIMAL(4,2);

ALTER TABLE public.superstore_clean
ALTER COLUMN postal_code
TYPE VARCHAR(10);


/*
===========================================================
STEP 9. FIX CHARACTER ENCODING ISSUES
===========================================================

Purpose: Replace corrupted Unicode replacement characters
         with spaces and normalize text formatting.
         
===========================================================
*/

-- product_name
UPDATE public.superstore_clean
SET product_name = REPLACE(product_name, '�', ' ')
WHERE product_name LIKE '%�%';

UPDATE public.superstore_clean
SET product_name = REGEXP_REPLACE(
    product_name,
    '\s+',
    ' ',
    'g'
);

UPDATE public.superstore_clean
SET product_name = TRIM(product_name);


-- customer_name
SELECT
    customer_name,
    COUNT(*) AS records_count
FROM public.superstore_clean
WHERE customer_name LIKE '%�%'
GROUP BY customer_name
ORDER BY records_count DESC;

UPDATE public.superstore_clean
SET customer_name = 'Peter Bühler'
WHERE customer_name = 'Peter B�hler';

UPDATE public.superstore_clean
SET customer_name = 'Anna Häberlin'
WHERE customer_name = 'Anna H�berlin';

UPDATE public.superstore_clean
SET customer_name = 'Resi Pülking'
WHERE customer_name = 'Resi P�lking';

UPDATE public.superstore_clean
SET customer_name = 'Barry Französisch'
WHERE customer_name = 'Barry Franz�sisch';

UPDATE public.superstore_clean
SET customer_name = 'Roy Französisch'
WHERE customer_name = 'Roy Franz�sisch';

UPDATE public.superstore_clean
SET customer_name = 'Neil Französisch'
WHERE customer_name = 'Neil Franz�sisch';


/*
===========================================================
STEP 10. VALIDATE DATE LOGIC
===========================================================

Business Rule: Ship Date cannot be earlier than Order Date.
Expected result: 0 rows.
*/


SELECT *
FROM public.superstore_clean
WHERE ship_date < order_date;


/*
===========================================================
STEP 11. VALIDATE SALES VALUES
===========================================================

Business Rule: Sales cannot be negative.
Expected result: 0 rows.
*/


SELECT *
FROM public.superstore_clean
WHERE sales < 0;


/*
===========================================================
STEP 12. VALIDATE QUANTITY VALUES
===========================================================

Business Rule: Quantity must be greater than zero.

Expected result: 0 rows.
*/


SELECT *
FROM public.superstore_clean
WHERE quantity <= 0;


/*
===========================================================
STEP 13. VALIDATE DISCOUNT VALUES
===========================================================

Purpose: Check all available discount levels.
*/


SELECT DISTINCT discount
FROM public.superstore_clean
ORDER BY discount;


/*
===========================================================
STEP 14. CHECKING BUSINESS RANGES
===========================================================

Purpose: Validate numerical ranges and identify potential outliers.
*/


SELECT
    MIN(sales) AS min_sales,
    MAX(sales) AS max_sales,
    MIN(profit) AS min_profit,
    MAX(profit) AS max_profit
FROM public.superstore_clean;


/*
===========================================================
STEP 14.1 ANALYZE NEGATIVE PROFITS
===========================================================

Business Rule: Negative profit values are allowed and indicate
               loss-making transactions.
Purpose: Identify unprofitable sales for future analysis.
*/

SELECT *
FROM public.superstore_clean
WHERE profit < 0;


/*
===========================================================
STEP 15. THE TIME PERIOD OF THE DATASET
===========================================================
*/


SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM public.superstore_clean;


/*
===========================================================
FINAL DATA QUALITY SUMMARY
===========================================================

Expected Results

Rows Before Cleaning : 9994
Rows After Cleaning  : 9994

Missing Values       : 0
Duplicate Rows       : 0
Invalid Dates        : 0
Negative Sales       : 0
Invalid Quantity     : 0

Transformations Applied:
✓ Column names standardized
✓ Date columns converted
✓ Postal code converted to text
✓ Business rules validated
===========================================================
*/

SELECT COUNT(*) AS cleaned_rows
FROM superstore_clean;

SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT product_id) AS total_products
FROM public.superstore_clean;