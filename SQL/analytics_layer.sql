--Create an analytics schema

 USE SupplyChainRiskDB;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = 'analytics'
)
BEGIN
    EXEC('CREATE SCHEMA analytics');
END;
GO

--Create Supplier Risk Analysis View

USE SupplyChainRiskDB;
GO

CREATE OR ALTER VIEW analytics.vw_supplier_risk_analysis
AS

/* ============================================================
   1. SHIPMENT PERFORMANCE
   ============================================================ */

WITH ShipmentMetrics AS
(
    SELECT
        SupplierKey,

        COUNT(*) AS TotalShipments,

        SUM(
            CASE
                WHEN DelayDays > 0 THEN 1
                ELSE 0
            END
        ) AS LateShipments,

        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN DelayDays > 0 THEN 1
                    ELSE 0
                END
            )
            / NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS LateShipmentPct,

        CAST(
            AVG(
                CAST(
                    CASE
                        WHEN DelayDays > 0 THEN DelayDays
                        ELSE 0
                    END
                    AS DECIMAL(10,2)
                )
            )
            AS DECIMAL(10,2)
        ) AS AvgDelayDays,

        CAST(
            AVG(
                CASE
                    WHEN DelayDays > 0
                    THEN CAST(DelayDays AS DECIMAL(10,2))
                END
            )
            AS DECIMAL(10,2)
        ) AS AvgLateDelayDays,

        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN DelayDays <= 0 THEN 1
                    ELSE 0
                END
            )
            / NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS OnTimeDeliveryPct

    FROM dw.FactShipments

    GROUP BY SupplierKey
),


/* ============================================================
   2. QUALITY PERFORMANCE
   ============================================================ */

QualityMetrics AS
(
    SELECT
        SupplierKey,

        COUNT(*) AS TotalInspections,

        CAST(
            AVG(QualityScore)
            AS DECIMAL(10,2)
        ) AS AvgQualityScore,

        SUM(InspectedQuantity)
            AS TotalInspectedQuantity,

        SUM(DefectQuantity)
            AS TotalDefectQuantity,

        CAST(
            100.0 *
            SUM(DefectQuantity)
            /
            NULLIF(
                SUM(InspectedQuantity),
                0
            )
            AS DECIMAL(10,2)
        ) AS DefectRatePct

    FROM dw.FactSupplierQuality

    GROUP BY SupplierKey
),


/* ============================================================
   3. PURCHASE / DEPENDENCY METRICS
   ============================================================ */

PurchaseMetrics AS
(
    SELECT
        SupplierKey,

        COUNT(*) AS TotalOrders,

        SUM(OrderQuantity)
            AS TotalOrderQuantity,

        CAST(
            SUM(OrderValue)
            AS DECIMAL(18,2)
        ) AS TotalPurchaseValue

    FROM dw.FactOrders

    WHERE OrderStatus <> 'Cancelled'

    GROUP BY SupplierKey
),


/* ============================================================
   4. COMBINE SUPPLIER METRICS
   ============================================================ */

