-- ============================================================================
-- 04_views_and_functions.sql
-- Analytical Views, Materialized Views, and Automation Logic
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Analytical View: Detailed Order Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_order_details AS
SELECT 
    o.order_id,
    o.order_date,
    o.order_status,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email AS customer_email,
    c.city AS customer_city,
    c.state AS customer_state,
    c.acquisition_channel,
    p.product_id,
    p.product_name,
    cat.category_name,
    oi.quantity,
    oi.unit_price,
    oi.cost_price,
    oi.item_discount,
    oi.total_price AS item_revenue,
    (oi.total_price - (oi.quantity * oi.cost_price)) AS item_gross_profit,
    ROUND(((oi.total_price - (oi.quantity * oi.cost_price)) / NULLIF(oi.total_price, 0)) * 100, 2) AS item_margin_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id;

COMMENT ON VIEW vw_order_details IS 'Denormalized dimensional view combining transactions, customers, line items, and product margins.';

-- ----------------------------------------------------------------------------
-- 2. Materialized View: Monthly Executive Financial Performance
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_financial_performance CASCADE;

CREATE MATERIALIZED VIEW mv_monthly_financial_performance AS
SELECT 
    DATE_TRUNC('month', o.order_date)::DATE AS sales_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_buyers,
    SUM(o.subtotal_amount) AS gross_merchandise_value,
    SUM(o.discount_amount) AS total_discounts,
    SUM(o.shipping_fee) AS total_shipping_revenue,
    SUM(o.total_amount) AS net_revenue,
    SUM(oi.quantity * oi.cost_price) AS total_cogs,
    (SUM(o.total_amount) - SUM(oi.quantity * oi.cost_price)) AS gross_profit,
    ROUND(
        ((SUM(o.total_amount) - SUM(oi.quantity * oi.cost_price)) / NULLIF(SUM(o.total_amount), 0)) * 100, 
        2
    ) AS gross_profit_margin_pct,
    ROUND(SUM(o.total_amount) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('cancelled')
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY sales_month;

CREATE UNIQUE INDEX idx_mv_monthly_sales_month ON mv_monthly_financial_performance(sales_month);

COMMENT ON MATERIALIZED VIEW mv_monthly_financial_performance IS 'Pre-aggregated monthly executive financial KPIs for fast reporting and dashboard delivery.';

-- ----------------------------------------------------------------------------
-- 3. Stored Procedure: Refresh Analytical Materialized Views
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_refresh_analytics_views()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_financial_performance;
    RAISE NOTICE 'Materialized views refreshed successfully at %', CURRENT_TIMESTAMP;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Trigger Function: Automatically Maintain Inventory on Order Placement
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_adjust_inventory_on_sale()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    -- Safety check against negative stock
    IF (SELECT stock_quantity FROM products WHERE product_id = NEW.product_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient inventory for product_id: %', NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_deduct_inventory
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_adjust_inventory_on_sale();
