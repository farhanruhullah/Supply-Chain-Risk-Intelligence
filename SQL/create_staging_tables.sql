USE master;
GO

IF DB_ID('SupplyChainRiskDB') IS NULL
BEGIN
    CREATE DATABASE SupplyChainRiskDB;
END;
GO

USE SupplyChainRiskDB;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'stg'
)
BEGIN
    EXEC('CREATE SCHEMA stg');
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'dw'
)
BEGIN
    EXEC('CREATE SCHEMA dw');
END;
GO

SELECT name
FROM sys.schemas
WHERE name IN ('stg', 'dw');

USE SupplyChainRiskDB;
GO

SELECT DB_NAME() AS CurrentDatabase;


USE SupplyChainRiskDB;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'stg'
ORDER BY t.name;

USE SupplyChainRiskDB;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;


SELECT COUNT(*) AS Suppliers FROM dbo.suppliers;
SELECT COUNT(*) AS Products FROM dbo.products;
SELECT COUNT(*) AS Warehouses FROM dbo.warehouses;
SELECT COUNT(*) AS Carriers FROM dbo.carriers;
SELECT COUNT(*) AS Orders FROM dbo.orders;
SELECT COUNT(*) AS Shipments FROM dbo.shipments;
SELECT COUNT(*) AS Inventory FROM dbo.inventory;
SELECT COUNT(*) AS SupplierQuality FROM dbo.supplier_quality;

SELECT TOP 5 * FROM dbo.suppliers;
SELECT TOP 5 * FROM dbo.orders;
SELECT TOP 5 * FROM dbo.shipments;
SELECT TOP 5 * FROM dbo.inventory;
SELECT TOP 5 * FROM dbo.supplier_quality;

SELECT TOP 20 SupplierSince
FROM dbo.suppliers;

SELECT TOP 20 OrderDate, ExpectedDeliveryDate
FROM dbo.orders;
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'suppliers'
ORDER BY ORDINAL_POSITION;

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'Suppliers'
ORDER BY ORDINAL_POSITION;

--Suppliers

TRUNCATE TABLE stg.Suppliers;

INSERT INTO stg.Suppliers
(
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    SupplierSince,
    QualityRating,
    RiskTier,
    ActiveStatus
)
SELECT
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    TRY_CONVERT(DATE, SupplierSince),
    TRY_CONVERT(DECIMAL(5,2), QualityRating),
    RiskTier,
    ActiveStatus
FROM dbo.suppliers;

SELECT COUNT(*) AS SupplierCount
FROM stg.Suppliers;

SELECT SupplierSince
FROM dbo.suppliers
WHERE SupplierSince IS NOT NULL
  AND TRY_CONVERT(DATE, SupplierSince) IS NULL;

SELECT TOP 10 *
FROM stg.Suppliers;

--Products

TRUNCATE TABLE stg.Products;

INSERT INTO stg.Products
(
    ProductID,
    ProductName,
    Category,
    SubCategory,
    UnitCost,
    StandardPrice,
    ReorderLevel,
    SafetyStockLevel,
    LeadTimeDays
)
SELECT
    ProductID,
    ProductName,
    Category,
    SubCategory,
    TRY_CONVERT(DECIMAL(18,2), UnitCost),
    TRY_CONVERT(DECIMAL(18,2), StandardPrice),
    TRY_CONVERT(INT, ReorderLevel),
    TRY_CONVERT(INT, SafetyStockLevel),
    TRY_CONVERT(INT, LeadTimeDays)
FROM dbo.products;

SELECT COUNT(*) AS ProductCount
FROM stg.Products;

SELECT TOP 10 *
FROM stg.Products;

SELECT *
FROM dbo.products
WHERE TRY_CONVERT(DECIMAL(18,2), UnitCost) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), StandardPrice) IS NULL
   OR TRY_CONVERT(INT, ReorderLevel) IS NULL
   OR TRY_CONVERT(INT, SafetyStockLevel) IS NULL
   OR TRY_CONVERT(INT, LeadTimeDays) IS NULL;

--Warehouse

TRUNCATE TABLE stg.Warehouses;

INSERT INTO stg.Warehouses
(
    WarehouseID,
    WarehouseName,
    Country,
    City,
    Capacity,
    WarehouseType
)
SELECT
    WarehouseID,
    WarehouseName,
    Country,
    City,
    TRY_CONVERT(INT, Capacity),
    WarehouseType
FROM dbo.warehouses;

SELECT COUNT(*) AS WarehouseCount
FROM stg.Warehouses;

SELECT TOP 10 *
FROM stg.Warehouses;

SELECT *
FROM dbo.warehouses
WHERE TRY_CONVERT(INT, Capacity) IS NULL;

--Carriers

TRUNCATE TABLE stg.Carriers;

