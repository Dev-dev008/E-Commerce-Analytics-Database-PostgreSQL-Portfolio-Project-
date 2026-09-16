-- ============================================================================
-- 06_payment_and_returns.sql
-- Payment Gateway Health, Refund Leakage, and Review Correlation
-- Analyzes payment method reliability, returns, and customer satisfaction
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Payment Gateway Method Distribution & Success Rates
-- ----------------------------------------------------------------------------
SELECT 
    payment_method,
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN payment_status = 'completed' THEN 1 END) AS successful_payments,
    COUNT(CASE WHEN payment_status = 'refunded' THEN 1 END) AS refunded_payments,
    COUNT(CASE WHEN payment_status = 'failed' THEN 1 END) AS failed_payments,
    ROUND(
        (COUNT(CASE WHEN payment_status = 'completed' THEN 1 END)::NUMERIC / COUNT(*) * 100), 
        2
    ) || '%' AS gateway_success_rate,
    TO_CHAR(SUM(amount), '$FM999,999,990.00') AS total_processed_volume,
    TO_CHAR(
        SUM(CASE WHEN payment_status = 'refunded' THEN amount ELSE 0 END), 
        '$FM999,999,990.00'
    ) AS total_refund_leakage
FROM payments
GROUP BY payment_method
ORDER BY total_transactions DESC;

-- ----------------------------------------------------------------------------
-- 2. Product Rating vs Return Rate Correlation
-- ----------------------------------------------------------------------------
WITH product_ratings AS (
    SELECT 
        product_id,
        COUNT(review_id) AS review_count,
        ROUND(AVG(rating), 2) AS avg_star_rating
    FROM reviews
    GROUP BY product_id
),
product_orders AS (
    SELECT 
        oi.product_id,
        COUNT(DISTINCT o.order_id) AS total_orders_containing_product,
        COUNT(DISTINCT CASE WHEN o.order_status = 'returned' THEN o.order_id END) AS returned_orders_count
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    GROUP BY oi.product_id
)
SELECT 
    p.product_name,
    c.category_name,
    po.total_orders_containing_product,
    po.returned_orders_count,
    ROUND(
        (po.returned_orders_count::NUMERIC / NULLIF(po.total_orders_containing_product, 0) * 100), 
        2
    ) || '%' AS return_rate_pct,
    COALESCE(pr.review_count, 0) AS total_reviews,
    COALESCE(pr.avg_star_rating, 0.0) AS avg_rating,
    CASE 
        WHEN COALESCE(pr.avg_star_rating, 0) >= 4.2 THEN '⭐ Highly Rated'
        WHEN COALESCE(pr.avg_star_rating, 0) >= 3.5 THEN '👍 Satisfactory'
        ELSE '⚠️ Quality Investigation Warranted'
    END AS satisfaction_flag
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN product_orders po ON p.product_id = po.product_id
LEFT JOIN product_ratings pr ON p.product_id = pr.product_id
WHERE po.total_orders_containing_product >= 15
ORDER BY (po.returned_orders_count::NUMERIC / NULLIF(po.total_orders_containing_product, 0)) DESC
LIMIT 15;
