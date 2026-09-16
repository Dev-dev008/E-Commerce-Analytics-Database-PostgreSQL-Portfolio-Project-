"""
E-Commerce Synthetic Dataset Generator
Generates realistic, referentially consistent e-commerce data for PostgreSQL portfolio showcase.
Outputs CSV files formatted for direct PostgreSQL \copy import.
"""

import os
import csv
import random
import uuid
from datetime import datetime, timedelta

# Fix random seed for reproducible benchmark data
random.seed(42)

DATA_DIR = os.path.dirname(os.path.abspath(__file__))

# -----------------------------------------------------------------------------
# Reference Dictionaries & Seed Lists
# -----------------------------------------------------------------------------
CATEGORIES = [
    (1, "Electronics", None, "Personal electronics, computing, and accessories"),
    (2, "Audio & Headphones", 1, "High-fidelity audio equipment, wireless earphones, and soundbars"),
    (3, "Smart Home", 1, "Connected home devices, smart lighting, and security"),
    (4, "Apparel & Fashion", None, "Men's, women's, and unisex everyday apparel"),
    (5, "Footwear", 4, "Athletic, casual, and formal shoes"),
    (6, "Home & Kitchen", None, "Cookware, kitchen appliances, and storage essentials"),
    (7, "Fitness & Wellness", None, "Home gym equipment, yoga gear, and health tracking"),
    (8, "Beauty & Personal Care", None, "Skincare, haircare, and daily grooming essentials"),
    (9, "Office & Workspace", None, "Ergonomic furniture, desk organization, and productivity tools"),
    (10, "Outdoor & Travel", None, "Backpacks, camping gear, and travel luggage"),
]

PRODUCT_TEMPLATES = [
    # Electronics & Audio
    (1, "Apex Wireless Noise-Cancelling Headphones", 75.00, 179.99, 120),
    (1, "UltraView 27-inch 4K USB-C Monitor", 210.00, 399.99, 45),
    (1, "Pulse Wireless Mechanical Keyboard (RGB)", 48.00, 119.99, 85),
    (1, "Glide Pro Ergonomic Wireless Mouse", 22.00, 69.99, 140),
    (1, "HyperVolt 100W GaN Fast Charger", 16.00, 49.99, 210),
    (2, "SoundWave Mini Portable Bluetooth Speaker", 18.50, 49.99, 175),
    (2, "StudioPro Open-Back Reference Headphones", 110.00, 249.99, 35),
    (2, "AeroPod True Wireless Earbuds with ANC", 38.00, 89.99, 160),
    (3, "Lumina Smart LED Strip (16M Colors, 5m)", 12.00, 34.99, 190),
    (3, "HomeGuard 2K Wireless Security Camera", 32.00, 79.99, 80),
    (3, "Aura Smart Ambient Light Bar Duo", 28.00, 69.99, 95),

    # Apparel & Footwear
    (4, "Core Merino Wool Crewneck Sweater", 30.00, 88.00, 110),
    (4, "All-Weather Technical Windbreaker Jacket", 42.00, 124.99, 70),
    (4, "Tailored Slim-Fit Chino Pants", 24.00, 68.00, 130),
    (4, "Everyday Organic Cotton Heavyweight T-Shirt", 8.50, 28.00, 260),
    (4, "Thermal Fleece Winter Pullover", 26.00, 74.99, 85),
    (5, "Velocity Carbon-Plated Running Shoes", 55.00, 159.99, 65),
    (5, "CloudWalk Casual Canvas Low-Tops", 20.00, 59.99, 150),
    (5, "Trekker Waterproof Trail Hiking Boots", 62.00, 169.99, 50),
    (5, "Retro Classic Leather Sneakers", 35.00, 99.99, 90),

    # Home, Kitchen & Office
    (6, "BaristaPro Precision Burr Coffee Grinder", 45.00, 129.99, 60),
    (6, "CastIron 5.5 Quart Enameled Dutch Oven", 38.00, 99.99, 75),
    (6, "ChefSelect Japanese 8-inch Damascus Chef Knife", 32.00, 89.99, 80),
    (6, "HydroPure Multi-Stage Countertop Water Filter", 25.00, 69.99, 115),
    (6, "AeroPress Go Travel Coffee Press", 14.00, 39.95, 140),
    (7, "FlexiBands Resistance Bands Set (5-Pack)", 6.50, 24.99, 220),
    (7, "ProForm High-Density Foam Roller (36 in)", 11.00, 32.00, 130),
    (7, "IronCore Adjustable Dumbbells (Pair 50lbs)", 140.00, 329.99, 30),
    (7, "Zenith Eco-Friendly Cork Yoga Mat", 18.00, 54.99, 90),
    (8, "HydraGlow Hyaluronic Acid Vitamin C Serum", 7.00, 28.00, 180),
    (8, "Botanical Gentle Foaming Face Cleanser", 5.50, 22.00, 210),
    (8, "Revitalize Peptide Night Repair Cream", 12.00, 42.00, 140),
    (9, "ErgoSpine Mesh High-Back Office Chair", 115.00, 289.99, 40),
    (9, "Solid Oak Monitor Riser & Desk Organizer", 22.00, 64.99, 95),
    (9, "DeskMat Wool Felt Minimalist Desk Pad", 9.00, 29.99, 170),
    (10, "Rover 35L Water-Resistant Travel Backpack", 34.00, 94.99, 85),
    (10, "Nomad Insulated Stainless Steel Flask (32oz)", 8.50, 29.99, 210),
    (10, "CampLite Ultralight 2-Person Backpacking Tent", 78.00, 199.99, 45)
]

