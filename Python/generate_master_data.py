from pathlib import Path
import random

import numpy as np
import pandas as pd
from faker import Faker


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

SEED = 42

random.seed(SEED)
np.random.seed(SEED)

fake = Faker()
Faker.seed(SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BASE_DIR / "data" / "raw"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ------------------------------------------------------------
# BUSINESS REFERENCE DATA
# ------------------------------------------------------------

countries = [
    ("China", "Asia"),
    ("India", "Asia"),
    ("Bangladesh", "Asia"),
    ("Vietnam", "Asia"),
    ("Japan", "Asia"),
    ("South Korea", "Asia"),
    ("Singapore", "Asia"),
    ("Malaysia", "Asia"),
    ("Thailand", "Asia"),
    ("Indonesia", "Asia"),

    ("Germany", "Europe"),
    ("France", "Europe"),
    ("Italy", "Europe"),
    ("Netherlands", "Europe"),
    ("Poland", "Europe"),
    ("Spain", "Europe"),
    ("United Kingdom", "Europe"),

    ("United States", "North America"),
    ("Canada", "North America"),
    ("Mexico", "North America"),

    ("Brazil", "South America"),
    ("Argentina", "South America"),

    ("UAE", "Middle East"),
    ("Saudi Arabia", "Middle East"),
    ("Turkey", "Middle East"),

    ("South Africa", "Africa"),
    ("Egypt", "Africa"),

    ("Australia", "Oceania"),
]

supplier_categories = [
    "Raw Materials",
    "Electronic Components",
    "Mechanical Components",
    "Packaging",
    "Industrial Equipment",
    "Chemicals",
    "Electrical Components",
    "Automotive Parts",
]

product_categories = {
    "Industrial Equipment": [
        "Industrial Motor",
        "Pump",
        "Compressor",
        "Generator",
        "Hydraulic System",
    ],

    "Electronic Components": [
        "Industrial Sensor",
        "Controller",
        "Circuit Board",
        "Power Module",
        "Relay",
    ],

    "Mechanical Components": [
        "Bearing",
        "Gear",
        "Shaft",
        "Valve",
        "Coupling",
    ],

    "Electrical Components": [
        "Transformer",
        "Switchgear",
        "Cable",
        "Connector",
        "Circuit Breaker",
    ],

    "Raw Materials": [
        "Steel",
        "Aluminium",
        "Copper",
        "Polymer",
        "Industrial Rubber",
    ],

    "Packaging": [
        "Industrial Box",
        "Pallet",
        "Protective Foam",
        "Container",
        "Packaging Film",
    ],
}

warehouse_types = [
    "Regional Distribution Center",
    "Central Warehouse",
    "Manufacturing Warehouse",
    "Fulfilment Center",
]

carrier_types = [
    "Air Freight",
    "Ocean Freight",
    "Road Freight",
    "Rail Freight",
    "Integrated Logistics",
]

service_levels = [
    "Standard",
    "Express",
    "Economy",
    "Priority",
]


# ------------------------------------------------------------
# SUPPLIER GENERATION
# ------------------------------------------------------------

def generate_suppliers(n=500):

    data = []

    for i in range(1, n + 1):

        country, region = random.choice(countries)

        supplier_since = fake.date_between(
            start_date="-20y",
            end_date="-1y"
        )

        quality_rating = round(
            np.clip(
                np.random.normal(88, 7),
                60,
                100
            ),
            2
        )

        if quality_rating >= 94:
            risk_tier = "Low"

        elif quality_rating >= 86:
            risk_tier = "Medium"

        elif quality_rating >= 75:
            risk_tier = "High"

        else:
            risk_tier = "Critical"

        active_status = random.choices(
            ["Active", "Inactive"],
            weights=[95, 5]
        )[0]

        data.append({
            "SupplierID": f"SUP{i:04d}",
            "SupplierName": fake.company(),
            "Country": country,
            "Region": region,
            "SupplierCategory": random.choice(
                supplier_categories
            ),
            "SupplierSince": supplier_since,
            "QualityRating": quality_rating,
            "RiskTier": risk_tier,
            "ActiveStatus": active_status,
        })

    return pd.DataFrame(data)


# ------------------------------------------------------------
# PRODUCT GENERATION
# ------------------------------------------------------------

def generate_products(n=1000):

    data = []

    category_names = list(product_categories.keys())

    for i in range(1, n + 1):

        category = random.choice(category_names)

        subcategory = random.choice(
            product_categories[category]
        )

        unit_cost = round(
            np.random.uniform(5, 2500),
            2
        )

        markup = np.random.uniform(
            1.10,
            1.55
        )

        standard_price = round(
            unit_cost * markup,
            2
        )

        reorder_level = random.randint(
            20,
            500
        )

        safety_stock = random.randint(
            10,
            max(20, reorder_level)
        )

        lead_time_days = random.randint(
            3,
            45
        )

        data.append({
            "ProductID": f"PRD{i:05d}",
            "ProductName":
                f"{subcategory} {fake.bothify(text='??-###').upper()}",
            "Category": category,
            "SubCategory": subcategory,
            "UnitCost": unit_cost,
            "StandardPrice": standard_price,
            "ReorderLevel": reorder_level,
            "SafetyStockLevel": safety_stock,
            "LeadTimeDays": lead_time_days,
        })

    return pd.DataFrame(data)


# ------------------------------------------------------------
# WAREHOUSE GENERATION
# ------------------------------------------------------------

def generate_warehouses(n=50):

    data = []

    selected_countries = [
        "United States",
        "China",
        "India",
        "Germany",
        "Singapore",
        "UAE",
        "United Kingdom",
        "Brazil",
        "Australia",
        "Netherlands",
    ]

    for i in range(1, n + 1):

        country = random.choice(
            selected_countries
        )

        capacity = random.randint(
            30000,
            250000
        )

        data.append({
            "WarehouseID": f"WH{i:03d}",
            "WarehouseName":
                f"{fake.city()} Distribution Center",
            "Country": country,
            "City": fake.city(),
            "Capacity": capacity,
            "WarehouseType": random.choice(
                warehouse_types
            ),
        })

    return pd.DataFrame(data)


# ------------------------------------------------------------
# CARRIER GENERATION
# ------------------------------------------------------------

def generate_carriers(n=30):

    data = []

    carrier_names = [
        "DHL Supply Chain",
        "FedEx Logistics",
        "UPS Supply Chain",
        "Maersk Logistics",
        "DB Schenker",
        "Kuehne + Nagel",
        "CEVA Logistics",
        "DSV Logistics",
        "Nippon Express",
        "Expeditors International",
    ]

    for i in range(1, n + 1):

        country, _ = random.choice(
            countries
        )

        if i <= len(carrier_names):
            carrier_name = carrier_names[i - 1]

        else:
            carrier_name = (
                fake.company()
                + " Logistics"
            )

        data.append({
            "CarrierID": f"CAR{i:03d}",
            "CarrierName": carrier_name,
            "CarrierType": random.choice(
                carrier_types
            ),
            "Country": country,
            "ServiceLevel": random.choice(
                service_levels
            ),
        })

    return pd.DataFrame(data)


# ------------------------------------------------------------
# SAVE CSV FILES
# ------------------------------------------------------------

def save_data():

    suppliers = generate_suppliers(500)

    products = generate_products(1000)

    warehouses = generate_warehouses(50)

    carriers = generate_carriers(30)

    suppliers.to_csv(
        OUTPUT_DIR / "suppliers.csv",
        index=False
    )

    products.to_csv(
        OUTPUT_DIR / "products.csv",
        index=False
    )

    warehouses.to_csv(
        OUTPUT_DIR / "warehouses.csv",
        index=False
    )

    carriers.to_csv(
        OUTPUT_DIR / "carriers.csv",
        index=False
    )

    print("\nMaster data generation completed.\n")

    print(
        f"Suppliers generated: {len(suppliers):,}"
    )

    print(
        f"Products generated: {len(products):,}"
    )

    print(
        f"Warehouses generated: {len(warehouses):,}"
    )

    print(
        f"Carriers generated: {len(carriers):,}"
    )

    print(
        f"\nFiles saved to:\n{OUTPUT_DIR}"
    )


# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

if __name__ == "__main__":
    save_data()