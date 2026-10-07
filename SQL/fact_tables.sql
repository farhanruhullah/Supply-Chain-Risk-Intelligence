USE SupplyChainRiskDB;
GO


/* ============================================================
   FACT ORDERS
   ============================================================ */

IF OBJECT_ID('dw.FactOrders', 'U') IS NULL
BEGIN
    CREATE TABLE dw.FactOrders
    (
        OrderKey INT IDENTITY(1,1) PRIMARY KEY,

        OrderID VARCHAR(30) NOT NULL,

        SupplierKey INT NOT NULL,
        ProductKey INT NOT NULL,
        WarehouseKey INT NOT NULL,

        OrderDateKey INT NOT NULL,
        ExpectedDeliveryDateKey INT NOT NULL,

        OrderQuantity INT,
        UnitCost DECIMAL(18,2),
        OrderValue DECIMAL(18,2),
        OrderStatus VARCHAR(30),

        CONSTRAINT FK_FactOrders_Supplier
            FOREIGN KEY (SupplierKey)
            REFERENCES dw.DimSupplier(SupplierKey),

        CONSTRAINT FK_FactOrders_Product
            FOREIGN KEY (ProductKey)
            REFERENCES dw.DimProduct(ProductKey),

        CONSTRAINT FK_FactOrders_Warehouse
            FOREIGN KEY (WarehouseKey)
            REFERENCES dw.DimWarehouse(WarehouseKey),

        CONSTRAINT FK_FactOrders_OrderDate
            FOREIGN KEY (OrderDateKey)
            REFERENCES dw.DimDate(DateKey),

        CONSTRAINT FK_FactOrders_ExpectedDate
            FOREIGN KEY (ExpectedDeliveryDateKey)
            REFERENCES dw.DimDate(DateKey)
    );
END;
GO


/* ============================================================
   FACT SHIPMENTS
   ============================================================ */

IF OBJECT_ID('dw.FactShipments', 'U') IS NULL
BEGIN
    CREATE TABLE dw.FactShipments
    (
        ShipmentKey INT IDENTITY(1,1) PRIMARY KEY,

        ShipmentID VARCHAR(30) NOT NULL,
        OrderID VARCHAR(30),

        SupplierKey INT NOT NULL,
        ProductKey INT NOT NULL,
        WarehouseKey INT NOT NULL,
        CarrierKey INT NOT NULL,

        ShipDateKey INT NOT NULL,
        PromisedDateKey INT NOT NULL,
        DeliveryDateKey INT NOT NULL,

        QuantityShipped INT,
        ShippingCost DECIMAL(18,2),
        QualityScore DECIMAL(5,2),
        DamagedQuantity INT,
        DeliveryDays INT,
        DelayDays INT,
        ShipmentStatus VARCHAR(30),

        CONSTRAINT FK_FactShipments_Supplier
            FOREIGN KEY (SupplierKey)
            REFERENCES dw.DimSupplier(SupplierKey),

        CONSTRAINT FK_FactShipments_Product
            FOREIGN KEY (ProductKey)
            REFERENCES dw.DimProduct(ProductKey),

        CONSTRAINT FK_FactShipments_Warehouse
            FOREIGN KEY (WarehouseKey)
            REFERENCES dw.DimWarehouse(WarehouseKey),

        CONSTRAINT FK_FactShipments_Carrier
            FOREIGN KEY (CarrierKey)
            REFERENCES dw.DimCarrier(CarrierKey),

        CONSTRAINT FK_FactShipments_ShipDate
            FOREIGN KEY (ShipDateKey)
            REFERENCES dw.DimDate(DateKey),

        CONSTRAINT FK_FactShipments_PromisedDate
            FOREIGN KEY (PromisedDateKey)
            REFERENCES dw.DimDate(DateKey),

        CONSTRAINT FK_FactShipments_DeliveryDate
            FOREIGN KEY (DeliveryDateKey)
            REFERENCES dw.DimDate(DateKey)
    );
END;
GO


/* ============================================================
   FACT INVENTORY
   ============================================================ */

IF OBJECT_ID('dw.FactInventory', 'U') IS NULL
BEGIN
    CREATE TABLE dw.FactInventory
    (
        InventoryKey INT IDENTITY(1,1) PRIMARY KEY,

        InventoryRecordID VARCHAR(30) NOT NULL,

        ProductKey INT NOT NULL,
        WarehouseKey INT NOT NULL,
        DateKey INT NOT NULL,

        CurrentStock INT,
        ReservedStock INT,
        AvailableStock INT,

        ReorderLevel INT,
        SafetyStockLevel INT,

        AvgDailyDemand DECIMAL(18,2),
        StockCoverageDays DECIMAL(18,2),

        InventoryValue DECIMAL(18,2),
        RiskStatus VARCHAR(30),
        WarehouseUtilizationPct DECIMAL(6,2),

        CONSTRAINT FK_FactInventory_Product
            FOREIGN KEY (ProductKey)
            REFERENCES dw.DimProduct(ProductKey),

        CONSTRAINT FK_FactInventory_Warehouse
            FOREIGN KEY (WarehouseKey)
            REFERENCES dw.DimWarehouse(WarehouseKey),

        CONSTRAINT FK_FactInventory_Date
            FOREIGN KEY (DateKey)
            REFERENCES dw.DimDate(DateKey)
    );