SupplierMetrics AS
(
    SELECT
        s.SupplierKey,
        s.SupplierID,
        s.SupplierName,
        s.Country,
        s.Region,
        s.SupplierCategory,
        s.ActiveStatus,

        COALESCE(
            sh.TotalShipments,
            0
        ) AS TotalShipments,

        COALESCE(
            sh.LateShipments,
            0
        ) AS LateShipments,

        COALESCE(
            sh.LateShipmentPct,
            0
        ) AS LateShipmentPct,

        COALESCE(
            sh.AvgDelayDays,
            0
        ) AS AvgDelayDays,

        COALESCE(
            sh.AvgLateDelayDays,
            0
        ) AS AvgLateDelayDays,

        COALESCE(
            sh.OnTimeDeliveryPct,
            0
        ) AS OnTimeDeliveryPct,

        COALESCE(
            q.TotalInspections,
            0
        ) AS TotalInspections,

        COALESCE(
            q.AvgQualityScore,
            s.QualityRating
        ) AS AvgQualityScore,

        COALESCE(
            q.DefectRatePct,
            0
        ) AS DefectRatePct,

        COALESCE(
            p.TotalOrders,
            0
        ) AS TotalOrders,

        COALESCE(
            p.TotalOrderQuantity,
            0
        ) AS TotalOrderQuantity,

        COALESCE(
            p.TotalPurchaseValue,
            0
        ) AS TotalPurchaseValue

    FROM dw.DimSupplier s

    LEFT JOIN ShipmentMetrics sh
        ON s.SupplierKey = sh.SupplierKey

    LEFT JOIN QualityMetrics q
        ON s.SupplierKey = q.SupplierKey

    LEFT JOIN PurchaseMetrics p
        ON s.SupplierKey = p.SupplierKey
),


/* ============================================================
   5. CALCULATE PURCHASE DEPENDENCY
   ============================================================ */

DependencyMetrics AS
(
    SELECT
        *,

        CAST(
            100.0 *
            TotalPurchaseValue
            /
            NULLIF(
                SUM(TotalPurchaseValue)
                    OVER(),
                0
            )
            AS DECIMAL(10,2)
        ) AS PurchaseDependencyPct

    FROM SupplierMetrics
),


/* ============================================================
   6. RELATIVE RISK SCORES
   ============================================================ */

RiskComponents AS
(
    SELECT
        *,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY LateShipmentPct
            ) * 100
            AS DECIMAL(10,2)
        ) AS LateDeliveryRiskScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY AvgDelayDays
            ) * 100
            AS DECIMAL(10,2)
        ) AS DelaySeverityRiskScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY AvgQualityScore DESC
            ) * 100
            AS DECIMAL(10,2)
        ) AS QualityRiskScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY PurchaseDependencyPct
            ) * 100
            AS DECIMAL(10,2)
        ) AS DependencyRiskScore

    FROM DependencyMetrics
),


/* ============================================================
   7. COMPOSITE RISK SCORE
   ============================================================ */

FinalRisk AS
(
    SELECT
        *,

        CAST(
              LateDeliveryRiskScore * 0.40
            + DelaySeverityRiskScore * 0.20
            + QualityRiskScore * 0.25
            + DependencyRiskScore * 0.15

            AS DECIMAL(10,2)
        ) AS RiskScore

    FROM RiskComponents
)


/* ============================================================
   FINAL OUTPUT
   ============================================================ */

SELECT
    SupplierKey,
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    ActiveStatus,

    TotalOrders,
    TotalPurchaseValue,
    PurchaseDependencyPct,

    TotalShipments,
    LateShipments,
    LateShipmentPct,
    AvgDelayDays,
    AvgLateDelayDays,
    OnTimeDeliveryPct,

    TotalInspections,
    AvgQualityScore,
    DefectRatePct,

    LateDeliveryRiskScore,
    DelaySeverityRiskScore,
    QualityRiskScore,
    DependencyRiskScore,

    RiskScore,

    CASE
        WHEN RiskScore >= 75
            THEN 'Critical'

        WHEN RiskScore >= 50
            THEN 'High'

        WHEN RiskScore >= 25
            THEN 'Medium'

        ELSE 'Low'
    END AS RiskCategory

FROM FinalRisk;
GO

SELECT TOP 20 *
FROM analytics.vw_supplier_risk_analysis
ORDER BY RiskScore DESC;

--Check risk distribution

SELECT
    RiskCategory,
    COUNT(*) AS SupplierCount
FROM analytics.vw_supplier_risk_analysis
GROUP BY RiskCategory
ORDER BY
    CASE RiskCategory
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END;

--Find the highest-risk suppliers

