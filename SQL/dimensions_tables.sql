--Creating Dimension table

USE SupplyChainRiskDB;
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

USE SupplyChainRiskDB;
GO

IF OBJECT_ID('dw.DimSupplier', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimSupplier
    (
        SupplierKey INT IDENTITY(1,1) PRIMARY KEY,
        SupplierID VARCHAR(20) NOT NULL,
        SupplierName VARCHAR(150),
        Country VARCHAR(100),
        Region VARCHAR(100),
        SupplierCategory VARCHAR(100),
        SupplierSince DATE,
        QualityRating DECIMAL(5,2),
        RiskTier VARCHAR(20),
        ActiveStatus VARCHAR(20)
    );
END;
GO


IF OBJECT_ID('dw.DimProduct', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimProduct
    (
        ProductKey INT IDENTITY(1,1) PRIMARY KEY,
        ProductID VARCHAR(20) NOT NULL,
        ProductName VARCHAR(150),
        Category VARCHAR(100),
        SubCategory VARCHAR(100),
        UnitCost DECIMAL(18,2),
        StandardPrice DECIMAL(18,2),
        ReorderLevel INT,
        SafetyStockLevel INT,
        LeadTimeDays INT
    );
END;
GO


IF OBJECT_ID('dw.DimWarehouse', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimWarehouse
    (
        WarehouseKey INT IDENTITY(1,1) PRIMARY KEY,
        WarehouseID VARCHAR(20) NOT NULL,
        WarehouseName VARCHAR(150),
        Country VARCHAR(100),
        City VARCHAR(100),
        Capacity INT,
        WarehouseType VARCHAR(50)
    );
END;
GO


IF OBJECT_ID('dw.DimCarrier', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimCarrier
    (
        CarrierKey INT IDENTITY(1,1) PRIMARY KEY,
        CarrierID VARCHAR(20) NOT NULL,
        CarrierName VARCHAR(150),
        CarrierType VARCHAR(50),
        Country VARCHAR(100),
        ServiceLevel VARCHAR(50)
    );
END;
GO

TRUNCATE TABLE dw.DimSupplier;
TRUNCATE TABLE dw.DimProduct;
TRUNCATE TABLE dw.DimWarehouse;
TRUNCATE TABLE dw.DimCarrier;
GO

--Load Supplier dimension

INSERT INTO dw.DimSupplier
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
    SupplierSince,
    QualityRating,
    RiskTier,
    ActiveStatus
FROM stg.Suppliers;
GO

--Load Product dimension

INSERT INTO dw.DimProduct
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
    UnitCost,
    StandardPrice,
    ReorderLevel,
    SafetyStockLevel,
    LeadTimeDays
FROM stg.Products;
GO

--Load Warehouse dimension

INSERT INTO dw.DimWarehouse
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
    Capacity,
    WarehouseType
FROM stg.Warehouses;
GO

--Load Carrier dimension

INSERT INTO dw.DimCarrier
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
FROM stg.Carriers;
GO

--Verify the dimension counts

SELECT 'DimSupplier' AS TableName, COUNT(*) AS Count
FROM dw.DimSupplier

UNION ALL

SELECT 'DimProduct', COUNT(*)
FROM dw.DimProduct

UNION ALL

SELECT 'DimWarehouse', COUNT(*)
FROM dw.DimWarehouse

UNION ALL

SELECT 'DimCarrier', COUNT(*)
FROM dw.DimCarrier;

SELECT TOP 10 *
FROM dw.DimSupplier;

--Create the Date dimension

IF OBJECT_ID('dw.DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimDate
    (
        DateKey INT PRIMARY KEY,
        FullDate DATE NOT NULL,
        DayNumber INT,
        DayName VARCHAR(20),
        MonthNumber INT,
        MonthName VARCHAR(20),
        QuarterNumber INT,
        QuarterName VARCHAR(10),
        YearNumber INT,
        WeekNumber INT,
        IsWeekend BIT
    );
END;
GO

TRUNCATE TABLE dw.DimDate;
GO

DECLARE @StartDate DATE = '2022-01-01';
DECLARE @EndDate DATE = '2026-12-31';

WHILE @StartDate <= @EndDate
BEGIN

    INSERT INTO dw.DimDate
    (
        DateKey,
        FullDate,
        DayNumber,
        DayName,
        MonthNumber,
        MonthName,
        QuarterNumber,
        QuarterName,
        YearNumber,
        WeekNumber,
        IsWeekend
    )
    VALUES
    (
        CONVERT(INT, FORMAT(@StartDate, 'yyyyMMdd')),
        @StartDate,
        DAY(@StartDate),
        DATENAME(WEEKDAY, @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
        DATEPART(QUARTER, @StartDate),
        CONCAT('Q', DATEPART(QUARTER, @StartDate)),
        YEAR(@StartDate),
        DATEPART(WEEK, @StartDate),
        CASE
            WHEN DATENAME(WEEKDAY, @StartDate)
                 IN ('Saturday','Sunday')
            THEN 1
            ELSE 0
        END
    );

    SET @StartDate = DATEADD(DAY, 1, @StartDate);

END;
GO

SELECT COUNT(*) AS DateRows
FROM dw.DimDate;

SELECT TOP 10 *
FROM dw.DimDate
ORDER BY FullDate;


--update

UPDATE d
SET
    d.SupplierName = s.SupplierName,
    d.Country = s.Country,
    d.Region = s.Region,
    d.SupplierCategory = s.SupplierCategory,
    d.SupplierSince = s.SupplierSince,
    d.QualityRating = s.QualityRating,
    d.RiskTier = s.RiskTier,
    d.ActiveStatus = s.ActiveStatus
FROM dw.DimSupplier d
INNER JOIN stg.Suppliers s
    ON d.SupplierID = s.SupplierID;
GO

SELECT
    SupplierKey,
    SupplierID,
    SupplierName,
    Country,
    Region
FROM dw.DimSupplier
WHERE SupplierID = 'SUP0075';