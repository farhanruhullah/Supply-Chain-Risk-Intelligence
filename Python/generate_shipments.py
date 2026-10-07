from pathlib import Path
import random
from datetime import timedelta

import numpy as np
import pandas as pd


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42

random.seed(SEED)
np.random.seed(SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"


# ============================================================
# LOAD DATA
# ============================================================

orders = pd.read_csv(
    RAW_DIR / "orders.csv",
    parse_dates=["OrderDate", "ExpectedDeliveryDate"]
)

suppliers = pd.read_csv(
    RAW_DIR / "suppliers.csv"
)

carriers = pd.read_csv(
    RAW_DIR / "carriers.csv"
)


print("Source data loaded successfully.")

print(f"Orders: {len(orders):,}")
print(f"Suppliers: {len(suppliers):,}")
print(f"Carriers: {len(carriers):,}")


# ============================================================
# CREATE SUPPLIER PERFORMANCE PROFILE
# ============================================================

supplier_profiles = {}

for _, row in suppliers.iterrows():

    quality = float(row["QualityRating"])

    # Higher quality suppliers tend to have better reliability
    reliability = np.clip(
        np.random.normal(
            loc=quality / 100,
            scale=0.05
        ),
        0.55,
        0.99
    )

    supplier_profiles[row["SupplierID"]] = {
        "quality": quality,
        "reliability": reliability
    }


# ============================================================
# CREATE CARRIER PERFORMANCE PROFILE
# ============================================================

carrier_profiles = {}

for _, row in carriers.iterrows():

    service_level = row["ServiceLevel"]

    if service_level == "Priority":
        reliability = np.random.uniform(0.91, 0.98)
        cost_multiplier = np.random.uniform(1.35, 1.60)

    elif service_level == "Express":
        reliability = np.random.uniform(0.88, 0.96)
        cost_multiplier = np.random.uniform(1.20, 1.45)

    elif service_level == "Standard":
        reliability = np.random.uniform(0.80, 0.92)
        cost_multiplier = np.random.uniform(0.90, 1.15)

    else:
        reliability = np.random.uniform(0.72, 0.88)
        cost_multiplier = np.random.uniform(0.70, 0.95)

    carrier_profiles[row["CarrierID"]] = {
        "reliability": reliability,
        "cost_multiplier": cost_multiplier
    }


carrier_ids = carriers["CarrierID"].tolist()


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_delay_days(
    supplier_reliability,
    carrier_reliability
):

    combined_reliability = (
        supplier_reliability * 0.65
        + carrier_reliability * 0.35
    )

    random_value = random.random()

    # Good suppliers/carriers usually arrive on time
    if random_value < combined_reliability:

        return random.choice([
            -2,
            -1,
            0,
            0,
            0,
            0,
            1
        ])

    # Late shipments
    late_probability = random.random()

    if late_probability < 0.55:
        return random.randint(1, 3)

    elif late_probability < 0.85:
        return random.randint(4, 7)

    elif late_probability < 0.97:
        return random.randint(8, 14)

    else:
        return random.randint(15, 30)


def generate_quality_score(
    supplier_quality
):

    score = np.random.normal(
        loc=supplier_quality,
        scale=4
    )

    return round(
        np.clip(score, 55, 100),
        2
    )


def generate_damage_quantity(
    shipped_quantity,
    quality_score
):

    defect_rate = max(
        0,
        (100 - quality_score) / 100
    )

    expected_damage = (
        shipped_quantity
        * defect_rate
        * np.random.uniform(0.05, 0.25)
    )

    damage = int(
        round(expected_damage)
    )

    return min(
        damage,
        shipped_quantity
    )


# ============================================================
# GENERATE SHIPMENTS
# ============================================================

shipments = []

print("\nGenerating shipment data...")


completed_orders = orders[
    orders["OrderStatus"] == "Completed"
].copy()


for i, (_, order) in enumerate(
    completed_orders.iterrows(),
    start=1
):

    supplier_id = order["SupplierID"]

    supplier_profile = supplier_profiles[
        supplier_id
    ]

    carrier_id = random.choice(
        carrier_ids
    )

    carrier_profile = carrier_profiles[
        carrier_id
    ]

    order_date = order["OrderDate"]

    promised_date = order[
        "ExpectedDeliveryDate"
    ]

    # Shipment usually leaves 1-5 days after order date
    ship_date = (
        order_date
        + timedelta(
            days=random.randint(1, 5)
        )
    )

    delay_days = calculate_delay_days(
        supplier_profile["reliability"],
        carrier_profile["reliability"]
    )

    delivery_date = (
        promised_date
        + timedelta(
            days=int(delay_days)
        )
    )

    # Ensure delivery cannot occur before shipment
    if delivery_date < ship_date:
        delivery_date = ship_date

    delivery_days = (
        delivery_date - ship_date
    ).days

    quantity_ordered = int(
        order["OrderQuantity"]
    )

    quantity_shipped = random.choices(
        [
            quantity_ordered,
            max(
                1,
                int(quantity_ordered * 0.95)
            ),
            max(
                1,
                int(quantity_ordered * 0.90)
            )
        ],
        weights=[
            94,
            4,
            2
        ]
    )[0]

    quality_score = generate_quality_score(
        supplier_profile["quality"]
    )

    damaged_quantity = generate_damage_quantity(
        quantity_shipped,
        quality_score
    )

    # Shipping cost depends partly on shipment size
    base_shipping_cost = (
        quantity_shipped
        * random.uniform(1.5, 8.0)
    )

    shipping_cost = round(
        base_shipping_cost
        * carrier_profile["cost_multiplier"],
        2
    )

    if delay_days <= 0:
        shipment_status = "On Time"

    elif delay_days <= 3:
        shipment_status = "Minor Delay"

    elif delay_days <= 7:
        shipment_status = "Moderate Delay"

    else:
        shipment_status = "Severe Delay"

    shipments.append({

        "ShipmentID":
            f"SHP{i:07d}",

        "OrderID":
            order["OrderID"],

        "SupplierID":
            supplier_id,

        "ProductID":
            order["ProductID"],

        "WarehouseID":
            order["WarehouseID"],

        "CarrierID":
            carrier_id,

        "ShipDate":
            ship_date.date(),

        "PromisedDate":
            promised_date.date(),

        "DeliveryDate":
            delivery_date.date(),

        "QuantityShipped":
            quantity_shipped,

        "ShippingCost":
            shipping_cost,

        "QualityScore":
            quality_score,

        "DamagedQuantity":
            damaged_quantity,

        "DeliveryDays":
            delivery_days,

        "DelayDays":
            delay_days,

        "ShipmentStatus":
            shipment_status
    })


# ============================================================
# CREATE DATAFRAME
# ============================================================

shipments_df = pd.DataFrame(
    shipments
)


# ============================================================
# SAVE FILE
# ============================================================

output_file = (
    RAW_DIR
    / "shipments.csv"
)

shipments_df.to_csv(
    output_file,
    index=False
)


# ============================================================
# VALIDATION
# ============================================================

print("\nShipment generation completed.")

print(
    f"Shipments generated: "
    f"{len(shipments_df):,}"
)

print("\nShipment status:")

print(
    shipments_df[
        "ShipmentStatus"
    ].value_counts()
)

on_time_pct = (
    shipments_df[
        "DelayDays"
    ].le(0).mean()
    * 100
)

print(
    f"\nOn-Time Delivery %: "
    f"{on_time_pct:.2f}%"
)

print(
    f"Average Delay Days: "
    f"{shipments_df['DelayDays'].mean():.2f}"
)

print(
    f"Average Shipping Cost: "
    f"${shipments_df['ShippingCost'].mean():,.2f}"
)

print(
    f"Total Shipping Cost: "
    f"${shipments_df['ShippingCost'].sum():,.2f}"
)

print(
    "\nMissing values:"
)

print(
    shipments_df.isnull().sum()
)

print(
    "\nDuplicate Shipment IDs:"
)

print(
    shipments_df[
        "ShipmentID"
    ].duplicated().sum()
)

print(
    f"\nSaved to:\n{output_file}"
)