import pandas as pd
import pymysql
import numpy as np

conn = pymysql.connect(
    host="localhost",
    user="root",
    password="root",
    database="ecommerce_bi",
    autocommit=True
)

cursor = conn.cursor()

# ---------- READ CSVs ----------
customers = pd.read_csv("../data/cleaned/customers.csv")
orders = pd.read_csv("../data/cleaned/orders.csv")
order_items = pd.read_csv("../data/cleaned/order_items.csv")
payments = pd.read_csv("../data/cleaned/payments.csv")
products = pd.read_csv("../data/cleaned/products.csv")

# ---------- FIX NaN ----------
customers = customers.replace({np.nan: None})
orders = orders.replace({np.nan: None})
order_items = order_items.replace({np.nan: None})
payments = payments.replace({np.nan: None})
products = products.replace({np.nan: None})

# ---------- INSERT FUNCTION ----------
def insert_dataframe(df, table):
    cols = ", ".join(df.columns)
    placeholders = ", ".join(["%s"] * len(df.columns))
    sql = f"INSERT INTO {table} ({cols}) VALUES ({placeholders})"
    cursor.executemany(sql, df.values.tolist())
    print(f"{table} loaded successfully")

# ---------- LOAD ----------
insert_dataframe(customers, "customers")
insert_dataframe(orders, "orders")
insert_dataframe(order_items, "order_items")
insert_dataframe(payments, "payments")
insert_dataframe(products, "products")

cursor.close()
conn.close()