SELECT TOP 10
    SupplierID,
    SupplierName,
    Country,

    LateShipmentPct,
    AvgDelayDays,
    AvgQualityScore,
    PurchaseDependencyPct,

    RiskScore,
    RiskCategory

FROM analytics.vw_supplier_risk_analysis

ORDER BY RiskScore DESC;

--Supplier Dependency Analysis

USE SupplyChainRiskDB;
GO

CREATE OR ALTER VIEW analytics.vw_supplier_dependency
AS

/* ============================================================
   1. BASIC SUPPLIER PURCHASE EXPOSURE
   ============================================================ */

WITH SupplierSpend AS
(
    SELECT
        SupplierKey,

        COUNT(*) AS TotalOrders,

        SUM(OrderQuantity) AS TotalOrderQuantity,

        CAST(
            SUM(OrderValue)
            AS DECIMAL(18,2)
        ) AS TotalPurchaseValue,

        CAST(
            AVG(OrderValue)
            AS DECIMAL(18,2)
        ) AS AvgOrderValue,

        COUNT(
            DISTINCT ProductKey
        ) AS ProductsSupplied,

        COUNT(
            DISTINCT WarehouseKey
        ) AS WarehousesSupported

    FROM dw.FactOrders

    WHERE OrderStatus <> 'Cancelled'

    GROUP BY SupplierKey
),


/* ============================================================
   2. SUPPLIER-PRODUCT PURCHASE VALUE
   ============================================================ */

SupplierProductSpend AS
(
    SELECT
        SupplierKey,
        ProductKey,

        SUM(OrderValue) AS SupplierProductValue

    FROM dw.FactOrders

    WHERE OrderStatus <> 'Cancelled'

    GROUP BY
        SupplierKey,
        ProductKey
),


/* ============================================================
   3. TOTAL SPEND BY PRODUCT
   ============================================================ */

ProductSpend AS
(
    SELECT
        ProductKey,

        SUM(OrderValue) AS TotalProductSpend

    FROM dw.FactOrders

    WHERE OrderStatus <> 'Cancelled'

    GROUP BY ProductKey
),


/* ============================================================
   4. CALCULATE SUPPLIER SHARE PER PRODUCT
   ============================================================ */

ProductDependency AS
(
    SELECT
        sps.SupplierKey,
        sps.ProductKey,

        CAST(
            100.0 *
            sps.SupplierProductValue
            /
            NULLIF(
                ps.TotalProductSpend,
                0
            )
            AS DECIMAL(10,2)
        ) AS SupplierProductDependencyPct

    FROM SupplierProductSpend sps

    INNER JOIN ProductSpend ps
        ON sps.ProductKey = ps.ProductKey
),


/* ============================================================
   5. PRODUCT CONCENTRATION BY SUPPLIER
   ============================================================ */

SupplierProductExposure AS
(
    SELECT
        SupplierKey,

        COUNT(*) AS ProductRelationships,

        SUM(
            CASE
                WHEN SupplierProductDependencyPct >= 50
                THEN 1
                ELSE 0
            END
        ) AS HighlyDependentProducts,

        SUM(
            CASE
                WHEN SupplierProductDependencyPct >= 30
                THEN 1
                ELSE 0
            END
        ) AS ModerateDependentProducts,

        CAST(
            AVG(
                SupplierProductDependencyPct
            )
            AS DECIMAL(10,2)
        ) AS AvgProductDependencyPct,

        CAST(
            MAX(
                SupplierProductDependencyPct
            )
            AS DECIMAL(10,2)
        ) AS MaxProductDependencyPct

    FROM ProductDependency

    GROUP BY SupplierKey
),


/* ============================================================
   6. COMBINE SUPPLIER INFORMATION
   ============================================================ */

