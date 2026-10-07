--Create the stored procedure

USE SupplyChainRiskDB;
GO

CREATE OR ALTER PROCEDURE analytics.sp_GetSupplierRiskReport
    @RiskLevel VARCHAR(20)
AS
BEGIN

    SET NOCOUNT ON;

    /* =========================================
       Validate parameter
       ========================================= */

    IF @RiskLevel NOT IN
    (
        'Low',
        'Medium',
        'High',
        'Critical'
    )
    BEGIN

        THROW 50001,
        'Invalid RiskLevel. Use Low, Medium, High, or Critical.',
        1;

    END;


    /* =========================================
       Return Supplier Risk Report
       ========================================= */

    SELECT
        SupplierID,
        SupplierName,
        Country,
        Region,
        SupplierCategory,

        TotalOrders,
        TotalPurchaseValue,
        PurchaseDependencyPct,

        TotalShipments,
        LateShipments,
        LateShipmentPct,
        AvgDelayDays,
        OnTimeDeliveryPct,

        TotalInspections,
        AvgQualityScore,
        DefectRatePct,

        RiskScore,
        RiskCategory

    FROM analytics.vw_supplier_risk_analysis

    WHERE RiskCategory = @RiskLevel

    ORDER BY
        RiskScore DESC,
        TotalPurchaseValue DESC;

END;
GO

--test

EXEC analytics.sp_GetSupplierRiskReport
    @RiskLevel = 'High';

EXEC analytics.sp_GetSupplierRiskReport
    @RiskLevel = 'Critical';

EXEC analytics.sp_GetSupplierRiskReport
    @RiskLevel = 'Medium';

EXEC analytics.sp_GetSupplierRiskReport
    @RiskLevel = 'Low';

--analytics.sp_GetInventoryRiskReport

CREATE OR ALTER PROCEDURE analytics.sp_GetInventoryRiskReport
    @RiskStatus VARCHAR(30)
AS
BEGIN

    SET NOCOUNT ON;

    IF @RiskStatus NOT IN
    (
        'Stockout',
        'Critical',
        'Reorder Required',
        'Overstock',
        'Safe'
    )
    BEGIN

        THROW 50002,
        'Invalid inventory risk status.',
        1;

    END;


    SELECT
        ProductID,
        ProductName,
        Category,

        WarehouseID,
        WarehouseName,
        WarehouseCountry,

        AvailableStock,
        SafetyStockLevel,
        ReorderLevel,

        StockGapQty,
        SuggestedReorderQty,

        AvgDailyDemand,
        StockCoverageDays,

        InventoryValue,
        InventoryRiskValue,

        InventoryRiskStatus,
        InventoryRiskScore,
        RiskPriority

    FROM analytics.vw_inventory_risk

    WHERE InventoryRiskStatus = @RiskStatus

    ORDER BY
        InventoryRiskScore DESC,
        InventoryRiskValue DESC;

END;
GO

--test

EXEC analytics.sp_GetInventoryRiskReport
    @RiskStatus = 'Critical';

EXEC analytics.sp_GetInventoryRiskReport
    @RiskStatus = 'Stockout';

