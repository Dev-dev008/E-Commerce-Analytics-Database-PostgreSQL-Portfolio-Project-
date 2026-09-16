-- ============================================================================
-- 07_performance_tuning_explain_analyze.sql
-- Query Performance Tuning & Execution Plan Benchmarks
-- Database Engine: PostgreSQL 14+
-- ============================================================================
-- Purpose:
--   Demonstrates enterprise SQL performance engineering practices using
--   EXPLAIN (ANALYZE, BUFFERS, VERBOSE, COSTS, TIMING).
--
-- Key Optimization Concepts Evaluated:
--   1. Materialized View Caching vs Dynamic Multi-Table Aggregation CTEs
--   2. Partial B-Tree Indexes on High-Churn Operational Subsets
--   3. Composite Multi-Column Indexes for Point-in-Time Customer Timelines
--   4. Memory Management & Multi-Pass Quicksort for Window Functions (RFM)
--   5. Hash Join Memory Allocation & Multi-Table Relational Plan Shapes
--   6. GIN Trigram Inverted Indexes vs Sequential Full-Table Scans
--   7. System Diagnostics: Buffer Cache Hit Ratio & Index Usage Health
--
-- How to run:
--   psql -U postgres -d ecommerce_analytics -f queries/07_performance_tuning_explain_analyze.sql
-- ============================================================================

\timing on
SET client_min_messages = warning;

-- ============================================================================
-- BENCHMARK 1: DYNAMIC CTE AGGREGATION VS MATERIALIZED VIEW CACHING
-- Scenario: Executive Monthly Financial KPI Dashboard Query
-- ============================================================================

-- 1A: Dynamic On-The-Fly Aggregation (Computes multi-table joins and aggregations dynamically)
\echo '>>> [1A] Dynamic CTE Aggregation (Uncached Multi-Table Join)...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', o.order_date)::DATE AS sales_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        SUM(o.subtotal_amount) AS gross_merchandise_value,
        SUM(o.discount_amount) AS total_discounts,
        SUM(o.shipping_fee) AS total_shipping_revenue,
        SUM(o.total_amount) AS net_revenue,
        SUM(oi.quantity * oi.cost_price) AS total_cogs,
        (SUM(o.total_amount) - SUM(oi.quantity * oi.cost_price)) AS gross_profit
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('cancelled')
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT 
    sales_month,
    total_orders,
    active_customers,
    gross_merchandise_value,
    net_revenue,
    gross_profit,
    ROUND((gross_profit / NULLIF(net_revenue, 0)) * 100, 2) AS gross_margin_pct
FROM monthly_sales
ORDER BY sales_month DESC;

-- 1B: Pre-computed Materialized View Query (Accelerated by clustered unique index)
\echo '>>> [1B] Materialized View Lookup (mv_monthly_financial_performance)...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    sales_month,
    total_orders,
    unique_buyers AS active_customers,
    gross_merchandise_value,
    net_revenue,
    gross_profit,
    gross_profit_margin_pct AS gross_margin_pct
FROM mv_monthly_financial_performance
ORDER BY sales_month DESC;


-- ============================================================================
-- BENCHMARK 2: PARTIAL INDEX SCAN VS FULL HEAP SEQUENTIAL SCAN
-- Scenario: Operational Pipeline Dispatch (Filter pending/processing/shipped)
-- ============================================================================

-- 2A: Full Heap Sequential Scan (Simulated by disabling index scans)
\echo '>>> [2A] Full Heap Sequential Scan on Active Orders (Simulated without Index)...'
SET enable_indexscan = off;
SET enable_indexonlyscan = off;
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date, customer_id, total_amount
FROM orders
WHERE order_status IN ('pending', 'processing', 'shipped')
ORDER BY order_date DESC;

-- Reset planner configuration
RESET enable_indexscan;
RESET enable_indexonlyscan;
RESET enable_bitmapscan;

-- 2B: Partial Index Accelerated Scan (Index: idx_orders_active_pipeline)
\echo '>>> [2B] Partial Index Scan on Active Orders (idx_orders_active_pipeline)...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date
FROM orders
WHERE order_status IN ('pending', 'processing', 'shipped')
ORDER BY order_date DESC;


-- ============================================================================
-- BENCHMARK 3: COMPOSITE INDEX VS TABLE SCAN ON CUSTOMER TIMELINES
-- Scenario: Order History Filtered by Customer ID and Date Range
-- ============================================================================

-- 3A: Filter without Index (Forces sequential scan on orders table)
\echo '>>> [3A] Customer Orders Timeline without Index...'
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, customer_id, order_date, total_amount, order_status
FROM orders
WHERE customer_id = 150 AND order_date >= '2024-01-01'
ORDER BY order_date DESC;

RESET enable_indexscan;
RESET enable_bitmapscan;