SupplierExposure AS
(
    SELECT
        s.SupplierKey,
        s.SupplierID,
        s.SupplierName,
        s.Country,
        s.Region,
        s.SupplierCategory,
        s.ActiveStatus,

        COALESCE(
            ss.TotalOrders,
            0
        ) AS TotalOrders,

        COALESCE(
            ss.TotalOrderQuantity,
            0
        ) AS TotalOrderQuantity,

        COALESCE(
            ss.TotalPurchaseValue,
            0
        ) AS TotalPurchaseValue,

        COALESCE(
            ss.AvgOrderValue,
            0
        ) AS AvgOrderValue,

        COALESCE(
            ss.ProductsSupplied,
            0
        ) AS ProductsSupplied,

        COALESCE(
            ss.WarehousesSupported,
            0
        ) AS WarehousesSupported,

        COALESCE(
            pe.HighlyDependentProducts,
            0
        ) AS HighlyDependentProducts,

        COALESCE(
            pe.ModerateDependentProducts,
            0
        ) AS ModerateDependentProducts,

        COALESCE(
            pe.AvgProductDependencyPct,
            0
        ) AS AvgProductDependencyPct,

        COALESCE(
            pe.MaxProductDependencyPct,
            0
        ) AS MaxProductDependencyPct

    FROM dw.DimSupplier s

    LEFT JOIN SupplierSpend ss
        ON s.SupplierKey = ss.SupplierKey

    LEFT JOIN SupplierProductExposure pe
        ON s.SupplierKey = pe.SupplierKey
),


/* ============================================================
   7. OVERALL COMPANY PURCHASE DEPENDENCY
   ============================================================ */

DependencyMetrics AS
(
    SELECT
        *,

        CAST(
            100.0 *
            TotalPurchaseValue
            /
            NULLIF(
                SUM(TotalPurchaseValue)
                OVER(),
                0
            )
            AS DECIMAL(10,2)
        ) AS CompanyPurchaseDependencyPct

    FROM SupplierExposure
),


/* ============================================================
   8. DEPENDENCY COMPONENT SCORES
   ============================================================ */

DependencyScores AS
(
    SELECT
        *,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY TotalPurchaseValue
            ) * 100
            AS DECIMAL(10,2)
        ) AS PurchaseExposureScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY ProductsSupplied
            ) * 100
            AS DECIMAL(10,2)
        ) AS ProductExposureScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY WarehousesSupported
            ) * 100
            AS DECIMAL(10,2)
        ) AS WarehouseExposureScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY HighlyDependentProducts
            ) * 100
            AS DECIMAL(10,2)
        ) AS ProductConcentrationScore

    FROM DependencyMetrics
),


/* ============================================================
   9. FINAL BUSINESS IMPACT SCORE
   ============================================================ */

FinalDependency AS
(
    SELECT
        *,

        CAST(
              PurchaseExposureScore       * 0.40
            + ProductExposureScore        * 0.25
            + WarehouseExposureScore      * 0.20
            + ProductConcentrationScore   * 0.15

            AS DECIMAL(10,2)
        ) AS BusinessImpactScore

    FROM DependencyScores
)


/* ============================================================
   FINAL OUTPUT
   ============================================================ */

SELECT
    SupplierKey,
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    ActiveStatus,

    TotalOrders,
    TotalOrderQuantity,
    TotalPurchaseValue,
    AvgOrderValue,

    CompanyPurchaseDependencyPct,

    ProductsSupplied,
    WarehousesSupported,

    HighlyDependentProducts,
    ModerateDependentProducts,

    AvgProductDependencyPct,
    MaxProductDependencyPct,

    PurchaseExposureScore,
    ProductExposureScore,
    WarehouseExposureScore,
    ProductConcentrationScore,

    BusinessImpactScore,

    CASE
        WHEN BusinessImpactScore >= 75
            THEN 'Critical'

        WHEN BusinessImpactScore >= 50
            THEN 'High'

        WHEN BusinessImpactScore >= 25
            THEN 'Medium'

        ELSE 'Low'

    END AS DependencyRiskCategory

FROM FinalDependency;
GO

