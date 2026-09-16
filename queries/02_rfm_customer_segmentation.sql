-- ============================================================================
-- 02_rfm_customer_segmentation.sql
-- Customer Segmentation using Recency, Frequency, and Monetary (RFM) Modeling
-- Implements NTILE quintiles and business segmentation classification
-- ============================================================================

WITH reference_date AS (
    -- Anchor to the latest order timestamp in the dataset
    SELECT MAX(order_date) AS max_order_date FROM orders
),
customer_rfm_raw AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.acquisition_channel,
        -- Recency: Days between customer's latest order and benchmark date
        DATE_PART('day', (SELECT max_order_date FROM reference_date) - MAX(o.order_date)) AS recency_days,
        -- Frequency: Count of non-cancelled orders
        COUNT(DISTINCT o.order_id) AS frequency,
        -- Monetary: Total spend across all orders
        ROUND(COALESCE(SUM(o.total_amount), 0), 2) AS monetary_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('cancelled')
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.acquisition_channel
),
customer_scores AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        acquisition_channel,
        recency_days,
        frequency,
        monetary_value,
        -- Lower recency days = higher score (5 is best)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        -- Higher frequency = higher score (5 is best)
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        -- Higher spend = higher score (5 is best)
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM customer_rfm_raw
),
customer_segments AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        acquisition_channel,
        recency_days,
        frequency,
        monetary_value,
        r_score,
        f_score,
        m_score,
        CONCAT(r_score, f_score, m_score) AS rfm_combined,
        ROUND((r_score + f_score + m_score) / 3.0, 2) AS rfm_avg,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score BETWEEN 1 AND 2 THEN 'Recent Promising'
            WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 4 THEN 'Big Spenders'
            WHEN r_score BETWEEN 2 AND 3 AND f_score >= 3 THEN 'Need Attention'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk Customers'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating High Value'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost Customers'
            ELSE 'Standard Buyers'
        END AS customer_segment
    FROM customer_scores
)
-- Segment Level Aggregates & Strategic Insights
SELECT 
    customer_segment,
    COUNT(customer_id) AS customer_count,
    ROUND((COUNT(customer_id)::NUMERIC / (SELECT COUNT(*) FROM customer_segments) * 100), 2) AS pct_of_customer_base,
    ROUND(AVG(recency_days)::numeric, 1) AS avg_recency_days,
    ROUND(AVG(frequency)::numeric, 2) AS avg_orders_per_customer,
    TO_CHAR(ROUND(AVG(monetary_value)::numeric, 2), '$FM999,990.00') AS avg_customer_spend,
    TO_CHAR(SUM(monetary_value), '$FM999,999,990.00') AS total_segment_revenue,
    ROUND((SUM(monetary_value) / (SELECT SUM(monetary_value) FROM customer_segments) * 100), 2) AS pct_of_total_revenue
FROM customer_segments
GROUP BY customer_segment
ORDER BY SUM(monetary_value) DESC;
