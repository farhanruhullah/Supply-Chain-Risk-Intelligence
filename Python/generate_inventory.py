from pathlib import Path
import random

import numpy as np
import pandas as pd


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42
INVENTORY_RECORDS = 200_000

random.seed(SEED)
np.random.seed(SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"


# ============================================================
# LOAD DATA
# ============================================================

products = pd.read_csv(
    RAW_DIR / "products.csv"
)

warehouses = pd.read_csv(
    RAW_DIR / "warehouses.csv"
)

orders = pd.read_csv(
    RAW_DIR / "orders.csv",
    parse_dates=["OrderDate"]
)


print("Source data loaded successfully.")

print(f"Products: {len(products):,}")
print(f"Warehouses: {len(warehouses):,}")
print(f"Orders: {len(orders):,}")


# ============================================================
# CALCULATE PRODUCT DEMAND
# ============================================================

order_start = orders["OrderDate"].min()
order_end = orders["OrderDate"].max()

total_days = max(
    1,
    (order_end - order_start).days
)


product_demand = (
    orders
    .groupby("ProductID")["OrderQuantity"]
    .sum()
    .div(total_days)
    .to_dict()
)


# Default demand if a product has little/no order history
default_daily_demand = (
    orders["OrderQuantity"].sum()
    / total_days
    / len(products)
)


# ============================================================
# LOOKUPS
# ============================================================

product_lookup = (
    products
    .set_index("ProductID")
    .to_dict("index")
)

warehouse_lookup = (
    warehouses
    .set_index("WarehouseID")
    .to_dict("index")
)


product_ids = products["ProductID"].tolist()
warehouse_ids = warehouses["WarehouseID"].tolist()


# ============================================================
# HISTORICAL SNAPSHOT DATES
# ============================================================

snapshot_dates = pd.date_range(
    start="2022-01-31",
    end="2026-09-30",
    freq="ME"
)

print(
    f"Inventory snapshot dates: "
    f"{len(snapshot_dates)}"
)


# ============================================================
# CREATE UNIQUE PRODUCT-WAREHOUSE-DATE COMBINATIONS
# ============================================================

number_products = len(product_ids)
number_warehouses = len(warehouse_ids)
number_dates = len(snapshot_dates)

total_possible = (
    number_products
    * number_warehouses
    * number_dates
)


selected_indices = np.random.choice(
    total_possible,
    size=INVENTORY_RECORDS,
    replace=False
)


# ============================================================
# GENERATE INVENTORY RECORDS
# ============================================================

inventory_records = []

print("\nGenerating inventory records...")


for record_number, index_value in enumerate(
    selected_indices,
    start=1
):

    date_index = (
        index_value
        // (
            number_products
            * number_warehouses
        )
    )

    remainder = (
        index_value
        % (
            number_products
            * number_warehouses
        )
    )

    product_index = (
        remainder
        // number_warehouses
    )

    warehouse_index = (
        remainder
        % number_warehouses
    )


    product_id = product_ids[
        product_index
    ]

    warehouse_id = warehouse_ids[
        warehouse_index
    ]

    snapshot_date = snapshot_dates[
        date_index
    ]


    product = product_lookup[
        product_id
    ]


    reorder_level = int(
        product["ReorderLevel"]
    )

    safety_stock = int(
        product["SafetyStockLevel"]
    )

    unit_cost = float(
        product["UnitCost"]
    )


    daily_demand = product_demand.get(
        product_id,
        default_daily_demand
    )


    # ========================================================
    # STOCK BEHAVIOUR
    # ========================================================

    stock_scenario = random.choices(
        [
            "Normal",
            "Low",
            "Critical",
            "Stockout",
            "Overstock"
        ],
        weights=[
            62,
            15,
            8,
            3,
            12
        ]
    )[0]


    if stock_scenario == "Stockout":

        current_stock = 0


    elif stock_scenario == "Critical":

        upper_limit = max(
            1,
            safety_stock - 1
        )

        current_stock = random.randint(
            1,
            upper_limit
        )


    elif stock_scenario == "Low":

        low_limit = max(
            safety_stock,
            1
        )

        high_limit = max(
            low_limit,
            reorder_level - 1
        )

        current_stock = random.randint(
            low_limit,
            high_limit
        )


    elif stock_scenario == "Overstock":

        current_stock = random.randint(
            max(
                reorder_level * 3,
                reorder_level + 1
            ),
            max(
                reorder_level * 7,
                reorder_level + 10
            )
        )


    else:

        current_stock = random.randint(
            max(
                reorder_level,
                1
            ),
            max(
                reorder_level * 3,
                reorder_level + 10
            )
        )


    # ========================================================
    # RESERVED / AVAILABLE STOCK
    # ========================================================

    if current_stock == 0:

        reserved_stock = 0

    else:

        reserved_stock = int(
            current_stock
            * np.random.uniform(
                0.02,
                0.25
            )
        )


    available_stock = max(
        0,
        current_stock
        - reserved_stock
    )


    # ========================================================
    # INVENTORY VALUE
    # ========================================================

    inventory_value = round(
        current_stock
        * unit_cost,
        2
    )


    # ========================================================
    # STOCK COVERAGE
    # ========================================================

    if daily_demand > 0:

        stock_coverage_days = round(
            available_stock
            / daily_demand,
            1
        )

    else:

        stock_coverage_days = 999


    # ========================================================
    # RISK STATUS
    # ========================================================

    if available_stock == 0:

        risk_status = "Stockout"


    elif available_stock < safety_stock:

        risk_status = "Critical"


    elif available_stock < reorder_level:

        risk_status = "Reorder Required"


    elif available_stock > (
        reorder_level * 3
    ):

        risk_status = "Overstock"


    else:

        risk_status = "Safe"


    inventory_records.append({

        "InventoryRecordID":
            f"INV{record_number:07d}",

        "ProductID":
            product_id,

        "WarehouseID":
            warehouse_id,

        "SnapshotDate":
            snapshot_date.date(),

        "CurrentStock":
            current_stock,

        "ReservedStock":
            reserved_stock,

        "AvailableStock":
            available_stock,

        "ReorderLevel":
            reorder_level,

        "SafetyStockLevel":
            safety_stock,

        "AvgDailyDemand":
            round(
                daily_demand,
                2
            ),

        "StockCoverageDays":
            stock_coverage_days,

        "InventoryValue":
            inventory_value,

        "RiskStatus":
            risk_status
    })


