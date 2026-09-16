-- ============================================================================
-- 03_create_indexes.sql
-- Strategic Indexing for Query Performance Optimization
-- B-Tree, Composite, and Partial Indexes
-- ============================================================================

-- Foreign Key Indexes (Crucial for JOIN performance)
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_reviews_product_id ON reviews(product_id);
CREATE INDEX idx_reviews_customer_id ON reviews(customer_id);

-- Time-Series & Analytical Composite Indexes
-- Accelerates cohort queries and date-filtered executive dashboards
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_orders_date_status ON orders(order_date, order_status);
CREATE INDEX idx_customers_channel_created ON customers(acquisition_channel, created_at);

-- Partial Indexes (Targeted for high-frequency operational queries)
-- Focuses index maintenance only on active inventory and active orders
CREATE INDEX idx_orders_active_pipeline ON orders(order_id, order_date) 
WHERE order_status IN ('pending', 'processing', 'shipped');

CREATE INDEX idx_products_low_stock ON products(product_id, stock_quantity)
WHERE is_active = TRUE AND stock_quantity < 15;

-- Trigram Index for Catalog Search Optimization
CREATE INDEX idx_products_name_trgm ON products USING gin (product_name gin_trgm_ops);