END;
GO


/* ============================================================
   FACT SUPPLIER QUALITY
   ============================================================ */

IF OBJECT_ID('dw.FactSupplierQuality', 'U') IS NULL
BEGIN
    CREATE TABLE dw.FactSupplierQuality
    (
        InspectionKey INT IDENTITY(1,1) PRIMARY KEY,

        InspectionID VARCHAR(30) NOT NULL,
        OrderID VARCHAR(30),

        SupplierKey INT NOT NULL,
        ProductKey INT NOT NULL,
        DateKey INT NOT NULL,

        InspectedQuantity INT,
        AcceptedQuantity INT,
        RejectedQuantity INT,
        DefectQuantity INT,

        QualityScore DECIMAL(5,2),
        InspectionResult VARCHAR(30),

        CONSTRAINT FK_FactSupplierQuality_Supplier
            FOREIGN KEY (SupplierKey)
            REFERENCES dw.DimSupplier(SupplierKey),

        CONSTRAINT FK_FactSupplierQuality_Product
            FOREIGN KEY (ProductKey)
            REFERENCES dw.DimProduct(ProductKey),

        CONSTRAINT FK_FactSupplierQuality_Date
            FOREIGN KEY (DateKey)
            REFERENCES dw.DimDate(DateKey)
    );
END;
GO

SELECT
    s.name AS SchemaName,
    t.name AS TableName
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
WHERE s.name = 'dw'
ORDER BY t.name;

--Order mapping check

USE SupplyChainRiskDB;
GO

SELECT
    COUNT(*) AS StagingOrders
FROM stg.Orders;

SELECT
    COUNT(*) AS MappedOrders
FROM stg.Orders o
INNER JOIN dw.DimSupplier s
    ON o.SupplierID = s.SupplierID
INNER JOIN dw.DimProduct p
    ON o.ProductID = p.ProductID
INNER JOIN dw.DimWarehouse w
    ON o.WarehouseID = w.WarehouseID
INNER JOIN dw.DimDate od
    ON o.OrderDate = od.FullDate
INNER JOIN dw.DimDate ed
    ON o.ExpectedDeliveryDate = ed.FullDate;

--shipment mapping check

SELECT
    COUNT(*) AS StagingShipments
FROM stg.Shipments;

SELECT
    COUNT(*) AS MappedShipments
FROM stg.Shipments sh
INNER JOIN dw.DimSupplier s
    ON sh.SupplierID = s.SupplierID
INNER JOIN dw.DimProduct p
    ON sh.ProductID = p.ProductID
INNER JOIN dw.DimWarehouse w
    ON sh.WarehouseID = w.WarehouseID
INNER JOIN dw.DimCarrier c
    ON sh.CarrierID = c.CarrierID
INNER JOIN dw.DimDate sd
    ON sh.ShipDate = sd.FullDate
INNER JOIN dw.DimDate pd
    ON sh.PromisedDate = pd.FullDate
INNER JOIN dw.DimDate dd
    ON sh.DeliveryDate = dd.FullDate;

--inventory mapping check

SELECT
    COUNT(*) AS StagingInventory
FROM stg.Inventory;

SELECT
    COUNT(*) AS MappedInventory
FROM stg.Inventory i
INNER JOIN dw.DimProduct p
    ON i.ProductID = p.ProductID
INNER JOIN dw.DimWarehouse w
    ON i.WarehouseID = w.WarehouseID
INNER JOIN dw.DimDate d
    ON i.SnapshotDate = d.FullDate;

--supplier quality mapping check

SELECT
    COUNT(*) AS StagingQuality
FROM stg.SupplierQuality;

SELECT
    COUNT(*) AS MappedQuality
FROM stg.SupplierQuality q
INNER JOIN dw.DimSupplier s
    ON q.SupplierID = s.SupplierID
INNER JOIN dw.DimProduct p
    ON q.ProductID = p.ProductID
INNER JOIN dw.DimDate d
    ON q.InspectionDate = d.FullDate;

--clear the fact table

TRUNCATE TABLE dw.FactOrders;
TRUNCATE TABLE dw.FactShipments;
TRUNCATE TABLE dw.FactInventory;
TRUNCATE TABLE dw.FactSupplierQuality;
GO

--load factorder

INSERT INTO dw.FactOrders
(
    OrderID,
    SupplierKey,
    ProductKey,
    WarehouseKey,
    OrderDateKey,
    ExpectedDeliveryDateKey,
    OrderQuantity,
    UnitCost,
    OrderValue,
    OrderStatus
)
SELECT
    o.OrderID,
    s.SupplierKey,
    p.ProductKey,
    w.WarehouseKey,
    od.DateKey,
    ed.DateKey,
    o.OrderQuantity,
    o.UnitCost,
    o.OrderValue,
    o.OrderStatus
