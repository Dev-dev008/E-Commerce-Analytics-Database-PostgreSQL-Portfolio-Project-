-- ============================================================================
-- 02_create_tables.sql
-- Core E-Commerce Relational Tables (3NF Design with Integrity Constraints)
-- ============================================================================

-- Drop tables in reverse dependency order if needed for clean re-runs
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Drop custom types if they exist
DROP TYPE IF EXISTS order_status_enum CASCADE;
DROP TYPE IF EXISTS payment_method_enum CASCADE;
DROP TYPE IF EXISTS payment_status_enum CASCADE;

-- ----------------------------------------------------------------------------
-- Custom Enum Types
-- ----------------------------------------------------------------------------
CREATE TYPE order_status_enum AS ENUM (
    'pending',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
    'returned'
);

CREATE TYPE payment_method_enum AS ENUM (
    'credit_card',
    'debit_card',
    'paypal',
    'apple_pay',
    'upi',
    'bank_transfer'
);

CREATE TYPE payment_status_enum AS ENUM (
    'completed',
    'pending',
    'failed',
    'refunded'
);

-- ----------------------------------------------------------------------------
-- 1. Customers
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(25),
    city VARCHAR(60) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20),
    country VARCHAR(50) NOT NULL DEFAULT 'United States',
    acquisition_channel VARCHAR(40) NOT NULL CHECK (acquisition_channel IN ('Organic Search', 'Direct', 'Google Ads', 'Meta Ads', 'Email Campaign', 'Affiliate', 'Referral')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE customers IS 'Stores demographic and acquisition information for e-commerce customers.';

-- ----------------------------------------------------------------------------
-- 2. Categories
-- ----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(80) NOT NULL UNIQUE,
    parent_category_id INT REFERENCES categories(category_id) ON DELETE SET NULL,
    description TEXT
);

COMMENT ON TABLE categories IS 'Hierarchical taxonomy for organizing products into departments and subcategories.';

-- ----------------------------------------------------------------------------
-- 3. Products
-- ----------------------------------------------------------------------------
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    product_name VARCHAR(150) NOT NULL,
    sku VARCHAR(40) NOT NULL UNIQUE,
    cost_price NUMERIC(10, 2) NOT NULL CHECK (cost_price >= 0),
    sale_price NUMERIC(10, 2) NOT NULL CHECK (sale_price >= cost_price),
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE products IS 'Master catalog containing pricing, inventory, and margin metrics.';

-- ----------------------------------------------------------------------------
-- 4. Orders
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    order_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status order_status_enum NOT NULL DEFAULT 'pending',
    subtotal_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal_amount >= 0),
    shipping_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (shipping_fee >= 0),
    discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0),
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    shipping_city VARCHAR(60) NOT NULL,
    shipping_state VARCHAR(50) NOT NULL,
    shipping_postal_code VARCHAR(20),
    delivery_date TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_delivery_after_order CHECK (delivery_date IS NULL OR delivery_date >= order_date)
);

COMMENT ON TABLE orders IS 'Header record for all customer transactions, timestamps, and delivery milestones.';

-- ----------------------------------------------------------------------------
-- 5. Order Items
-- ----------------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    cost_price NUMERIC(10, 2) NOT NULL CHECK (cost_price >= 0),
    item_discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (item_discount >= 0),
    total_price NUMERIC(10, 2) GENERATED ALWAYS AS ((quantity * unit_price) - item_discount) STORED
);

COMMENT ON TABLE order_items IS 'Line-level details for each item purchased within an order.';

-- ----------------------------------------------------------------------------
-- 6. Payments
-- ----------------------------------------------------------------------------
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    payment_method payment_method_enum NOT NULL,
    payment_status payment_status_enum NOT NULL DEFAULT 'pending',
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    transaction_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gateway_transaction_id VARCHAR(80) NOT NULL UNIQUE
);

COMMENT ON TABLE payments IS 'Settlement transactions and payment gateway audit records.';

-- ----------------------------------------------------------------------------
-- 7. Reviews
-- ----------------------------------------------------------------------------
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    order_id INT REFERENCES orders(order_id) ON DELETE SET NULL,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_title VARCHAR(120),
    review_text TEXT,
    is_verified_purchase BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE reviews IS 'Customer feedback, star ratings, and sentiment for catalog products.';