SELECT TOP 20
    SupplierID,
    SupplierName,
    Country,
    TotalPurchaseValue,
    CompanyPurchaseDependencyPct,
    ProductsSupplied,
    WarehousesSupported,
    HighlyDependentProducts,
    BusinessImpactScore,
    DependencyRiskCategory
FROM analytics.vw_supplier_dependency
ORDER BY BusinessImpactScore DESC;

--dependency distribution

SELECT
    DependencyRiskCategory,
    COUNT(*) AS SupplierCount
FROM analytics.vw_supplier_dependency
GROUP BY DependencyRiskCategory
ORDER BY
    CASE DependencyRiskCategory
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
    END;

SELECT TOP 10
    SupplierName,
    Country,
    ProductsSupplied,
    WarehousesSupported,
    TotalPurchaseValue,
    BusinessImpactScore
FROM analytics.vw_supplier_dependency
ORDER BY ProductsSupplied DESC;

SELECT TOP 10
    SupplierName,
    ProductsSupplied,
    HighlyDependentProducts,
    ModerateDependentProducts,
    MaxProductDependencyPct,
    BusinessImpactScore
FROM analytics.vw_supplier_dependency
ORDER BY HighlyDependentProducts DESC,
         BusinessImpactScore DESC;


--analytics.vw_inventory_risk

USE SupplyChainRiskDB;
GO

CREATE OR ALTER VIEW analytics.vw_inventory_risk
AS

/* ============================================================
   1. FIND LATEST INVENTORY SNAPSHOT
   ============================================================ */

WITH LatestSnapshot AS
(
    SELECT
        MAX(d.FullDate) AS LatestInventoryDate
    FROM dw.FactInventory i
    INNER JOIN dw.DimDate d
        ON i.DateKey = d.DateKey
),


/* ============================================================
   2. GET CURRENT INVENTORY POSITION
   ============================================================ */

CurrentInventory AS
(
    SELECT
        i.InventoryKey,
        i.InventoryRecordID,

        p.ProductKey,
        p.ProductID,
        p.ProductName,
        p.Category,
        p.SubCategory,
        p.UnitCost,
        p.LeadTimeDays,

        w.WarehouseKey,
        w.WarehouseID,
        w.WarehouseName,
        w.Country AS WarehouseCountry,
        w.City AS WarehouseCity,
        w.Capacity,

        d.FullDate AS SnapshotDate,

        i.CurrentStock,
        i.ReservedStock,
        i.AvailableStock,

        i.ReorderLevel,
        i.SafetyStockLevel,

        i.AvgDailyDemand,
        i.StockCoverageDays,

        i.InventoryValue,
        i.WarehouseUtilizationPct

    FROM dw.FactInventory i

    INNER JOIN dw.DimProduct p
        ON i.ProductKey = p.ProductKey

    INNER JOIN dw.DimWarehouse w
        ON i.WarehouseKey = w.WarehouseKey

    INNER JOIN dw.DimDate d
        ON i.DateKey = d.DateKey

    CROSS JOIN LatestSnapshot ls

    WHERE d.FullDate = ls.LatestInventoryDate
),


/* ============================================================
   3. CALCULATE INVENTORY RISK METRICS
   ============================================================ */

