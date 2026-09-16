-- ============================================================================
-- 03_cohort_retention_analysis.sql
-- Month-over-Month Cohort Retention Matrix
-- Measures customer lifecycle durability and repeat purchase rates
-- ============================================================================

WITH customer_first_purchase AS (
    -- Determine the first purchase month for each customer
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE AS cohort_month
    FROM orders
    WHERE order_status NOT IN ('cancelled')
    GROUP BY customer_id
),
customer_activities AS (
    -- Map each subsequent purchase back to the acquisition cohort
    SELECT 
        o.customer_id,
        fp.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE AS order_month,
        -- Calculate the monthly index (0 = cohort acquisition month)
        (
            (DATE_PART('year', o.order_date) - DATE_PART('year', fp.cohort_month)) * 12 +
            (DATE_PART('month', o.order_date) - DATE_PART('month', fp.cohort_month))
        )::INT AS month_number
    FROM orders o
    JOIN customer_first_purchase fp ON o.customer_id = fp.customer_id
    WHERE o.order_status NOT IN ('cancelled')
),
cohort_sizes AS (
    -- Total distinct customers who made their first order in each cohort month
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),
retention_counts AS (
    -- Count of unique active customers for each cohort and month index
    SELECT 
        ca.cohort_month,
        cs.cohort_size,
        ca.month_number,
        COUNT(DISTINCT ca.customer_id) AS active_users
    FROM customer_activities ca
    JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
    GROUP BY ca.cohort_month, cs.cohort_size, ca.month_number
)
-- Display Retention Matrix (Month 0 to Month 6)
SELECT 
    TO_CHAR(rc.cohort_month, 'YYYY-MM') AS cohort,
    rc.cohort_size,
    -- Month 0 (Always 100%)
    MAX(CASE WHEN rc.month_number = 0 THEN rc.active_users END) AS m0_users,
    -- Retention Percentages
    ROUND((MAX(CASE WHEN rc.month_number = 1 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m1_retention,
    ROUND((MAX(CASE WHEN rc.month_number = 2 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m2_retention,
    ROUND((MAX(CASE WHEN rc.month_number = 3 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m3_retention,
    ROUND((MAX(CASE WHEN rc.month_number = 4 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m4_retention,
    ROUND((MAX(CASE WHEN rc.month_number = 5 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m5_retention,
    ROUND((MAX(CASE WHEN rc.month_number = 6 THEN rc.active_users ELSE 0 END)::NUMERIC / rc.cohort_size) * 100, 1) || '%' AS m6_retention
FROM retention_counts rc
GROUP BY rc.cohort_month, rc.cohort_size
ORDER BY rc.cohort_month ASC;
