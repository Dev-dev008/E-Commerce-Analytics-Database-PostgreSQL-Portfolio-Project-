-- ============================================================================
-- 08_data_quality_checks.sql
-- Automated Data Quality, Integrity & Domain Sanity Validation Suite
-- Database Engine: PostgreSQL 14+
-- ============================================================================
-- Purpose:
--   Validates warehouse data integrity prior to downstream BI reporting.
--   Enforces referential integrity, temporal sequence validity, financial sanity,
--   lifecycle state consistency, and duplicate detection.
--
-- How to run:
--   psql -U postgres -d ecommerce_analytics -f queries/08_data_quality_checks.sql
-- ============================================================================

\timing on

-- ----------------------------------------------------------------------------
-- CHECK 1: Referential Integrity (Orphan Record Auditing)
-- Description: Ensures all foreign keys resolve cleanly to existing parent rows.
-- ----------------------------------------------------------------------------
-- 1A: Orders without existing customer parent
SELECT 'Orders with missing customer' AS check_name, COUNT(*) AS violations
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 1B: Order items without parent order
SELECT 'Order items with missing order' AS check_name, COUNT(*) AS violations
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 1C: Order items referencing non-existent product
SELECT 'Order items with missing product' AS check_name, COUNT(*) AS violations
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 1D: Payments without parent order
SELECT 'Payments with missing order' AS check_name, COUNT(*) AS violations
FROM payments py
LEFT JOIN orders o ON py.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 1E: Reviews referencing non-existent product or customer
SELECT 'Reviews with missing foreign keys' AS check_name, COUNT(*) AS violations
FROM reviews r
LEFT JOIN customers c ON r.customer_id = c.customer_id
LEFT JOIN products p ON r.product_id = p.product_id
WHERE c.customer_id IS NULL OR p.product_id IS NULL;


-- ----------------------------------------------------------------------------
-- CHECK 2: Temporal Sequence & Event Logic
-- Description: Ensures chronologically valid timestamps across order lifecycle.
-- ----------------------------------------------------------------------------
-- 2A: Delivery timestamp preceding order placement timestamp
SELECT 'Delivery timestamp prior to order date' AS check_name, COUNT(*) AS violations
FROM orders
WHERE delivery_date IS NOT NULL AND delivery_date < order_date;

-- 2B: Orders placed in the future relative to system clock
SELECT 'Future-dated order placement' AS check_name, COUNT(*) AS violations
FROM orders
WHERE order_date > NOW();

-- 2C: Reviews created before customer registration
SELECT 'Reviews created before customer registration' AS check_name, COUNT(*) AS violations
FROM reviews r
JOIN customers c ON r.customer_id = c.customer_id
WHERE r.created_at < c.created_at;


-- ----------------------------------------------------------------------------
-- CHECK 3: Financial Domain Sanity & Line Item Reconciliation
-- Description: Verifies positive unit economics, margin bounds, and total sums.
-- ----------------------------------------------------------------------------
-- 3A: Products where sale price is lower than cost of goods sold (negative margin)
SELECT 'Products with negative margin (sale < cost)' AS check_name, COUNT(*) AS violations
FROM products
WHERE sale_price < cost_price;

-- 3B: Line items with invalid zero or negative pricing or quantities
SELECT 'Line items with non-positive quantities or prices' AS check_name, COUNT(*) AS violations
FROM order_items
WHERE quantity <= 0 OR unit_price <= 0 OR cost_price < 0;

-- 3C: Promotional discounts exceeding subtotal amount
SELECT 'Discount amount exceeding order subtotal' AS check_name, COUNT(*) AS violations
FROM orders
WHERE discount_amount > subtotal_amount;

-- 3D: Order total reconciliation discrepancy (subtotal - discount + shipping != total)
SELECT 'Order header total amount reconciliation mismatch' AS check_name, COUNT(*) AS violations
FROM orders
WHERE ABS((subtotal_amount - discount_amount + shipping_fee) - total_amount) > 0.01;

-- 3E: Order items sum reconciliation with order subtotal
SELECT 'Order header subtotal vs line items sum mismatch' AS check_name, COUNT(*) AS violations
FROM (
    SELECT o.order_id, o.subtotal_amount, COALESCE(SUM(oi.total_price), 0) AS calculated_subtotal
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.subtotal_amount
) sub
WHERE ABS(subtotal_amount - calculated_subtotal) > 0.01;


-- ----------------------------------------------------------------------------
-- CHECK 4: Lifecycle Status & Workflow Consistency
-- Description: Audits cross-field state rules.
-- ----------------------------------------------------------------------------
-- 4A: Orders marked 'delivered' but missing delivery date
SELECT 'Delivered orders missing delivery date' AS check_name, COUNT(*) AS violations
FROM orders
WHERE order_status = 'delivered' AND delivery_date IS NULL;

-- 4B: Orders not delivered but possessing delivery date
SELECT 'Undelivered orders with delivery date populated' AS check_name, COUNT(*) AS violations
FROM orders
WHERE order_status IN ('pending', 'processing', 'cancelled') AND delivery_date IS NOT NULL;