RiskMetrics AS
(
    SELECT
        *,

        /* Stock shortage against reorder level */
        CASE
            WHEN AvailableStock < ReorderLevel
            THEN ReorderLevel - AvailableStock
            ELSE 0
        END AS StockGapQty,


        /* Recommended quantity needed to restore safety */
        CASE
            WHEN AvailableStock < ReorderLevel
            THEN
                (ReorderLevel + SafetyStockLevel)
                - AvailableStock

            ELSE 0
        END AS SuggestedReorderQty,


        /* Inventory status calculated in SQL */
        CASE

            WHEN AvailableStock <= 0
                THEN 'Stockout'

            WHEN AvailableStock < SafetyStockLevel
                THEN 'Critical'

            WHEN AvailableStock < ReorderLevel
                THEN 'Reorder Required'

            WHEN AvailableStock > ReorderLevel * 3
                THEN 'Overstock'

            ELSE 'Safe'

        END AS InventoryRiskStatus,


        /* Coverage-based risk */
        CASE

            WHEN StockCoverageDays <= 0
                THEN 'Stockout'

            WHEN StockCoverageDays < 7
                THEN 'Critical'

            WHEN StockCoverageDays < 15
                THEN 'Low Coverage'

            WHEN StockCoverageDays > 90
                THEN 'Excess Coverage'

            ELSE 'Healthy'

        END AS CoverageStatus,


        /* Approximate monetary exposure */
        CAST(
            CASE
                WHEN AvailableStock < ReorderLevel
                THEN
                    (ReorderLevel - AvailableStock)
                    * UnitCost
                ELSE 0
            END
            AS DECIMAL(18,2)
        ) AS InventoryRiskValue

    FROM CurrentInventory
),


/* ============================================================
   4. CREATE RISK SCORE
   ============================================================ */

RiskScoring AS
(
    SELECT
        *,

        CAST(
            CASE

                WHEN InventoryRiskStatus = 'Stockout'
                    THEN 100

                WHEN InventoryRiskStatus = 'Critical'
                    THEN 85

                WHEN InventoryRiskStatus = 'Reorder Required'
                    THEN 65

                WHEN InventoryRiskStatus = 'Overstock'
                    THEN 45

                ELSE 10

            END
            AS DECIMAL(10,2)
        ) AS BaseRiskScore

    FROM RiskMetrics
),


/* ============================================================
   5. PRIORITY SCORE
   ============================================================ */

FinalRisk AS
(
    SELECT
        *,

        CAST(
            BaseRiskScore * 0.70
            +
            (
                PERCENT_RANK()
                OVER(
                    ORDER BY InventoryRiskValue
                )
                * 100
            ) * 0.30

            AS DECIMAL(10,2)
        ) AS InventoryRiskScore

    FROM RiskScoring
)


/* ============================================================
   FINAL OUTPUT
   ============================================================ */

SELECT
    InventoryKey,
    InventoryRecordID,

    ProductKey,
    ProductID,
    ProductName,
    Category,
    SubCategory,

    WarehouseKey,
    WarehouseID,
    WarehouseName,
    WarehouseCountry,
    WarehouseCity,

    SnapshotDate,

    CurrentStock,
    ReservedStock,
    AvailableStock,

    ReorderLevel,
    SafetyStockLevel,

    StockGapQty,
    SuggestedReorderQty,

    AvgDailyDemand,
    StockCoverageDays,

    InventoryValue,
    InventoryRiskValue,

    WarehouseUtilizationPct,

    InventoryRiskStatus,
    CoverageStatus,

    InventoryRiskScore,

    CASE

        WHEN InventoryRiskScore >= 80
            THEN 'Critical'

        WHEN InventoryRiskScore >= 60
            THEN 'High'

        WHEN InventoryRiskScore >= 30
            THEN 'Medium'

        ELSE 'Low'

    END AS RiskPriority

FROM FinalRisk;
GO

SELECT
    ProductID,
    ProductName,
    WarehouseName,
    AvailableStock,
    AvgDailyDemand,
    StockCoverageDays,
    InventoryRiskValue
FROM analytics.vw_inventory_risk
WHERE InventoryRiskStatus = 'Stockout'
ORDER BY InventoryRiskValue DESC;

SELECT TOP 20
    ProductID,
    ProductName,
    WarehouseName,
    AvailableStock,
    ReorderLevel,
    SafetyStockLevel,
    StockGapQty,
    SuggestedReorderQty,
    InventoryRiskScore
FROM analytics.vw_inventory_risk
WHERE InventoryRiskStatus IN
(
    'Critical',
    'Reorder Required'
)
ORDER BY InventoryRiskScore DESC;

