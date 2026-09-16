-- ============================================================================
-- 00_seed_all.sql
-- Master Seed Script to populate PostgreSQL tables from generated CSVs
-- Run in psql using: \i data/00_seed_all.sql
-- ============================================================================

-- Disable triggers temporarily during bulk load if desired
SET session_replication_role = 'replica';

\echo 'Importing categories...'
\copy categories(category_id, category_name, parent_category_id, description) FROM 'data/categories.csv' WITH (FORMAT csv, HEADER true, NULL '');

\echo 'Importing products...'
\copy products(product_id, category_id, product_name, sku, cost_price, sale_price, stock_quantity, is_active, created_at) FROM 'data/products.csv' WITH (FORMAT csv, HEADER true);

\echo 'Importing customers...'
\copy customers(customer_id, first_name, last_name, email, phone, city, state, postal_code, country, acquisition_channel, created_at) FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true);

\echo 'Importing orders...'
\copy orders(order_id, customer_id, order_date, order_status, subtotal_amount, shipping_fee, discount_amount, total_amount, shipping_city, shipping_state, shipping_postal_code, delivery_date) FROM 'data/orders.csv' WITH (FORMAT csv, HEADER true, NULL '');

\echo 'Importing order_items...'
\copy order_items(order_item_id, order_id, product_id, quantity, unit_price, cost_price, item_discount) FROM 'data/order_items.csv' WITH (FORMAT csv, HEADER true);

\echo 'Importing payments...'
\copy payments(payment_id, order_id, payment_method, payment_status, amount, transaction_timestamp, gateway_transaction_id) FROM 'data/payments.csv' WITH (FORMAT csv, HEADER true);

\echo 'Importing reviews...'
\copy reviews(review_id, customer_id, product_id, order_id, rating, review_title, review_text, is_verified_purchase, created_at) FROM 'data/reviews.csv' WITH (FORMAT csv, HEADER true, NULL '');

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Update sequence serial counters
SELECT setval('categories_category_id_seq', (SELECT MAX(category_id) FROM categories));
SELECT setval('products_product_id_seq', (SELECT MAX(product_id) FROM products));
SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers));
SELECT setval('orders_order_id_seq', (SELECT MAX(order_id) FROM orders));
SELECT setval('order_items_order_item_id_seq', (SELECT MAX(order_item_id) FROM order_items));
SELECT setval('payments_payment_id_seq', (SELECT MAX(payment_id) FROM payments));
SELECT setval('reviews_review_id_seq', (SELECT MAX(review_id) FROM reviews));

-- Refresh Materialized Views
REFRESH MATERIALIZED VIEW mv_monthly_financial_performance;

\echo 'Data seeding complete and sequences synchronized!'
