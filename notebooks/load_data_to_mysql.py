"""
ETL Script: Load cleaned CSV data into MySQL

Features:
- Environment variable validation
- Chunked inserts (scalable)
- Duplicate handling (ON DUPLICATE KEY UPDATE)
- Missing value handling
- Transaction safety (commit/rollback)
- Logging + execution time tracking
"""

import pandas as pd
import pymysql
import os
from pathlib import Path
from dotenv import load_dotenv
import logging
import time

# ⏱️ Start timer
start = time.time()

# ---------------- ENV SETUP ----------------
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

required_vars = ["DB_HOST", "DB_USER", "DB_PASS", "DB_NAME"]

for var in required_vars:
    if not os.getenv(var):
        raise ValueError(f"❌ Missing environment variable: {var}")

# ---------------- DB CONNECTION ----------------
conn = pymysql.connect(
    host=os.getenv("DB_HOST"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASS"),
    database=os.getenv("DB_NAME"),
    port=int(os.getenv("DB_PORT", 3306)),
    charset="utf8mb4",
    cursorclass=pymysql.cursors.Cursor
)

print("✅ Connected to MySQL successfully")

cursor = conn.cursor()

# ---------------- LOGGING ----------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# ---------------- READ CSVs ----------------
customers = pd.read_csv(os.path.join(BASE_DIR, "data/cleaned/customers.csv"))
orders = pd.read_csv(os.path.join(BASE_DIR, "data/cleaned/orders.csv"))
order_items = pd.read_csv(os.path.join(BASE_DIR, "data/cleaned/order_items.csv"))

# Filter invalid order_ids
valid_order_ids = set(orders["order_id"])
order_items = order_items[order_items["order_id"].isin(valid_order_ids)]

payments = pd.read_csv(os.path.join(BASE_DIR, "data/cleaned/payments.csv"))
payments = payments[payments["order_id"].isin(valid_order_ids)]

products = pd.read_csv(os.path.join(BASE_DIR, "data/cleaned/products.csv"))

# ---------------- CLEAN NaN ----------------
def clean_df(df):
    return df.astype(object).where(pd.notnull(df), None)

customers = clean_df(customers)
orders = clean_df(orders)
order_items = clean_df(order_items)
payments = clean_df(payments)
products = clean_df(products)

# ---------------- INSERT FUNCTION ----------------
def insert_dataframe(df, table, chunk_size=1000):
    if df.empty:
        logging.warning(f"{table} is empty, skipping...")
        return

    cols = ", ".join([f"`{col}`" for col in df.columns])
    placeholders = ", ".join(["%s"] * len(df.columns))

    sql = f"""
    INSERT INTO {table} ({cols})
    VALUES ({placeholders})
    ON DUPLICATE KEY UPDATE
    {', '.join([f"{col}=VALUES({col})" for col in df.columns])}
    """

    for i in range(0, len(df), chunk_size):
        chunk = df.iloc[i:i+chunk_size]

        chunk = chunk.astype(object).where(pd.notnull(chunk), None)

        logging.info(f"{table}: inserting rows {i} to {i + len(chunk)}")

        try:
            cursor.executemany(sql, chunk.values.tolist())
        except Exception as e:
            logging.error(f"❌ Error inserting into {table} at chunk {i}: {e}")
            raise

    logging.info(f"✅ {table}: {len(df)} rows inserted successfully")


# ---------------- LOAD DATA ----------------
# Order matters due to foreign keys:
# customers → orders → order_items → payments → products

def main():
    try:
        insert_dataframe(customers, "customers")
        insert_dataframe(orders, "orders")
        insert_dataframe(order_items, "order_items")
        insert_dataframe(payments, "payments")
        insert_dataframe(products, "products")

        conn.commit()
        print("✅ Data loading completed")

        # 🔥 Validation (Interview booster)
        cursor.execute("SELECT COUNT(*) FROM customers")
        print("Customers in DB:", cursor.fetchone()[0])

    except Exception as e:
        conn.rollback()
        print(f"❌ Error occurred: {e}")

    finally:
        cursor.close()
        conn.close()
        print(f"⏱️ Total time: {time.time() - start:.2f} seconds")


# ---------------- RUN SCRIPT ----------------
if __name__ == "__main__":
    main()