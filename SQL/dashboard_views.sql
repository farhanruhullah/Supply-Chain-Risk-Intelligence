--Create Supplier Risk Dashboard View

USE SupplyChainRiskDB;
GO

CREATE OR ALTER VIEW analytics.vw_supplier_risk_dashboard
AS

WITH RankedSuppliers AS
(
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

        RiskScore,
        RiskCategory,

        RANK()
        OVER(
            ORDER BY RiskScore DESC
        ) AS RiskRank,

        RANK()
        OVER(
            ORDER BY TotalPurchaseValue DESC
        ) AS PurchaseValueRank,

        RANK()
        OVER(
            ORDER BY LateShipmentPct DESC
        ) AS LateDeliveryRank,

        RANK()
        OVER(
            ORDER BY AvgQualityScore ASC
        ) AS QualityRiskRank

    FROM analytics.vw_supplier_risk_analysis
)

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

    RiskScore,
    RiskCategory,

    RiskRank,
    PurchaseValueRank,
    LateDeliveryRank,
    QualityRiskRank

FROM RankedSuppliers;
GO

SELECT TOP 20
    SupplierName,
    Country,
    RiskScore,
    RiskCategory,
    RiskRank,
    TotalPurchaseValue,
    PurchaseValueRank,
    LateShipmentPct,
    LateDeliveryRank
FROM analytics.vw_supplier_risk_dashboard
ORDER BY RiskRank;

--Create Inventory Dashboard View

CREATE OR ALTER VIEW analytics.vw_inventory_dashboard
AS

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
    RiskPriority

FROM analytics.vw_inventory_risk;
GO

SELECT TOP 20 *
FROM analytics.vw_inventory_dashboard
ORDER BY InventoryRiskScore DESC;

--Create Logistics Dashboard View

CREATE OR ALTER VIEW analytics.vw_logistics_dashboard
AS

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
    CarrierPerformanceCategory

FROM analytics.vw_logistics_performance;
GO

SELECT TOP 20 *
FROM analytics.vw_logistics_dashboard
ORDER BY LogisticsPerformanceScore DESC;

--Create Supplier Dependency Dashboard View

CREATE OR ALTER VIEW analytics.vw_supplier_dependency_dashboard
AS

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

    BusinessImpactScore,
    DependencyRiskCategory

FROM analytics.vw_supplier_dependency;
GO

SELECT TOP 20 *
FROM analytics.vw_supplier_dependency_dashboard
ORDER BY BusinessImpactScore DESC;

--Create one executive summary view

CREATE OR ALTER VIEW analytics.vw_supply_chain_executive_summary
AS

SELECT

    /* Supplier KPIs */

    (
        SELECT COUNT(*)
        FROM dw.DimSupplier
        WHERE ActiveStatus = 'Active'
    ) AS TotalActiveSuppliers,


    (
        SELECT COUNT(*)
        FROM analytics.vw_supplier_risk_analysis
        WHERE RiskCategory IN ('High', 'Critical')
    ) AS HighRiskSuppliers,


    /* Order KPIs */

    (
        SELECT COUNT(*)
        FROM dw.FactOrders
    ) AS TotalOrders,


    (
        SELECT
            CAST(
                SUM(OrderValue)
                AS DECIMAL(18,2)
            )
        FROM dw.FactOrders
        WHERE OrderStatus <> 'Cancelled'
    ) AS TotalPurchaseValue,


    /* Logistics KPI */

    (
        SELECT
            CAST(
                100.0 *
                SUM(
                    CASE
                        WHEN DelayDays <= 0 THEN 1
                        ELSE 0
                    END
                )
                /
                NULLIF(COUNT(*),0)
                AS DECIMAL(10,2)
            )
        FROM dw.FactShipments
    ) AS OnTimeDeliveryPct,


    /* Inventory risk */

    (
        SELECT COUNT(*)
        FROM analytics.vw_inventory_risk
        WHERE InventoryRiskStatus IN
        (
            'Stockout',
            'Critical',
            'Reorder Required'
        )
    ) AS InventoryRiskItems,


    (
        SELECT COUNT(*)
        FROM analytics.vw_inventory_risk
        WHERE InventoryRiskStatus = 'Stockout'
    ) AS StockoutItems,


    /* Shipping */

    (
        SELECT
            CAST(
                SUM(ShippingCost)
                AS DECIMAL(18,2)
            )
        FROM dw.FactShipments
    ) AS TotalShippingCost;
GO

SELECT *
FROM analytics.vw_supply_chain_executive_summary;