-- 4C: Completed payments on cancelled orders
SELECT 'Cancelled orders with settled payments' AS check_name, COUNT(*) AS violations
FROM orders o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'cancelled' AND p.payment_status = 'completed';


-- ----------------------------------------------------------------------------
-- CHECK 5: Uniqueness & Key Collision Audits
-- Description: Asserts unique identity constraints across natural keys.
-- ----------------------------------------------------------------------------
-- 5A: Duplicate customer emails
SELECT 'Duplicate customer emails' AS check_name, COUNT(*) AS violations
FROM (
    SELECT email, COUNT(*) FROM customers GROUP BY email HAVING COUNT(*) > 1
) dupes;

-- 5B: Duplicate product SKUs
SELECT 'Duplicate product SKUs' AS check_name, COUNT(*) AS violations
FROM (
    SELECT sku, COUNT(*) FROM products GROUP BY sku HAVING COUNT(*) > 1
) dupes;

-- 5C: Duplicate payment gateway transaction references
SELECT 'Duplicate gateway transaction IDs' AS check_name, COUNT(*) AS violations
FROM (
    SELECT gateway_transaction_id, COUNT(*) FROM payments GROUP BY gateway_transaction_id HAVING COUNT(*) > 1
) dupes;


-- ============================================================================
-- MASTER DATA QUALITY SCORECARD
-- Consolidates all integrity rules into a single production audit summary
-- ============================================================================
WITH audit_rules AS (
    SELECT 1 AS rule_id, 'Referential Integrity' AS category, 'Orders -> Customers FK Resolution' AS test_name, 
           COUNT(*) AS violation_count FROM orders o LEFT JOIN customers c ON o.customer_id = c.customer_id WHERE c.customer_id IS NULL
    UNION ALL
    SELECT 2, 'Referential Integrity', 'Order Items -> Orders FK Resolution', 
           COUNT(*) FROM order_items oi LEFT JOIN orders o ON oi.order_id = o.order_id WHERE o.order_id IS NULL
    UNION ALL
    SELECT 3, 'Referential Integrity', 'Order Items -> Products FK Resolution', 
           COUNT(*) FROM order_items oi LEFT JOIN products p ON oi.product_id = p.product_id WHERE p.product_id IS NULL
    UNION ALL
    SELECT 4, 'Referential Integrity', 'Payments -> Orders FK Resolution', 
           COUNT(*) FROM payments py LEFT JOIN orders o ON py.order_id = o.order_id WHERE o.order_id IS NULL
    UNION ALL
    SELECT 5, 'Temporal Sequence', 'Delivery Date >= Order Date', 
           COUNT(*) FROM orders WHERE delivery_date IS NOT NULL AND delivery_date < order_date
    UNION ALL
    SELECT 6, 'Temporal Sequence', 'No Future Order Timestamps', 
           COUNT(*) FROM orders WHERE order_date > NOW()
    UNION ALL
    SELECT 7, 'Financial Sanity', 'Sale Price >= Cost Price (Non-negative Margins)', 
           COUNT(*) FROM products WHERE sale_price < cost_price
    UNION ALL
    SELECT 8, 'Financial Sanity', 'Order Total = Subtotal - Discount + Shipping', 
           COUNT(*) FROM orders WHERE ABS((subtotal_amount - discount_amount + shipping_fee) - total_amount) > 0.01
    UNION ALL
    SELECT 9, 'Financial Sanity', 'Header Subtotal Reconciles With Item Totals', 
           COUNT(*) FROM (
               SELECT o.order_id, o.subtotal_amount, COALESCE(SUM(oi.total_price), 0) AS item_sum
               FROM orders o JOIN order_items oi ON o.order_id = oi.order_id
               GROUP BY o.order_id, o.subtotal_amount
           ) s WHERE ABS(subtotal_amount - item_sum) > 0.01
    UNION ALL
    SELECT 10, 'Status Consistency', 'Delivered Orders Require Delivery Date', 
           COUNT(*) FROM orders WHERE order_status = 'delivered' AND delivery_date IS NULL
    UNION ALL
    SELECT 11, 'Status Consistency', 'No Completed Payments on Cancelled Orders', 
           COUNT(*) FROM orders o JOIN payments p ON o.order_id = p.order_id WHERE o.order_status = 'cancelled' AND p.payment_status = 'completed'
    UNION ALL
    SELECT 12, 'Uniqueness & Keys', 'Customer Email Uniqueness', 
           COUNT(*) FROM (SELECT email FROM customers GROUP BY email HAVING COUNT(*) > 1) d
    UNION ALL
    SELECT 13, 'Uniqueness & Keys', 'Product SKU Uniqueness', 
           COUNT(*) FROM (SELECT sku FROM products GROUP BY sku HAVING COUNT(*) > 1) d
    UNION ALL
    SELECT 14, 'Uniqueness & Keys', 'Gateway Transaction ID Uniqueness', 
           COUNT(*) FROM (SELECT gateway_transaction_id FROM payments GROUP BY gateway_transaction_id HAVING COUNT(*) > 1) d
)
SELECT 
    rule_id,
    category,
    test_name,
    violation_count,
    CASE 
        WHEN violation_count = 0 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS status
FROM audit_rules
ORDER BY rule_id ASC;