INSERT INTO stg.Carriers
(
    CarrierID,
    CarrierName,
    CarrierType,
    Country,
    ServiceLevel
)
SELECT
    CarrierID,
    CarrierName,
    CarrierType,
    Country,
    ServiceLevel
FROM dbo.carriers;

SELECT COUNT(*) AS CarrierCount
FROM stg.Carriers;

SELECT TOP 10 *
FROM stg.Carriers;

--Order

TRUNCATE TABLE stg.Orders;

INSERT INTO stg.Orders
(
    OrderID,
    SupplierID,
    ProductID,
    WarehouseID,
    OrderDate,
    ExpectedDeliveryDate,
    OrderQuantity,
    UnitCost,
    OrderValue,
    OrderStatus
)
SELECT
    OrderID,
    SupplierID,
    ProductID,
    WarehouseID,
    TRY_CONVERT(DATE, OrderDate),
    TRY_CONVERT(DATE, ExpectedDeliveryDate),
    TRY_CONVERT(INT, OrderQuantity),
    TRY_CONVERT(DECIMAL(18,2), UnitCost),
    TRY_CONVERT(DECIMAL(18,2), OrderValue),
    OrderStatus
FROM dbo.orders;

SELECT TOP 10 *
FROM stg.Orders;

SELECT *
FROM dbo.orders
WHERE TRY_CONVERT(DATE, OrderDate) IS NULL
   OR TRY_CONVERT(DATE, ExpectedDeliveryDate) IS NULL
   OR TRY_CONVERT(INT, OrderQuantity) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), UnitCost) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), OrderValue) IS NULL;

SELECT
    OrderID,
    COUNT(*) AS DuplicateCount
FROM stg.Orders
GROUP BY OrderID
HAVING COUNT(*) > 1;

--Shipments

TRUNCATE TABLE stg.Shipments;

INSERT INTO stg.Shipments
(
    ShipmentID,
    OrderID,
    SupplierID,
    ProductID,
    WarehouseID,
    CarrierID,
    ShipDate,
    PromisedDate,
    DeliveryDate,
    QuantityShipped,
    ShippingCost,
    QualityScore,
    DamagedQuantity,
    DeliveryDays,
    DelayDays,
    ShipmentStatus
)
SELECT
    ShipmentID,
    OrderID,
    SupplierID,
    ProductID,
    WarehouseID,
    CarrierID,
    TRY_CONVERT(DATE, ShipDate),
    TRY_CONVERT(DATE, PromisedDate),
    TRY_CONVERT(DATE, DeliveryDate),
    TRY_CONVERT(INT, QuantityShipped),
    TRY_CONVERT(DECIMAL(18,2), ShippingCost),
    TRY_CONVERT(DECIMAL(5,2), QualityScore),
    TRY_CONVERT(INT, DamagedQuantity),
    TRY_CONVERT(INT, DeliveryDays),
    TRY_CONVERT(INT, DelayDays),
    ShipmentStatus
FROM dbo.shipments;

SELECT TOP 10 *
FROM stg.Shipments;

SELECT *
FROM dbo.shipments
WHERE TRY_CONVERT(DATE, ShipDate) IS NULL
   OR TRY_CONVERT(DATE, PromisedDate) IS NULL
   OR TRY_CONVERT(DATE, DeliveryDate) IS NULL
   OR TRY_CONVERT(INT, QuantityShipped) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), ShippingCost) IS NULL
   OR TRY_CONVERT(DECIMAL(5,2), QualityScore) IS NULL
   OR TRY_CONVERT(INT, DamagedQuantity) IS NULL
   OR TRY_CONVERT(INT, DeliveryDays) IS NULL
   OR TRY_CONVERT(INT, DelayDays) IS NULL;

SELECT
    ShipmentID,
    COUNT(*) AS DuplicateCount
FROM stg.Shipments
GROUP BY ShipmentID
HAVING COUNT(*) > 1;

--Inventory

TRUNCATE TABLE stg.Inventory;

INSERT INTO stg.Inventory
(
    InventoryRecordID,
    ProductID,
    WarehouseID,
    SnapshotDate,
    CurrentStock,
    ReservedStock,
    AvailableStock,
    ReorderLevel,
    SafetyStockLevel,
    AvgDailyDemand,
    StockCoverageDays,
    InventoryValue,
    RiskStatus,
    WarehouseUtilizationPct
)
SELECT
    InventoryRecordID,
    ProductID,
    WarehouseID,
    TRY_CONVERT(DATE, SnapshotDate),
    TRY_CONVERT(INT, CurrentStock),
    TRY_CONVERT(INT, ReservedStock),
    TRY_CONVERT(INT, AvailableStock),
    TRY_CONVERT(INT, ReorderLevel),
    TRY_CONVERT(INT, SafetyStockLevel),
    TRY_CONVERT(DECIMAL(18,2), AvgDailyDemand),
    TRY_CONVERT(DECIMAL(18,2), StockCoverageDays),
    TRY_CONVERT(DECIMAL(18,2), InventoryValue),
    RiskStatus,
    TRY_CONVERT(DECIMAL(6,2), WarehouseUtilizationPct)
