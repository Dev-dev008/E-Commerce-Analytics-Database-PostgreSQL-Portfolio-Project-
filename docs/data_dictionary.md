# 📚 E-Commerce Analytics Database: Data Dictionary

This document outlines the schema architecture, column definitions, data types, constraints, and relational mappings for the `ecommerce_analytics` database.

---

## 🗄️ Tables Overview

| Table | Records | Primary Key | Description |
| :--- | :--- | :--- | :--- |
| **`customers`** | 1,200 | `customer_id` | Demographic profiles, geographical location, and marketing acquisition channels. |
| **`categories`** | 10 | `category_id` | Hierarchical department and subcategory classification for products. |
| **`products`** | 38 | `product_id` | Catalog items with SKU, unit costs, retail prices, and inventory stock levels. |
| **`orders`** | 2,141 | `order_id` | Transaction headers containing timestamps, delivery status, and financial totals. |
| **`order_items`** | 3,604 | `order_item_id` | Line-item specifics linking purchased quantities, discounts, and historical cost. |
| **`payments`** | 2,141 | `payment_id` | Gateway transaction audit logs, payment methods, and settlement statuses. |
| **`reviews`** | 645 | `review_id` | Customer product reviews, 1-5 star ratings, and sentiment feedback. |

---

## 1. `customers`
Stores user demographic profiles and origin marketing channels.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `customer_id` | `SERIAL` | `PRIMARY KEY` | Unique customer auto-incrementing ID. |
| `first_name` | `VARCHAR(50)` | `NOT NULL` | Customer first name. |
| `last_name` | `VARCHAR(50)` | `NOT NULL` | Customer last name. |
| `email` | `VARCHAR(100)` | `NOT NULL, UNIQUE` | Customer email address. |
| `phone` | `VARCHAR(25)` | `NULLABLE` | Contact phone number. |
| `city` | `VARCHAR(60)` | `NOT NULL` | Customer billing / shipping city. |
| `state` | `VARCHAR(50)` | `NOT NULL` | US State code or name. |
| `postal_code` | `VARCHAR(20)` | `NULLABLE` | Postal/ZIP code. |
| `country` | `VARCHAR(50)` | `NOT NULL, DEFAULT 'United States'` | Residence country. |
| `acquisition_channel` | `VARCHAR(40)` | `NOT NULL, CHECK` | Channel of origin: *Organic Search, Direct, Google Ads, Meta Ads, Email Campaign, Affiliate, Referral*. |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL, DEFAULT CURRENT_TIMESTAMP` | Account registration timestamp. |

---

## 2. `categories`
Hierarchical product categories.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `category_id` | `SERIAL` | `PRIMARY KEY` | Category identifier. |
| `category_name` | `VARCHAR(80)` | `NOT NULL, UNIQUE` | Category title (e.g. *Electronics*, *Audio & Headphones*). |
| `parent_category_id`| `INT` | `FK -> categories(category_id)` | Self-referential key for subcategories. |
| `description` | `TEXT` | `NULLABLE` | Category summary. |

---

## 3. `products`
Master catalog items, margins, and real-time inventory tracking.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `product_id` | `SERIAL` | `PRIMARY KEY` | Product identifier. |
| `category_id` | `INT` | `NOT NULL, FK -> categories` | Associated category. |
| `product_name` | `VARCHAR(150)`| `NOT NULL` | Product display name. |
| `sku` | `VARCHAR(40)` | `NOT NULL, UNIQUE` | Stock Keeping Unit code. |
| `cost_price` | `NUMERIC(10,2)`| `NOT NULL, CHECK (cost_price >= 0)` | Wholesale unit acquisition cost. |
| `sale_price` | `NUMERIC(10,2)`| `NOT NULL, CHECK (sale_price >= cost_price)` | Retail list price. |
| `stock_quantity` | `INT` | `NOT NULL, DEFAULT 0, CHECK (>= 0)` | Available on-hand inventory units. |
| `is_active` | `BOOLEAN` | `NOT NULL, DEFAULT TRUE` | Active selling flag. |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL, DEFAULT CURRENT_TIMESTAMP` | Catalog addition timestamp. |

---