FIRST_NAMES = [
    "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda",
    "David", "Elizabeth", "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Nancy", "Daniel", "Lisa",
    "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra", "Donald", "Ashley",
    "Steven", "Kimberly", "Paul", "Emily", "Andrew", "Donna", "Joshua", "Michelle",
    "Kenneth", "Carol", "Kevin", "Amanda", "Brian", "Melissa", "George", "Deborah",
    "Timothy", "Stephanie", "Ronald", "Rebecca", "Edward", "Sharon", "Jason", "Laura",
    "Jeffrey", "Cynthia", "Ryan", "Kathleen", "Jacob", "Amy", "Gary", "Shirley",
    "Nicholas", "Angela", "Eric", "Helen", "Jonathan", "Anna", "Stephen", "Brenda",
    "Larry", "Pamela", "Justin", "Nicole", "Scott", "Emma", "Brandon", "Samantha",
    "Benjamin", "Katherine", "Samuel", "Christine", "Gregory", "Debra", "Alexander", "Rachel",
    "Frank", "Catherine", "Patrick", "Carolyn", "Raymond", "Janet", "Jack", "Ruth"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
    "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
    "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
    "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
    "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz", "Parker",
    "Cruz", "Edwards", "Collins", "Reyes", "Stewart", "Morris", "Morales", "Murphy",
    "Cook", "Rogers", "Gutierrez", "Ortiz", "Morgan", "Cooper", "Peterson", "Bailey"
]

CITIES_STATES = [
    ("New York", "NY", "10001"),
    ("Los Angeles", "CA", "90001"),
    ("Chicago", "IL", "60601"),
    ("Houston", "TX", "77001"),
    ("Phoenix", "AZ", "85001"),
    ("Philadelphia", "PA", "19101"),
    ("San Antonio", "TX", "78201"),
    ("San Diego", "CA", "92101"),
    ("Dallas", "TX", "75201"),
    ("Austin", "TX", "73301"),
    ("San Jose", "CA", "95101"),
    ("Seattle", "WA", "98101"),
    ("Denver", "CO", "80201"),
    ("Boston", "MA", "02101"),
    ("Atlanta", "GA", "30301"),
    ("Miami", "FL", "33101"),
    ("Nashville", "TN", "37201"),
    ("Portland", "OR", "97201"),
    ("Minneapolis", "MN", "55401"),
    ("Charlotte", "NC", "28201")
]

CHANNELS = [
    "Organic Search", "Google Ads", "Meta Ads", "Email Campaign",
    "Direct", "Affiliate", "Referral"
]
CHANNEL_WEIGHTS = [0.28, 0.22, 0.20, 0.12, 0.10, 0.05, 0.03]

ORDER_STATUSES = ["delivered", "shipped", "processing", "pending", "cancelled", "returned"]
ORDER_STATUS_WEIGHTS = [0.82, 0.05, 0.04, 0.02, 0.05, 0.02]

PAYMENT_METHODS = ["credit_card", "debit_card", "paypal", "apple_pay", "upi", "bank_transfer"]
PAYMENT_WEIGHTS = [0.45, 0.20, 0.18, 0.10, 0.05, 0.02]

POSITIVE_REVIEWS = [
    ("Exceeded Expectations!", "Absolutely stellar quality. Built to last and works seamlessly out of the box."),
    ("Top notch quality", "Remarkable attention to detail. Fast shipping and solid packaging."),
    ("Would buy again in a heartbeat", "Hands down the best purchase I made this year. High performance and sleek design."),
    ("Great value for money", "Competes with items twice the price. Very satisfied with this product."),
    ("Sturdy and reliable", "I have been using this daily for weeks now with zero complaints.")
]

