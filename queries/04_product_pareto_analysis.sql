-- ============================================================================
-- 04_product_pareto_analysis.sql
-- Pareto (80/20 Rule) & Product Catalog Contribution Analysis
-- Classifies products into Tier A (80% revenue), Tier B (15%), and Tier C (5%)
-- ============================================================================

WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.sku,
        c.category_name,
        p.stock_quantity AS current_inventory,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.total_price) AS total_revenue,
        SUM(oi.total_price - (oi.quantity * oi.cost_price)) AS total_gross_profit,
        ROUND((SUM(oi.total_price - (oi.quantity * oi.cost_price)) / NULLIF(SUM(oi.total_price), 0)) * 100, 2) AS margin_pct
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('cancelled')
    GROUP BY p.product_id, p.product_name, p.sku, c.category_name, p.stock_quantity
),
product_pareto AS (
    SELECT 
        product_id,
        product_name,
        sku,
        category_name,
        current_inventory,
        total_units_sold,
        total_revenue,
        total_gross_profit,
        margin_pct,
        -- Running cumulative revenue
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        -- Total catalog revenue
        SUM(total_revenue) OVER () AS overall_revenue,
        -- Cumulative percentage of total sales
        ROUND(
            (SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / SUM(total_revenue) OVER ()) * 100, 
            2
        ) AS cumulative_revenue_pct,
        -- Rank products by revenue
        DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM product_sales
)
SELECT 
    revenue_rank,
    product_name,
    category_name,
    total_units_sold,
    TO_CHAR(total_revenue, '$FM999,999,990.00') AS revenue,
    TO_CHAR(total_gross_profit, '$FM999,999,990.00') AS profit,
    CONCAT(margin_pct, '%') AS margin,
    CONCAT(cumulative_revenue_pct, '%') AS cumulative_share,
    CASE 
        WHEN cumulative_revenue_pct <= 80.0 THEN 'Tier A (Top 80% Driver)'
        WHEN cumulative_revenue_pct <= 95.0 THEN 'Tier B (Mid 15% Contributor)'
        ELSE 'Tier C (Tail 5% Long-Tail)'
    END AS pareto_classification
FROM product_pareto
ORDER BY revenue_rank ASC;
