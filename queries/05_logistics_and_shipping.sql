-- ============================================================================
-- 05_logistics_and_shipping.sql
-- Logistics Fulfillment SLA & Delivery Performance Analysis
-- Measures transit latency, SLA compliance, and regional distribution
-- ============================================================================

WITH delivery_metrics AS (
    SELECT 
        order_id,
        customer_id,
        shipping_city,
        shipping_state,
        shipping_fee,
        total_amount,
        order_date,
        delivery_date,
        -- Duration in fractional days
        EXTRACT(EPOCH FROM (delivery_date - order_date)) / 86400.0 AS transit_days
    FROM orders
    WHERE order_status = 'delivered' AND delivery_date IS NOT NULL
)
-- State-Level Delivery SLA Performance
SELECT 
    shipping_state,
    COUNT(order_id) AS total_deliveries,
    ROUND(AVG(transit_days), 2) AS avg_delivery_days,
    ROUND(MIN(transit_days), 1) AS fastest_delivery_days,
    ROUND(MAX(transit_days), 1) AS slowest_delivery_days,
    -- Median (50th percentile) and 90th percentile delivery duration
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY transit_days)::NUMERIC, 2) AS median_delivery_days,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY transit_days)::NUMERIC, 2) AS p90_delivery_days,
    -- Percentage delivered within 4-day SLA
    ROUND((COUNT(CASE WHEN transit_days <= 4.0 THEN 1 END)::NUMERIC / COUNT(order_id) * 100), 1) || '%' AS on_time_sla_pct,
    TO_CHAR(AVG(shipping_fee), '$FM990.00') AS avg_shipping_fee_collected
FROM delivery_metrics
GROUP BY shipping_state
HAVING COUNT(order_id) >= 20
ORDER BY avg_delivery_days ASC;

-- ----------------------------------------------------------------------------
-- Overall Logistics Pipeline Health Summary
-- ----------------------------------------------------------------------------
SELECT 
    order_status,
    COUNT(*) AS order_count,
    ROUND((COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM orders) * 100), 2) AS pct_of_total_orders,
    TO_CHAR(SUM(total_amount), '$FM999,999,990.00') AS total_pipeline_value
FROM orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;