NEUTRAL_REVIEWS = [
    ("Decent, does the job", "Good product overall, though a bit heavier than I anticipated."),
    ("Average performance", "Works as advertised but packaging was slightly dinged during transit."),
    ("Okay for the price", "Nothing extraordinary, but perfectly fine for daily casual use.")
]

NEGATIVE_REVIEWS = [
    ("Disappointed with build quality", "Stopped functioning after 2 weeks. Expected better durability for the price."),
    ("Not what I expected", "Colors did not match the product pictures online. Customer support was slow."),
    ("Defective on arrival", "Had to initiate a return immediately due to damaged hardware.")
]

def generate_all():
    print("Starting E-Commerce synthetic dataset generation...")
    
    # -------------------------------------------------------------------------
    # 1. Categories
    # -------------------------------------------------------------------------
    cat_file = os.path.join(DATA_DIR, "categories.csv")
    with open(cat_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["category_id", "category_name", "parent_category_id", "description"])
        for cat in CATEGORIES:
            writer.writerow([cat[0], cat[1], cat[2] if cat[2] is not None else "", cat[3]])
    print(f"  [+] Generated {len(CATEGORIES)} categories -> categories.csv")

    # -------------------------------------------------------------------------
    # 2. Products
    # -------------------------------------------------------------------------
    products = []
    prod_file = os.path.join(DATA_DIR, "products.csv")
    sku_counter = 1001
    for cat_id, name, cost, sale, stock in PRODUCT_TEMPLATES:
        sku = f"PROD-{cat_id:02d}-{sku_counter}"
        sku_counter += 1
        created_at = "2023-11-15 09:00:00+00"
        products.append({
            "product_id": len(products) + 1,
            "category_id": cat_id,
            "product_name": name,
            "sku": sku,
            "cost_price": cost,
            "sale_price": sale,
            "stock_quantity": stock,
            "is_active": "TRUE",
            "created_at": created_at
        })

    with open(prod_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["product_id", "category_id", "product_name", "sku", "cost_price", "sale_price", "stock_quantity", "is_active", "created_at"])
        for p in products:
            writer.writerow([
                p["product_id"], p["category_id"], p["product_name"], p["sku"],
                f"{p['cost_price']:.2f}", f"{p['sale_price']:.2f}", p["stock_quantity"],
                p["is_active"], p["created_at"]
            ])
    print(f"  [+] Generated {len(products)} products -> products.csv")

    # -------------------------------------------------------------------------
    # 3. Customers (1,200 Customers across a 2-year timeline)
    # -------------------------------------------------------------------------
    NUM_CUSTOMERS = 1200
    customers = []
    start_date = datetime(2024, 1, 1, 8, 0, 0)
    end_date = datetime(2025, 12, 1, 18, 0, 0)
    total_seconds = int((end_date - start_date).total_seconds())

    cust_file = os.path.join(DATA_DIR, "customers.csv")
    used_emails = set()

    for i in range(1, NUM_CUSTOMERS + 1):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        email_base = f"{fn.lower()}.{ln.lower()}{random.randint(1, 9999)}"
        domain = random.choice(["gmail.com", "yahoo.com", "outlook.com", "icloud.com", "proton.me"])
        email = f"{email_base}@{domain}"
        while email in used_emails:
            email = f"{fn.lower()}.{ln.lower()}{random.randint(10000, 99999)}@{domain}"
        used_emails.add(email)

        phone = f"+1-{random.randint(200, 999)}-{random.randint(200, 999)}-{random.randint(1000, 9999)}"
        city, state, zip_code = random.choice(CITIES_STATES)
        channel = random.choices(CHANNELS, weights=CHANNEL_WEIGHTS, k=1)[0]
        
        # Acquisition timestamp skewed towards earlier quarters to simulate mature cohorts
        offset = random.randint(0, total_seconds)
        cust_created = start_date + timedelta(seconds=offset)
        cust_created_str = cust_created.strftime("%Y-%m-%d %H:%M:%S+00")

        customers.append({
            "customer_id": i,
            "first_name": fn,
            "last_name": ln,
            "email": email,
            "phone": phone,
            "city": city,
            "state": state,
            "postal_code": zip_code,
            "country": "United States",
            "acquisition_channel": channel,
            "created_at": cust_created,
            "created_at_str": cust_created_str
        })

    with open(cust_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["customer_id", "first_name", "last_name", "email", "phone", "city", "state", "postal_code", "country", "acquisition_channel", "created_at"])
        for c in customers:
            writer.writerow([
                c["customer_id"], c["first_name"], c["last_name"], c["email"], c["phone"],
                c["city"], c["state"], c["postal_code"], c["country"], c["acquisition_channel"],
                c["created_at_str"]
            ])
    print(f"  [+] Generated {len(customers)} customers -> customers.csv")

    # -------------------------------------------------------------------------
    # 4. Orders & Order Items (Realistic multi-order frequencies)
    # -------------------------------------------------------------------------
    orders = []
    order_items = []
    payments = []
    reviews = []

    order_id_counter = 1
    item_id_counter = 1
    payment_id_counter = 1
    review_id_counter = 1

    # Frequency distribution:
    # 55% have 1 order, 25% have 2 orders, 12% have 3 orders, 5% have 4 orders, 3% have 5-7 orders
    for cust in customers:
        freq_roll = random.random()
        if freq_roll < 0.55:
            num_orders = 1
        elif freq_roll < 0.80:
            num_orders = 2
        elif freq_roll < 0.92:
            num_orders = 3
        elif freq_roll < 0.97:
            num_orders = 4
        else:
            num_orders = random.randint(5, 7)

        # Generate orders chronologically after customer acquisition
        current_time = cust["created_at"]
        for o_idx in range(num_orders):
            gap_days = random.randint(2, 60) if o_idx > 0 else random.randint(0, 14)
            order_time = current_time + timedelta(days=gap_days, hours=random.randint(1, 12), minutes=random.randint(0, 59))
            if order_time > datetime(2026, 3, 1):
                break
            current_time = order_time

            status = random.choices(ORDER_STATUSES, weights=ORDER_STATUS_WEIGHTS, k=1)[0]
            
            # Delivery date logic
            if status == "delivered":
                delivery_time = order_time + timedelta(days=random.randint(2, 6), hours=random.randint(1, 10))
                delivery_str = delivery_time.strftime("%Y-%m-%d %H:%M:%S+00")
            elif status == "returned":
                delivery_time = order_time + timedelta(days=random.randint(3, 5))
                delivery_str = delivery_time.strftime("%Y-%m-%d %H:%M:%S+00")
            else:
                delivery_str = ""

            # Order items: 1 to 4 items per order
            num_items = random.choices([1, 2, 3, 4], weights=[0.55, 0.28, 0.12, 0.05], k=1)[0]
            chosen_prods = random.sample(products, k=min(num_items, len(products)))

            subtotal = 0.0
            order_line_items = []
            for p in chosen_prods:
                qty = random.choices([1, 2, 3], weights=[0.75, 0.20, 0.05], k=1)[0]
                unit_p = p["sale_price"]
                cost_p = p["cost_price"]
                # 15% chance of item promo discount
                discount = round(unit_p * random.choice([0.05, 0.10, 0.15]), 2) if random.random() < 0.15 else 0.0
                line_total = (qty * unit_p) - discount
                subtotal += line_total

                order_line_items.append({
                    "order_item_id": item_id_counter,
                    "order_id": order_id_counter,
                    "product_id": p["product_id"],
                    "quantity": qty,
                    "unit_price": unit_p,
                    "cost_price": cost_p,
                    "item_discount": discount
                })
                item_id_counter += 1

            shipping_fee = 0.0 if subtotal > 75.0 else 5.99
            order_discount = round(subtotal * 0.10, 2) if random.random() < 0.08 else 0.0
            total_amount = max(0.0, round(subtotal + shipping_fee - order_discount, 2))

            orders.append({
                "order_id": order_id_counter,
                "customer_id": cust["customer_id"],
                "order_date": order_time.strftime("%Y-%m-%d %H:%M:%S+00"),
                "order_status": status,
                "subtotal_amount": round(subtotal, 2),
                "shipping_fee": shipping_fee,
                "discount_amount": order_discount,
                "total_amount": total_amount,
                "shipping_city": cust["city"],
                "shipping_state": cust["state"],
                "shipping_postal_code": cust["postal_code"],
                "delivery_date": delivery_str
            })
            order_items.extend(order_line_items)

            # -----------------------------------------------------------------
            # Payment Record
            # -----------------------------------------------------------------
            pay_method = random.choices(PAYMENT_METHODS, weights=PAYMENT_WEIGHTS, k=1)[0]
            if status in ["delivered", "shipped", "processing"]:
                pay_status = "completed"
            elif status == "pending":
                pay_status = "pending"
            elif status == "cancelled":
                pay_status = "refunded" if random.random() < 0.70 else "failed"
            elif status == "returned":
                pay_status = "refunded"
            else:
                pay_status = "completed"

            payments.append({
                "payment_id": payment_id_counter,
                "order_id": order_id_counter,
                "payment_method": pay_method,
                "payment_status": pay_status,
                "amount": total_amount,
                "transaction_timestamp": order_time.strftime("%Y-%m-%d %H:%M:%S+00"),
                "gateway_transaction_id": f"TXN-{uuid.uuid4().hex[:12].upper()}"
            })
            payment_id_counter += 1

            # -----------------------------------------------------------------
            # Reviews (for delivered items, ~35% write reviews)
            # -----------------------------------------------------------------
            if status == "delivered" and random.random() < 0.35:
                reviewed_item = random.choice(order_line_items)
                rating_roll = random.random()
                if rating_roll < 0.72:
                    rating = random.choice([4, 5])
                    title, text = random.choice(POSITIVE_REVIEWS)
                elif rating_roll < 0.88:
                    rating = 3
                    title, text = random.choice(NEUTRAL_REVIEWS)
                else:
                    rating = random.choice([1, 2])
                    title, text = random.choice(NEGATIVE_REVIEWS)

                review_time = datetime.strptime(delivery_str[:19], "%Y-%m-%d %H:%M:%S") + timedelta(days=random.randint(1, 14))
                reviews.append({
                    "review_id": review_id_counter,
                    "customer_id": cust["customer_id"],
                    "product_id": reviewed_item["product_id"],
                    "order_id": order_id_counter,
                    "rating": rating,
                    "review_title": title,
                    "review_text": text,
                    "is_verified_purchase": "TRUE",
                    "created_at": review_time.strftime("%Y-%m-%d %H:%M:%S+00")
                })
                review_id_counter += 1

            order_id_counter += 1

    # Write orders.csv
    orders_file = os.path.join(DATA_DIR, "orders.csv")
    with open(orders_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["order_id", "customer_id", "order_date", "order_status", "subtotal_amount", "shipping_fee", "discount_amount", "total_amount", "shipping_city", "shipping_state", "shipping_postal_code", "delivery_date"])
        for o in orders:
            writer.writerow([
                o["order_id"], o["customer_id"], o["order_date"], o["order_status"],
                f"{o['subtotal_amount']:.2f}", f"{o['shipping_fee']:.2f}", f"{o['discount_amount']:.2f}",
                f"{o['total_amount']:.2f}", o["shipping_city"], o["shipping_state"],
                o["shipping_postal_code"], o["delivery_date"]
            ])
    print(f"  [+] Generated {len(orders)} orders -> orders.csv")

    # Write order_items.csv
    items_file = os.path.join(DATA_DIR, "order_items.csv")
    with open(items_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["order_item_id", "order_id", "product_id", "quantity", "unit_price", "cost_price", "item_discount"])
        for oi in order_items:
            writer.writerow([
                oi["order_item_id"], oi["order_id"], oi["product_id"], oi["quantity"],
                f"{oi['unit_price']:.2f}", f"{oi['cost_price']:.2f}", f"{oi['item_discount']:.2f}"
            ])
    print(f"  [+] Generated {len(order_items)} order items -> order_items.csv")

    # Write payments.csv
    pay_file = os.path.join(DATA_DIR, "payments.csv")
    with open(pay_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["payment_id", "order_id", "payment_method", "payment_status", "amount", "transaction_timestamp", "gateway_transaction_id"])
        for p in payments:
            writer.writerow([
                p["payment_id"], p["order_id"], p["payment_method"], p["payment_status"],
                f"{p['amount']:.2f}", p["transaction_timestamp"], p["gateway_transaction_id"]
            ])
    print(f"  [+] Generated {len(payments)} payments -> payments.csv")

    # Write reviews.csv
    rev_file = os.path.join(DATA_DIR, "reviews.csv")
    with open(rev_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["review_id", "customer_id", "product_id", "order_id", "rating", "review_title", "review_text", "is_verified_purchase", "created_at"])
        for r in reviews:
            writer.writerow([
                r["review_id"], r["customer_id"], r["product_id"], r["order_id"],
                r["rating"], r["review_title"], r["review_text"], r["is_verified_purchase"],
                r["created_at"]
            ])
    print(f"  [+] Generated {len(reviews)} reviews -> reviews.csv")
    print("\nAll synthetic datasets created successfully!")

if __name__ == "__main__":
    generate_all()