SELECT TOP 20
    ProductID,
    ProductName,
    WarehouseName,
    AvailableStock,
    ReorderLevel,
    InventoryValue,
    StockCoverageDays
FROM analytics.vw_inventory_risk
WHERE InventoryRiskStatus = 'Overstock'
ORDER BY InventoryValue DESC;

SELECT
    WarehouseName,

    COUNT(*) AS InventoryItems,

    SUM(
        CASE
            WHEN InventoryRiskStatus = 'Stockout'
            THEN 1
            ELSE 0
        END
    ) AS StockoutItems,

    SUM(
        CASE
            WHEN InventoryRiskStatus = 'Critical'
            THEN 1
            ELSE 0
        END
    ) AS CriticalItems,

    CAST(
        AVG(WarehouseUtilizationPct)
        AS DECIMAL(10,2)
    ) AS AvgUtilizationPct,

    CAST(
        SUM(InventoryValue)
        AS DECIMAL(18,2)
    ) AS TotalInventoryValue

FROM analytics.vw_inventory_risk

GROUP BY WarehouseName

ORDER BY StockoutItems DESC,
         CriticalItems DESC;

--Logistics Performance Analysis

USE SupplyChainRiskDB;
GO

CREATE OR ALTER VIEW analytics.vw_logistics_performance
AS

WITH CarrierMetrics AS
(
    SELECT
        fs.CarrierKey,

        COUNT(*) AS TotalShipments,

        SUM(
            CASE
                WHEN fs.DelayDays <= 0 THEN 1
                ELSE 0
            END
        ) AS OnTimeShipments,

        SUM(
            CASE
                WHEN fs.DelayDays > 0 THEN 1
                ELSE 0
            END
        ) AS LateShipments,

        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN fs.DelayDays <= 0 THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS OnTimeDeliveryPct,

        CAST(
            100.0 *
            SUM(
                CASE
                    WHEN fs.DelayDays > 0 THEN 1
                    ELSE 0
                END
            )
            /
            NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS DelayPct,

        CAST(
            AVG(
                CAST(
                    fs.DeliveryDays
                    AS DECIMAL(10,2)
                )
            )
            AS DECIMAL(10,2)
        ) AS AvgDeliveryDays,

        CAST(
            AVG(
                CAST(
                    CASE
                        WHEN fs.DelayDays > 0
                        THEN fs.DelayDays
                        ELSE 0
                    END
                    AS DECIMAL(10,2)
                )
            )
            AS DECIMAL(10,2)
        ) AS AvgDelayDays,

        CAST(
            AVG(fs.ShippingCost)
            AS DECIMAL(18,2)
        ) AS AvgShippingCost,

        CAST(
            SUM(fs.ShippingCost)
            AS DECIMAL(18,2)
        ) AS TotalShippingCost,

        SUM(fs.QuantityShipped)
            AS TotalQuantityShipped,

        SUM(fs.DamagedQuantity)
            AS TotalDamagedQuantity,

        CAST(
            100.0 *
            SUM(fs.DamagedQuantity)
            /
            NULLIF(
                SUM(fs.QuantityShipped),
                0
            )
            AS DECIMAL(10,2)
        ) AS DamageRatePct

    FROM dw.FactShipments fs

    GROUP BY fs.CarrierKey
),


CarrierDetails AS
(
    SELECT
        c.CarrierKey,
        c.CarrierID,
        c.CarrierName,
        c.CarrierType,
        c.Country,
        c.ServiceLevel,

        cm.TotalShipments,
        cm.OnTimeShipments,
        cm.LateShipments,
        cm.OnTimeDeliveryPct,
        cm.DelayPct,
        cm.AvgDeliveryDays,
        cm.AvgDelayDays,
        cm.AvgShippingCost,
        cm.TotalShippingCost,
        cm.TotalQuantityShipped,
        cm.TotalDamagedQuantity,
        cm.DamageRatePct

    FROM dw.DimCarrier c

    LEFT JOIN CarrierMetrics cm
        ON c.CarrierKey = cm.CarrierKey
),


CarrierEfficiency AS
(
    SELECT
        *,

        CAST(
            TotalShippingCost
            /
            NULLIF(
                TotalQuantityShipped,
                0
            )
            AS DECIMAL(18,2)
        ) AS ShippingCostPerUnit,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY OnTimeDeliveryPct
            ) * 100
            AS DECIMAL(10,2)
        ) AS DeliveryPerformanceScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY AvgShippingCost DESC
            ) * 100
            AS DECIMAL(10,2)
        ) AS CostEfficiencyScore,

        CAST(
            PERCENT_RANK()
            OVER(
                ORDER BY DamageRatePct DESC
            ) * 100
            AS DECIMAL(10,2)
        ) AS DamagePerformanceScore

    FROM CarrierDetails
),