-- 3B: Composite Index Scan (Index: idx_orders_customer_date)
\echo '>>> [3B] Customer Orders Timeline with Composite B-Tree Index...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, customer_id, order_date, total_amount, order_status
FROM orders
WHERE customer_id = 150 AND order_date >= '2024-01-01'
ORDER BY order_date DESC;


-- ============================================================================
-- BENCHMARK 4: MULTI-WINDOW FUNCTION SORTING & MEMORY CONSUMPTION
-- Scenario: RFM Segmentation Quintiles (Recency, Frequency, Monetary NTILE)
-- ============================================================================
\echo '>>> [4] RFM Segmentation Multi-Window Function Execution Plan...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH customer_rfm_raw AS (
    SELECT 
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email,
        c.city,
        c.state,
        c.acquisition_channel,
        MAX(o.order_date) AS last_order_date,
        ('2024-12-31'::DATE - MAX(o.order_date)::DATE) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        COALESCE(SUM(o.total_amount), 0) AS monetary_value
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status NOT IN ('cancelled')
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.city, c.state, c.acquisition_channel
),
rfm_scores AS (
    SELECT 
        customer_id,
        customer_name,
        recency_days,
        frequency_orders,
        monetary_value,
        NTILE(5) OVER (ORDER BY recency_days ASC NULLS LAST) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value DESC) AS m_score
    FROM customer_rfm_raw
)
SELECT 
    r_score, 
    f_score, 
    m_score, 
    COUNT(*) AS total_customers,
    ROUND(AVG(monetary_value), 2) AS avg_segment_spend
FROM rfm_scores
GROUP BY r_score, f_score, m_score
ORDER BY r_score DESC, f_score DESC, m_score DESC
LIMIT 15;


-- ============================================================================
-- BENCHMARK 5: MULTI-TABLE JOIN TREE & HASH AGGREGATE MEMORY (PARETO 80/20)
-- Scenario: 4-Way Relational Join Across Products, Categories, Order Items, Orders
-- ============================================================================
\echo '>>> [5] Pareto 80/20 4-Table Hash Join & Running Window Aggregation...'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.sku,
        c.category_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.total_price) AS total_revenue,
        SUM(oi.total_price - (oi.quantity * oi.cost_price)) AS total_gross_profit
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('cancelled')
    GROUP BY p.product_id, p.product_name, p.sku, c.category_name
)
SELECT 
    product_name,
    category_name,
    total_units_sold,
    total_revenue,
    total_gross_profit,
    SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
    ROUND(
        (SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / NULLIF(SUM(total_revenue) OVER (), 0)) * 100, 
        2
    ) AS cumulative_revenue_pct
FROM product_sales
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================================================
-- BENCHMARK 6: GIN TRIGRAM INDEX SEARCH VS SEQUENTIAL SCAN
-- Scenario: Catalog Fuzzy Search on Product Names
-- ============================================================================

-- 6A: Sequential Scan on Pattern Search
\echo '>>> [6A] Trigram Fuzzy Search (Forced Seq Scan)...'
SET enable_bitmapscan = off;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT product_id, product_name, sku, sale_price
FROM products
WHERE product_name ILIKE '%wireless%'
ORDER BY sale_price DESC;
RESET enable_bitmapscan;

-- 6B: GIN Trigram Bitmap Index Scan (Index: idx_products_name_trgm)
\echo '>>> [6B] Trigram Fuzzy Search (GIN Index Scan)...'
SET enable_seqscan = off;
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT product_id, product_name, sku, sale_price
FROM products
WHERE product_name ILIKE '%wireless%'
ORDER BY sale_price DESC;
RESET enable_seqscan;


-- ============================================================================
-- BENCHMARK 7: DATABASE BUFFER CACHE & INDEX USAGE HEALTH DIAGNOSTICS
-- Scenario: Auditing Operational Cache Hit Rates and Index Utilization
-- ============================================================================
\echo '>>> [7A] Database-Wide Buffer Cache Hit Ratio...'
SELECT 
    datname AS database_name,
    blks_read AS disk_blocks_read,
    blks_hit AS memory_blocks_hit,
    ROUND((blks_hit::NUMERIC / NULLIF(blks_hit + blks_read, 0)) * 100, 2) AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname = current_database();

\echo '>>> [7B] User Table Index Usage Audit...'
SELECT 
    relname AS table_name,
    seq_scan AS sequential_scans,
    seq_tup_read AS tuples_read_seq,
    idx_scan AS index_scans,
    idx_tup_fetch AS tuples_fetched_idx,
    ROUND(
        (idx_scan::NUMERIC / NULLIF(idx_scan + seq_scan, 0)) * 100, 
        1
    ) AS index_utilization_pct
FROM pg_stat_user_tables
ORDER BY (idx_scan + seq_scan) DESC;