FROM dbo.inventory;

SELECT TOP 10 *
FROM stg.Inventory;

SELECT *
FROM dbo.inventory
WHERE TRY_CONVERT(DATE, SnapshotDate) IS NULL
   OR TRY_CONVERT(INT, CurrentStock) IS NULL
   OR TRY_CONVERT(INT, ReservedStock) IS NULL
   OR TRY_CONVERT(INT, AvailableStock) IS NULL
   OR TRY_CONVERT(INT, ReorderLevel) IS NULL
   OR TRY_CONVERT(INT, SafetyStockLevel) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), AvgDailyDemand) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), StockCoverageDays) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), InventoryValue) IS NULL
   OR TRY_CONVERT(DECIMAL(6,2), WarehouseUtilizationPct) IS NULL;

SELECT
    InventoryRecordID,
    COUNT(*) AS DuplicateCount
FROM stg.Inventory
GROUP BY InventoryRecordID
HAVING COUNT(*) > 1;

--SupplierQuality

TRUNCATE TABLE stg.SupplierQuality;

INSERT INTO stg.SupplierQuality
(
    InspectionID,
    OrderID,
    SupplierID,
    ProductID,
    InspectionDate,
    InspectedQuantity,
    AcceptedQuantity,
    RejectedQuantity,
    DefectQuantity,
    QualityScore,
    InspectionResult
)
SELECT
    InspectionID,
    OrderID,
    SupplierID,
    ProductID,
    TRY_CONVERT(DATE, InspectionDate),
    TRY_CONVERT(INT, InspectedQuantity),
    TRY_CONVERT(INT, AcceptedQuantity),
    TRY_CONVERT(INT, RejectedQuantity),
    TRY_CONVERT(INT, DefectQuantity),
    TRY_CONVERT(DECIMAL(5,2), QualityScore),
    InspectionResult
FROM dbo.supplier_quality;

SELECT TOP 10 *
FROM stg.SupplierQuality;

SELECT *
FROM dbo.supplier_quality
WHERE TRY_CONVERT(DATE, InspectionDate) IS NULL
   OR TRY_CONVERT(INT, InspectedQuantity) IS NULL
   OR TRY_CONVERT(INT, AcceptedQuantity) IS NULL
   OR TRY_CONVERT(INT, RejectedQuantity) IS NULL
   OR TRY_CONVERT(INT, DefectQuantity) IS NULL
   OR TRY_CONVERT(DECIMAL(5,2), QualityScore) IS NULL;

SELECT 'Suppliers' AS TableName, COUNT(*) AS Count FROM stg.Suppliers
UNION ALL
SELECT 'Products', COUNT(*) FROM stg.Products
UNION ALL
SELECT 'Warehouses', COUNT(*) FROM stg.Warehouses
UNION ALL
SELECT 'Carriers', COUNT(*) FROM stg.Carriers
UNION ALL
SELECT 'Orders', COUNT(*) FROM stg.Orders
UNION ALL
SELECT 'Shipments', COUNT(*) FROM stg.Shipments
UNION ALL
SELECT 'Inventory', COUNT(*) FROM stg.Inventory
UNION ALL
SELECT 'SupplierQuality', COUNT(*) FROM stg.SupplierQuality;


--update

TRUNCATE TABLE stg.Suppliers;
GO

INSERT INTO stg.Suppliers
(
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    SupplierSince,
    QualityRating,
    RiskTier,
    ActiveStatus
)
SELECT
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory,
    TRY_CONVERT(DATE, SupplierSince),
    TRY_CONVERT(DECIMAL(5,2), QualityRating),
    RiskTier,
    ActiveStatus
FROM dbo.suppliers_fixed;
GO

SELECT
    SupplierID,
    SupplierName,
    Country,
    Region,
    SupplierCategory
FROM dbo.suppliers_fixed
WHERE SupplierName LIKE '"%'
   OR Country LIKE '%"%';

SELECT
    SupplierID,
    SupplierName,
    Country
FROM dbo.suppliers_fixed
WHERE Country NOT IN
(
    'China','India','Bangladesh','Vietnam','Japan',
    'South Korea','Singapore','Malaysia','Thailand',
    'Indonesia','Germany','France','Italy','Netherlands',
    'Poland','Spain','United Kingdom','United States',
    'Canada','Mexico','Brazil','Argentina','UAE',
    'Saudi Arabia','Turkey','South Africa','Egypt',
    'Australia'
);

SELECT COUNT(*) AS SupplierCount
FROM stg.Suppliers;