# ============================================================
# CREATE DATAFRAME
# ============================================================

inventory_df = pd.DataFrame(
    inventory_records
)


# ============================================================
# WAREHOUSE UTILIZATION
# ============================================================

warehouse_capacity = warehouses[
    [
        "WarehouseID",
        "Capacity"
    ]
].copy()


warehouse_stock = (
    inventory_df
    .groupby(
        [
            "WarehouseID",
            "SnapshotDate"
        ]
    )["CurrentStock"]
    .sum()
    .reset_index(
        name="TotalWarehouseStock"
    )
)


warehouse_stock = warehouse_stock.merge(
    warehouse_capacity,
    on="WarehouseID",
    how="left"
)


warehouse_stock[
    "WarehouseUtilizationPct"
] = np.minimum(
    100,
    (
        warehouse_stock[
            "TotalWarehouseStock"
        ]
        /
        warehouse_stock[
            "Capacity"
        ]
        * 100
    )
).round(2)


inventory_df = inventory_df.merge(
    warehouse_stock[
        [
            "WarehouseID",
            "SnapshotDate",
            "WarehouseUtilizationPct"
        ]
    ],
    on=[
        "WarehouseID",
        "SnapshotDate"
    ],
    how="left"
)


# ============================================================
# SORT DATA
# ============================================================

inventory_df = inventory_df.sort_values(
    [
        "SnapshotDate",
        "WarehouseID",
        "ProductID"
    ]
).reset_index(
    drop=True
)


# ============================================================
# SAVE CSV
# ============================================================

output_file = (
    RAW_DIR
    / "inventory.csv"
)


inventory_df.to_csv(
    output_file,
    index=False
)


# ============================================================
# VALIDATION
# ============================================================

print("\nInventory generation completed.")

print(
    f"Inventory records: "
    f"{len(inventory_df):,}"
)


print("\nInventory Risk Distribution:")

print(
    inventory_df[
        "RiskStatus"
    ].value_counts()
)


print(
    "\nAverage warehouse utilization:"
)

print(
    f"{inventory_df['WarehouseUtilizationPct'].mean():.2f}%"
)


print(
    "\nTotal inventory value:"
)

print(
    f"${inventory_df['InventoryValue'].sum():,.2f}"
)


print(
    "\nAverage stock coverage:"
)

print(
    f"{inventory_df['StockCoverageDays'].mean():.2f} days"
)


print("\nMissing values:")

print(
    inventory_df.isnull().sum()
)


print(
    "\nDuplicate Product/Warehouse/Date:"
)

duplicates = inventory_df.duplicated(
    subset=[
        "ProductID",
        "WarehouseID",
        "SnapshotDate"
    ]
).sum()

print(duplicates)


print(
    f"\nSaved to:\n{output_file}"
)