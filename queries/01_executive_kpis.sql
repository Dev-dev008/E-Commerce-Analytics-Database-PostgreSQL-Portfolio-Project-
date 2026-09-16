-- ============================================================================
-- 01_executive_kpis.sql
-- Executive Financial & Operational KPIs
-- Core Metrics: GMV, Net Revenue, COGS, Gross Margin %, AOV, MoM Growth Rate
-- ============================================================================

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
),
metrics_with_growth AS (
    SELECT 
        sales_month,
        total_orders,
        active_customers,
        gross_merchandise_value,
        total_discounts,
        net_revenue,
        total_cogs,
        gross_profit,
        ROUND((gross_profit / NULLIF(net_revenue, 0)) * 100, 2) AS gross_margin_pct,
        ROUND(net_revenue / NULLIF(total_orders, 0), 2) AS average_order_value,
        LAG(net_revenue) OVER (ORDER BY sales_month) AS prev_month_net_revenue,
        ROUND(
            ((net_revenue - LAG(net_revenue) OVER (ORDER BY sales_month)) / 
             NULLIF(LAG(net_revenue) OVER (ORDER BY sales_month), 0)) * 100, 
            2
        ) AS mom_net_revenue_growth_pct
    FROM monthly_sales
)
SELECT 
    TO_CHAR(sales_month, 'YYYY-MM') AS month_label,
    total_orders,
    active_customers,
    TO_CHAR(gross_merchandise_value, '$FM999,999,990.00') AS gmv,
    TO_CHAR(total_discounts, '$FM999,999,990.00') AS discounts,
    TO_CHAR(net_revenue, '$FM999,999,990.00') AS net_revenue,
    TO_CHAR(gross_profit, '$FM999,999,990.00') AS gross_profit,
    CONCAT(gross_margin_pct, '%') AS gross_margin,
    TO_CHAR(average_order_value, '$FM999,990.00') AS aov,
    CASE 
        WHEN mom_net_revenue_growth_pct IS NULL THEN 'N/A (Base)'
        ELSE CONCAT(mom_net_revenue_growth_pct, '%')
    END AS mom_growth
FROM metrics_with_growth
ORDER BY sales_month DESC;

-- ----------------------------------------------------------------------------
-- Sub-Query: Customer Acquisition Channel Performance
-- ----------------------------------------------------------------------------
SELECT 
    c.acquisition_channel,
    COUNT(DISTINCT c.customer_id) AS acquired_customers,
    COUNT(DISTINCT o.order_id) AS total_orders_placed,
    TO_CHAR(COALESCE(SUM(o.total_amount), 0), '$FM999,999,990.00') AS total_attributed_revenue,
    TO_CHAR(ROUND(COALESCE(SUM(o.total_amount), 0) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2), '$FM999,990.00') AS revenue_per_acquired_customer,
    ROUND((COUNT(DISTINCT c.customer_id)::NUMERIC / (SELECT COUNT(*) FROM customers) * 100), 2) AS channel_share_pct
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status NOT IN ('cancelled')
GROUP BY c.acquisition_channel
ORDER BY COALESCE(SUM(o.total_amount), 0) DESC;
