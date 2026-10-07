from pathlib import Path
import random

import numpy as np
import pandas as pd


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42
QUALITY_RECORDS = 50_000

random.seed(SEED)
np.random.seed(SEED)

BASE_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"


# ============================================================
# LOAD MASTER DATA
# ============================================================

suppliers = pd.read_csv(
    RAW_DIR / "suppliers.csv"
)

products = pd.read_csv(
    RAW_DIR / "products.csv"
)

orders = pd.read_csv(
    RAW_DIR / "orders.csv",
    parse_dates=["OrderDate"]
)


print("Source data loaded successfully.")

print(f"Suppliers: {len(suppliers):,}")
print(f"Products: {len(products):,}")
print(f"Orders: {len(orders):,}")


# ============================================================
# CREATE LOOKUPS
# ============================================================

supplier_lookup = (
    suppliers
    .set_index("SupplierID")
    .to_dict("index")
)

product_lookup = (
    products
    .set_index("ProductID")
    .to_dict("index")
)


# ============================================================
# USE COMPLETED ORDERS AS INSPECTION SOURCE
# ============================================================

completed_orders = orders[
    orders["OrderStatus"] == "Completed"
].copy()


if len(completed_orders) < QUALITY_RECORDS:
    raise ValueError(
        "Not enough completed orders to generate "
        "the requested quality inspection records."
    )


sample_orders = completed_orders.sample(
    n=QUALITY_RECORDS,
    random_state=SEED
).reset_index(drop=True)


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def generate_quality_result(
    supplier_quality,
    inspected_quantity
):

    # Expected defect rate from supplier quality
    base_defect_rate = max(
        0.002,
        (100 - supplier_quality) / 100
    )

    # Add realistic inspection variation
    defect_rate = np.random.normal(
        loc=base_defect_rate,
        scale=0.015
    )

    defect_rate = np.clip(
        defect_rate,
        0,
        0.30
    )

    defect_quantity = int(
        round(
            inspected_quantity
            * defect_rate
        )
    )

    defect_quantity = min(
        defect_quantity,
        inspected_quantity
    )

    accepted_quantity = (
        inspected_quantity
        - defect_quantity
    )

    rejected_quantity = defect_quantity


    if inspected_quantity > 0:

        quality_score = round(
            (
                accepted_quantity
                / inspected_quantity
            )
            * 100,
            2
        )

    else:

        quality_score = 0


    # Inspection classification
    if quality_score >= 95:
        inspection_result = "Passed"

    elif quality_score >= 85:
        inspection_result = "Conditional"

    else:
        inspection_result = "Failed"


    return (
        accepted_quantity,
        rejected_quantity,
        defect_quantity,
        quality_score,
        inspection_result
    )


# ============================================================
# GENERATE QUALITY INSPECTION DATA
# ============================================================

quality_records = []

print("\nGenerating supplier quality inspections...")


for i, order in sample_orders.iterrows():

    supplier_id = order["SupplierID"]
    product_id = order["ProductID"]

    supplier = supplier_lookup[
        supplier_id
    ]

    supplier_quality = float(
        supplier["QualityRating"]
    )

    order_quantity = int(
        order["OrderQuantity"]
    )


    # Inspect between 20% and 100% of order quantity
    inspection_percentage = np.random.uniform(
        0.20,
        1.00
    )

    inspected_quantity = max(
        1,
        int(
            order_quantity
            * inspection_percentage
        )
    )


    (
        accepted_quantity,
        rejected_quantity,
        defect_quantity,
        quality_score,
        inspection_result
    ) = generate_quality_result(
        supplier_quality,
        inspected_quantity
    )


    # Inspection occurs around expected delivery
    inspection_date = (
        order["OrderDate"]
        + pd.to_timedelta(
            random.randint(5, 45),
            unit="D"
        )
    )


    quality_records.append({

        "InspectionID":
            f"INS{i + 1:07d}",

        "OrderID":
            order["OrderID"],

        "SupplierID":
            supplier_id,

        "ProductID":
            product_id,

        "InspectionDate":
            inspection_date.date(),

        "InspectedQuantity":
            inspected_quantity,

        "AcceptedQuantity":
            accepted_quantity,

        "RejectedQuantity":
            rejected_quantity,

        "DefectQuantity":
            defect_quantity,

        "QualityScore":
            quality_score,

        "InspectionResult":
            inspection_result
    })


# ============================================================
# CREATE DATAFRAME
# ============================================================

quality_df = pd.DataFrame(
    quality_records
)


# ============================================================
# SAVE CSV
# ============================================================

output_file = (
    RAW_DIR
    / "supplier_quality.csv"
)

quality_df.to_csv(
    output_file,
    index=False
)


# ============================================================
# VALIDATION
# ============================================================

print("\nSupplier quality generation completed.")

print(
    f"Quality records generated: "
    f"{len(quality_df):,}"
)


print("\nInspection Result Distribution:")

print(
    quality_df[
        "InspectionResult"
    ].value_counts()
)


print(
    "\nAverage Quality Score:"
)

print(
    f"{quality_df['QualityScore'].mean():.2f}%"
)


print(
    "\nTotal Inspected Quantity:"
)

print(
    f"{quality_df['InspectedQuantity'].sum():,}"
)


print(
    "\nTotal Defect Quantity:"
)

print(
    f"{quality_df['DefectQuantity'].sum():,}"
)


defect_rate = (
    quality_df[
        "DefectQuantity"
    ].sum()
    /
    quality_df[
        "InspectedQuantity"
    ].sum()
    * 100
)


print(
    f"\nOverall Defect Rate: "
    f"{defect_rate:.2f}%"
)


print("\nMissing Values:")

print(
    quality_df.isnull().sum()
)


print(
    "\nDuplicate Inspection IDs:"
)

print(
    quality_df[
        "InspectionID"
    ].duplicated().sum()
)


print(
    f"\nSaved to:\n{output_file}"
)