FinalPerformance AS
(
    SELECT
        *,

        CAST(
              DeliveryPerformanceScore * 0.50
            + CostEfficiencyScore       * 0.30
            + DamagePerformanceScore   * 0.20

            AS DECIMAL(10,2)
        ) AS LogisticsPerformanceScore

    FROM CarrierEfficiency
)


SELECT
    CarrierKey,
    CarrierID,
    CarrierName,
    CarrierType,
    Country,
    ServiceLevel,

    TotalShipments,
    OnTimeShipments,
    LateShipments,

    OnTimeDeliveryPct,
    DelayPct,

    AvgDeliveryDays,
    AvgDelayDays,

    AvgShippingCost,
    TotalShippingCost,
    ShippingCostPerUnit,

    TotalQuantityShipped,
    TotalDamagedQuantity,
    DamageRatePct,

    DeliveryPerformanceScore,
    CostEfficiencyScore,
    DamagePerformanceScore,

    LogisticsPerformanceScore,

    CASE
        WHEN LogisticsPerformanceScore >= 75
            THEN 'Excellent'

        WHEN LogisticsPerformanceScore >= 50
            THEN 'Good'

        WHEN LogisticsPerformanceScore >= 25
            THEN 'Average'

        ELSE 'Poor'
    END AS CarrierPerformanceCategory

FROM FinalPerformance;
GO

SELECT TOP 20
    CarrierName,
    CarrierType,
    ServiceLevel,
    TotalShipments,
    OnTimeDeliveryPct,
    DelayPct,
    AvgDeliveryDays,
    AvgDelayDays,
    AvgShippingCost,
    ShippingCostPerUnit,
    DamageRatePct,
    LogisticsPerformanceScore,
    CarrierPerformanceCategory
FROM analytics.vw_logistics_performance
ORDER BY LogisticsPerformanceScore DESC;

--best carriers

SELECT TOP 10
    CarrierName,
    OnTimeDeliveryPct,
    AvgDelayDays,
    ShippingCostPerUnit,
    DamageRatePct,
    LogisticsPerformanceScore
FROM analytics.vw_logistics_performance
ORDER BY LogisticsPerformanceScore DESC;

--worst carriers

SELECT TOP 10
    CarrierName,
    TotalShipments,
    DelayPct,
    AvgDelayDays,
    AvgShippingCost,
    DamageRatePct,
    LogisticsPerformanceScore
FROM analytics.vw_logistics_performance
ORDER BY LogisticsPerformanceScore ASC;

SELECT
    CarrierPerformanceCategory,
    COUNT(*) AS CarrierCount
FROM analytics.vw_logistics_performance
GROUP BY CarrierPerformanceCategory
ORDER BY
    CASE CarrierPerformanceCategory
        WHEN 'Excellent' THEN 1
        WHEN 'Good' THEN 2
        WHEN 'Average' THEN 3
        WHEN 'Poor' THEN 4
    END;