FROM stg.Orders o

INNER JOIN dw.DimSupplier s
    ON o.SupplierID = s.SupplierID

INNER JOIN dw.DimProduct p
    ON o.ProductID = p.ProductID

INNER JOIN dw.DimWarehouse w
    ON o.WarehouseID = w.WarehouseID

INNER JOIN dw.DimDate od
    ON o.OrderDate = od.FullDate

INNER JOIN dw.DimDate ed
    ON o.ExpectedDeliveryDate = ed.FullDate;
GO

SELECT TOP 10 *
FROM dw.FactOrders;

--load factshipments

INSERT INTO dw.FactShipments
(
    ShipmentID,
    OrderID,
    SupplierKey,
    ProductKey,
    WarehouseKey,
    CarrierKey,
    ShipDateKey,
    PromisedDateKey,
    DeliveryDateKey,
    QuantityShipped,
    ShippingCost,
    QualityScore,
    DamagedQuantity,
    DeliveryDays,
    DelayDays,
    ShipmentStatus
)
SELECT
    sh.ShipmentID,
    sh.OrderID,
    s.SupplierKey,
    p.ProductKey,
    w.WarehouseKey,
    c.CarrierKey,
    sd.DateKey,
    pd.DateKey,
    dd.DateKey,
    sh.QuantityShipped,
    sh.ShippingCost,
    sh.QualityScore,
    sh.DamagedQuantity,
    sh.DeliveryDays,
    sh.DelayDays,
    sh.ShipmentStatus
FROM stg.Shipments sh

INNER JOIN dw.DimSupplier s
    ON sh.SupplierID = s.SupplierID

INNER JOIN dw.DimProduct p
    ON sh.ProductID = p.ProductID

INNER JOIN dw.DimWarehouse w
    ON sh.WarehouseID = w.WarehouseID

INNER JOIN dw.DimCarrier c
    ON sh.CarrierID = c.CarrierID

INNER JOIN dw.DimDate sd
    ON sh.ShipDate = sd.FullDate

INNER JOIN dw.DimDate pd
    ON sh.PromisedDate = pd.FullDate

INNER JOIN dw.DimDate dd
    ON sh.DeliveryDate = dd.FullDate;
GO

--load factinventory

INSERT INTO dw.FactInventory
(
    InventoryRecordID,
    ProductKey,
    WarehouseKey,
    DateKey,
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
    i.InventoryRecordID,
    p.ProductKey,
    w.WarehouseKey,
    d.DateKey,
    i.CurrentStock,
    i.ReservedStock,
    i.AvailableStock,
    i.ReorderLevel,
    i.SafetyStockLevel,
    i.AvgDailyDemand,
    i.StockCoverageDays,
    i.InventoryValue,
    i.RiskStatus,
    i.WarehouseUtilizationPct
FROM stg.Inventory i

INNER JOIN dw.DimProduct p
    ON i.ProductID = p.ProductID

INNER JOIN dw.DimWarehouse w
    ON i.WarehouseID = w.WarehouseID

INNER JOIN dw.DimDate d
    ON i.SnapshotDate = d.FullDate;
GO

--load factsupplyquality

INSERT INTO dw.FactSupplierQuality
(
    InspectionID,
    OrderID,
    SupplierKey,
    ProductKey,
    DateKey,
    InspectedQuantity,
    AcceptedQuantity,
    RejectedQuantity,
    DefectQuantity,
    QualityScore,
    InspectionResult
)
SELECT
    q.InspectionID,
    q.OrderID,
    s.SupplierKey,
    p.ProductKey,
    d.DateKey,
    q.InspectedQuantity,
    q.AcceptedQuantity,
    q.RejectedQuantity,
    q.DefectQuantity,
    q.QualityScore,
    q.InspectionResult
FROM stg.SupplierQuality q

INNER JOIN dw.DimSupplier s
    ON q.SupplierID = s.SupplierID

INNER JOIN dw.DimProduct p
    ON q.ProductID = p.ProductID

INNER JOIN dw.DimDate d
    ON q.InspectionDate = d.FullDate;
GO

--verify warehouse

SELECT 'DimSupplier' AS TableName, COUNT(*) AS Count
FROM dw.DimSupplier

UNION ALL
SELECT 'DimProduct', COUNT(*) FROM dw.DimProduct

UNION ALL
SELECT 'DimWarehouse', COUNT(*) FROM dw.DimWarehouse

UNION ALL
SELECT 'DimCarrier', COUNT(*) FROM dw.DimCarrier

UNION ALL
SELECT 'DimDate', COUNT(*) FROM dw.DimDate

UNION ALL
SELECT 'FactOrders', COUNT(*) FROM dw.FactOrders

UNION ALL
SELECT 'FactShipments', COUNT(*) FROM dw.FactShipments

UNION ALL
SELECT 'FactInventory', COUNT(*) FROM dw.FactInventory

UNION ALL
SELECT 'FactSupplierQuality', COUNT(*) FROM dw.FactSupplierQuality;

