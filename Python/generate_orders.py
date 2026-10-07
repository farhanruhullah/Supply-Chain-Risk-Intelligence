from pathlib import Path
import random
from datetime import timedelta

import numpy as np
import pandas as pd


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42
ORDER_COUNT = 100_000

random.seed(SEED)
np.random.seed(SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

START_DATE = pd.Timestamp("2022-01-01")
END_DATE = pd.Timestamp("2026-09-30")


# ============================================================
# LOAD MASTER DATA
# ============================================================

suppliers = pd.read_csv(
    RAW_DIR / "suppliers.csv"
)

products = pd.read_csv(
    RAW_DIR / "products.csv"
)

warehouses = pd.read_csv(
    RAW_DIR / "warehouses.csv"
)


print("Master data loaded successfully.")

print(f"Suppliers: {len(suppliers):,}")
print(f"Products: {len(products):,}")
print(f"Warehouses: {len(warehouses):,}")


# ============================================================
# PREPARE SUPPLIER / PRODUCT RELATIONSHIPS
# ============================================================

supplier_categories = (
    suppliers
    .groupby("SupplierCategory")["SupplierID"]
    .apply(list)
    .to_dict()
)


# Map product categories to compatible supplier categories
category_supplier_map = {

    "Industrial Equipment": [
        "Industrial Equipment",
        "Mechanical Components"
    ],

    "Electronic Components": [
        "Electronic Components",
        "Electrical Components"
    ],

    "Mechanical Components": [
        "Mechanical Components",
        "Raw Materials"
    ],

    "Electrical Components": [
        "Electrical Components",
        "Electronic Components"
    ],

    "Raw Materials": [
        "Raw Materials",
        "Chemicals"
    ],

    "Packaging": [
        "Packaging",
        "Raw Materials"
    ],
}


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def random_date(start_date, end_date):

    total_days = (
        end_date - start_date
    ).days

    random_days = random.randint(
        0,
        total_days
    )

    return start_date + timedelta(
        days=random_days
    )


def choose_supplier(product_category):

    valid_categories = category_supplier_map.get(
        product_category,
        list(supplier_categories.keys())
    )

    available_suppliers = []

    for category in valid_categories:

        available_suppliers.extend(
            supplier_categories.get(
                category,
                []
            )
        )

    if not available_suppliers:

        return random.choice(
            suppliers["SupplierID"].tolist()
        )

    return random.choice(
        available_suppliers
    )


def generate_quantity():

    # Creates more realistic order-size distribution

    probability = random.random()

    if probability < 0.50:

        return random.randint(
            10,
            100
        )

    elif probability < 0.80:

        return random.randint(
            101,
            500
        )

    elif probability < 0.95:

        return random.randint(
            501,
            1500
        )

    else:

        return random.randint(
            1501,
            5000
        )


# ============================================================
# CREATE PRODUCT LOOKUP
# ============================================================

product_lookup = products.set_index(
    "ProductID"
).to_dict("index")


warehouse_ids = warehouses[
    "WarehouseID"
].tolist()

product_ids = products[
    "ProductID"
].tolist()


# ============================================================
# GENERATE ORDERS
# ============================================================

orders = []

print("\nGenerating purchase orders...")


for i in range(1, ORDER_COUNT + 1):

    product_id = random.choice(
        product_ids
    )

    product = product_lookup[
        product_id
    ]

    supplier_id = choose_supplier(
        product["Category"]
    )

    warehouse_id = random.choice(
        warehouse_ids
    )

    order_date = random_date(
        START_DATE,
        END_DATE
    )

    lead_time = int(
        product["LeadTimeDays"]
    )

    # Small buffer added to expected delivery
    expected_delivery_date = (
        order_date
        + timedelta(
            days=lead_time
            + random.randint(0, 5)
        )
    )

    quantity = generate_quantity()

    base_unit_cost = float(
        product["UnitCost"]
    )

    # Simulate supplier price variation
    price_variation = np.random.normal(
        loc=1.0,
        scale=0.04
    )

    price_variation = np.clip(
        price_variation,
        0.85,
        1.20
    )

    unit_cost = round(
        base_unit_cost
        * price_variation,
        2
    )

    order_value = round(
        quantity * unit_cost,
        2
    )

    # Older orders are mostly completed.
    # Recent orders may still be processing.
    days_from_end = (
        END_DATE - order_date
    ).days

    if days_from_end > 60:

        order_status = random.choices(
            [
                "Completed",
                "Cancelled"
            ],
            weights=[
                98,
                2
            ]
        )[0]

    else:

        order_status = random.choices(
            [
                "Completed",
                "Processing",
                "Pending",
                "Cancelled"
            ],
            weights=[
                70,
                15,
                12,
                3
            ]
        )[0]

    orders.append({

        "OrderID":
            f"ORD{i:07d}",

        "SupplierID":
            supplier_id,

        "ProductID":
            product_id,

        "WarehouseID":
            warehouse_id,

        "OrderDate":
            order_date.date(),

        "ExpectedDeliveryDate":
            expected_delivery_date.date(),

        "OrderQuantity":
            quantity,

        "UnitCost":
            unit_cost,

        "OrderValue":
            order_value,

        "OrderStatus":
            order_status
    })


# ============================================================
# CREATE DATAFRAME
# ============================================================

orders_df = pd.DataFrame(
    orders
)


# ============================================================
# SORT DATA
# ============================================================

orders_df = orders_df.sort_values(
    "OrderDate"
).reset_index(
    drop=True
)


# ============================================================
# SAVE CSV
# ============================================================

output_file = (
    RAW_DIR
    / "orders.csv"
)

orders_df.to_csv(
    output_file,
    index=False
)


# ============================================================
# VALIDATION
# ============================================================

print("\nOrder generation completed.")

print(
    f"Orders generated: "
    f"{len(orders_df):,}"
)

print(
    f"Total purchase value: "
    f"${orders_df['OrderValue'].sum():,.2f}"
)

print(
    f"Average order value: "
    f"${orders_df['OrderValue'].mean():,.2f}"
)

print(
    "\nOrder Status:"
)

print(
    orders_df[
        "OrderStatus"
    ].value_counts()
)

print(
    "\nDate range:"
)

print(
    orders_df[
        "OrderDate"
    ].min(),
    "to",
    orders_df[
        "OrderDate"
    ].max()
)

print(
    f"\nSaved to:\n"
    f"{output_file}"
)


# ============================================================
# DATA QUALITY CHECK
# ============================================================

print(
    "\nMissing values:"
)

print(
    orders_df.isnull().sum()
)

print(
    "\nDuplicate Order IDs:"
)

print(
    orders_df[
        "OrderID"
    ].duplicated().sum()
)