## 4. `orders`
Header transaction records.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `order_id` | `SERIAL` | `PRIMARY KEY` | Order identifier. |
| `customer_id` | `INT` | `NOT NULL, FK -> customers` | Purchasing customer. |
| `order_date` | `TIMESTAMPTZ` | `NOT NULL, DEFAULT CURRENT_TIMESTAMP` | Order placement timestamp. |
| `order_status` | `order_status_enum` | `NOT NULL, DEFAULT 'pending'` | `pending`, `processing`, `shipped`, `delivered`, `cancelled`, `returned`. |
| `subtotal_amount`| `NUMERIC(10,2)`| `NOT NULL, CHECK (>= 0)` | Total line-items amount before shipping/discounts. |
| `shipping_fee` | `NUMERIC(10,2)`| `NOT NULL, DEFAULT 0.00` | Freight charge. |
| `discount_amount`| `NUMERIC(10,2)`| `NOT NULL, DEFAULT 0.00` | Order-level promotional discount. |
| `total_amount` | `NUMERIC(10,2)`| `NOT NULL, CHECK (>= 0)` | Net billed amount (`subtotal + shipping - discount`). |
| `shipping_city` | `VARCHAR(60)` | `NOT NULL` | Destination city. |
| `shipping_state`| `VARCHAR(50)` | `NOT NULL` | Destination state. |
| `shipping_postal_code`| `VARCHAR(20)`| `NULLABLE` | Destination ZIP code. |
| `delivery_date` | `TIMESTAMPTZ` | `CHECK (delivery_date >= order_date)` | Timestamp of delivery completion. |

---

## 5. `order_items`
Line item records specifying units and historical transaction price.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `order_item_id` | `SERIAL` | `PRIMARY KEY` | Line item identifier. |
| `order_id` | `INT` | `NOT NULL, FK -> orders` | Associated order. |
| `product_id` | `INT` | `NOT NULL, FK -> products` | Purchased product. |
| `quantity` | `INT` | `NOT NULL, CHECK (quantity > 0)` | Quantity ordered. |
| `unit_price` | `NUMERIC(10,2)`| `NOT NULL, CHECK (>= 0)` | Selling price at moment of purchase. |
| `cost_price` | `NUMERIC(10,2)`| `NOT NULL, CHECK (>= 0)` | Wholesale unit cost at moment of purchase. |
| `item_discount` | `NUMERIC(10,2)`| `NOT NULL, DEFAULT 0.00` | Item-specific promotional discount. |
| `total_price` | `NUMERIC(10,2)`| `GENERATED ALWAYS AS ((quantity * unit_price) - item_discount) STORED` | Net line total revenue. |

---

## 6. `payments`
Gateway payment audit logs.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `payment_id` | `SERIAL` | `PRIMARY KEY` | Payment identifier. |
| `order_id` | `INT` | `NOT NULL, FK -> orders` | Associated order. |
| `payment_method`| `payment_method_enum`| `NOT NULL` | `credit_card`, `debit_card`, `paypal`, `apple_pay`, `upi`, `bank_transfer`. |
| `payment_status`| `payment_status_enum`| `NOT NULL, DEFAULT 'pending'` | `completed`, `pending`, `failed`, `refunded`. |
| `amount` | `NUMERIC(10,2)`| `NOT NULL, CHECK (>= 0)` | Amount processed. |
| `transaction_timestamp`| `TIMESTAMPTZ`| `NOT NULL, DEFAULT CURRENT_TIMESTAMP` | Gateway processing timestamp. |
| `gateway_transaction_id`| `VARCHAR(80)`| `NOT NULL, UNIQUE` | Unique merchant processor trace ID. |

---

## 7. `reviews`
Customer product reviews and ratings.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `review_id` | `SERIAL` | `PRIMARY KEY` | Review identifier. |
| `customer_id` | `INT` | `NOT NULL, FK -> customers` | Author customer. |
| `product_id` | `INT` | `NOT NULL, FK -> products` | Reviewed product. |
| `order_id` | `INT` | `NULLABLE, FK -> orders` | Verified purchase order reference. |
| `rating` | `SMALLINT` | `NOT NULL, CHECK (rating BETWEEN 1 AND 5)` | 1 to 5 star rating. |
| `review_title` | `VARCHAR(120)`| `NULLABLE` | Short headline summary. |
| `review_text` | `TEXT` | `NULLABLE` | Detailed feedback text. |
| `is_verified_purchase`| `BOOLEAN` | `NOT NULL, DEFAULT FALSE` | Flag validating receipt of delivered product. |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL, DEFAULT CURRENT_TIMESTAMP` | Review posting timestamp. |
