
#query1

CREATE TABLE Regions (
    RegionID INT PRIMARY KEY,
    RegionName VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO Regions (RegionID, RegionName)
VALUES
(1, 'North'),
(2, 'South'),
(3, 'West');

UPDATE Stores
SET RegionID =
    CASE
        WHEN UPPER(TRIM(RegionRaw)) IN ('N', 'NORTH') THEN 1
        WHEN UPPER(TRIM(RegionRaw)) IN ('S', 'SOUTH') THEN 2
        WHEN UPPER(TRIM(RegionRaw)) IN ('W', 'WEST') THEN 3
        ELSE NULL
    END
WHERE StoreID > 0;

SELECT
    s.StoreID,
    s.StoreName,
    s.RegionRaw,
    r.RegionID,
    r.RegionName
FROM Stores s
LEFT JOIN Regions r
ON s.RegionID = r.RegionID
ORDER BY s.StoreID;


SELECT
    StoreID,
    StoreName,
    RegionRaw
FROM Stores
WHERE RegionID IS NULL;


#query 2
SELECT
    OrderItemID,
    COUNT(*) AS Duplicate_Count
FROM OrderItems
GROUP BY OrderItemID
HAVING COUNT(*) > 1;

SELECT *
FROM OrderItems
WHERE OrderItemID IN (
    SELECT OrderItemID
    FROM OrderItems
    GROUP BY OrderItemID
    HAVING COUNT(*) > 1
)
ORDER BY OrderItemID, LoadedAt DESC;


DROP TABLE IF EXISTS CleanOrderItems;

CREATE TABLE CleanOrderItems AS
SELECT
    RowID,
    OrderItemID,
    OrderID,
    ProductID,
    Quantity,
    UnitPrice,
    LoadedAt
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY OrderItemID
            ORDER BY LoadedAt DESC, RowID DESC
        ) AS rn
    FROM OrderItems
) AS RankedItems
WHERE rn = 1;


ALTER TABLE CleanOrderItems
ADD PRIMARY KEY (OrderItemID);


SELECT
    OrderItemID,
    COUNT(*) AS Total
FROM CleanOrderItems
GROUP BY OrderItemID
HAVING COUNT(*) > 1;

SELECT
    (SELECT COUNT(*) FROM OrderItems) AS Original_Rows,
    (SELECT COUNT(*) FROM CleanOrderItems) AS Cleaned_Rows;

#query 4
SELECT
    o.OrderID,
    o.CustomerID,
    c.CustomerName
FROM Orders o
INNER JOIN Customers c
ON o.CustomerID = c.CustomerID
ORDER BY o.OrderID;

#query 5
 
SELECT
    o.OrderID,
    o.CustomerID
FROM Orders o
LEFT JOIN Customers c
ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

#query 6
SELECT
    c.CustomerID,
    c.CustomerName
FROM Customers c
LEFT JOIN Orders o
ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;


#query 7 
SELECT
    OrderItemID,
    COUNT(ReturnID) AS Return_Count,
    SUM(ReturnQuantity) AS Total_Returned_Units
FROM Returns
GROUP BY OrderItemID
HAVING COUNT(ReturnID) > 1
ORDER BY OrderItemID;




#query 8
SELECT
    r.RegionName,
    COUNT(DISTINCT o.OrderID) AS Completed_Orders,
    ROUND(
        SUM(oi.Quantity * oi.UnitPrice), 2
    ) AS Gross_Sales
FROM Orders o

INNER JOIN Stores s
    ON o.StoreID = s.StoreID

INNER JOIN Regions r
    ON s.RegionID = r.RegionID

INNER JOIN CleanOrderItems oi
    ON o.OrderID = oi.OrderID

WHERE o.OrderStatus = 'Completed'

AND o.OrderDate >= '2026-10-01'
AND o.OrderDate < '2026-11-01'

GROUP BY r.RegionID, r.RegionName

ORDER BY Gross_Sales DESC;


SELECT
    r.RegionName,

    ROUND(
        SUM(ret.ReturnQuantity * oi.UnitPrice), 2
    ) AS Return_Value

FROM Returns ret

INNER JOIN CleanOrderItems oi
    ON ret.OrderItemID = oi.OrderItemID

INNER JOIN Orders o
    ON oi.OrderID = o.OrderID

INNER JOIN Stores s
    ON o.StoreID = s.StoreID

INNER JOIN Regions r
    ON s.RegionID = r.RegionID

WHERE ret.ReturnDate >= '2026-10-01'
AND ret.ReturnDate < '2026-11-01'

AND o.OrderStatus = 'Completed'

GROUP BY r.RegionID, r.RegionName

ORDER BY Return_Value DESC;

WITH GrossSales AS (

    SELECT
        r.RegionID,
        r.RegionName,
        COUNT(DISTINCT o.OrderID) AS Completed_Orders,

        SUM(oi.Quantity * oi.UnitPrice) AS Gross_Sales

    FROM Regions r

    LEFT JOIN Stores s
        ON r.RegionID = s.RegionID

    LEFT JOIN Orders o
        ON s.StoreID = o.StoreID
        AND o.OrderStatus = 'Completed'
        AND o.OrderDate >= '2026-10-01'
        AND o.OrderDate < '2026-11-01'

    LEFT JOIN CleanOrderItems oi
        ON o.OrderID = oi.OrderID

    GROUP BY r.RegionID, r.RegionName
),

ReturnSales AS (

    SELECT
        r.RegionID,

        SUM(ret.ReturnQuantity * oi.UnitPrice) AS Return_Value

    FROM Returns ret

    INNER JOIN CleanOrderItems oi
        ON ret.OrderItemID = oi.OrderItemID

    INNER JOIN Orders o
        ON oi.OrderID = o.OrderID

    INNER JOIN Stores s
        ON o.StoreID = s.StoreID

    INNER JOIN Regions r
        ON s.RegionID = r.RegionID

    WHERE ret.ReturnDate >= '2026-10-01'
    AND ret.ReturnDate < '2026-11-01'
    AND o.OrderStatus = 'Completed'

    GROUP BY r.RegionID
)

SELECT
    g.RegionName,
    g.Completed_Orders,

    ROUND(COALESCE(g.Gross_Sales, 0), 2) AS Gross_Sales,

    ROUND(COALESCE(rs.Return_Value, 0), 2) AS Return_Value,

    ROUND(
        COALESCE(g.Gross_Sales, 0)
        - COALESCE(rs.Return_Value, 0), 2
    ) AS Net_Sales

FROM GrossSales g

LEFT JOIN ReturnSales rs
    ON g.RegionID = rs.RegionID

ORDER BY Net_Sales DESC;

#query 9
WITH GrossSales AS (

    SELECT
        r.RegionID,
        r.RegionName,
        SUM(oi.Quantity * oi.UnitPrice) AS Gross_Sales

    FROM Regions r

    LEFT JOIN Stores s
        ON r.RegionID = s.RegionID

    LEFT JOIN Orders o
        ON s.StoreID = o.StoreID
        AND o.OrderStatus = 'Completed'
        AND o.OrderDate >= '2026-10-01'
        AND o.OrderDate < '2026-11-01'

    LEFT JOIN CleanOrderItems oi
        ON o.OrderID = oi.OrderID

    GROUP BY r.RegionID, r.RegionName
),

ReturnSales AS (

    SELECT
        r.RegionID,
        SUM(ret.ReturnQuantity * oi.UnitPrice) AS Return_Value

    FROM Returns ret

    INNER JOIN CleanOrderItems oi
        ON ret.OrderItemID = oi.OrderItemID

    INNER JOIN Orders o
        ON oi.OrderID = o.OrderID

    INNER JOIN Stores s
        ON o.StoreID = s.StoreID

    INNER JOIN Regions r
        ON s.RegionID = r.RegionID

    WHERE ret.ReturnDate >= '2026-10-01'
    AND ret.ReturnDate < '2026-11-01'
    AND o.OrderStatus = 'Completed'

    GROUP BY r.RegionID
),

RegionTotals AS (

    SELECT
        g.RegionName,
        COALESCE(g.Gross_Sales, 0) AS Gross_Sales,
        COALESCE(rs.Return_Value, 0) AS Return_Value,

        COALESCE(g.Gross_Sales, 0)
        - COALESCE(rs.Return_Value, 0) AS Net_Sales

    FROM GrossSales g

    LEFT JOIN ReturnSales rs
        ON g.RegionID = rs.RegionID
)

SELECT
    RegionName,
    ROUND(Gross_Sales, 2) AS Gross_Sales,
    ROUND(Return_Value, 2) AS Return_Value,
    ROUND(Net_Sales, 2) AS Net_Sales,

    RANK() OVER (
        ORDER BY Gross_Sales DESC
    ) AS Gross_Rank,

    RANK() OVER (
        ORDER BY Net_Sales DESC
    ) AS Net_Rank

FROM RegionTotals

ORDER BY Net_Sales DESC, RegionName ASC;


WITH Sales AS (

    SELECT
        r.RegionName,
        SUM(oi.Quantity * oi.UnitPrice) AS Gross_Sales

    FROM Regions r

    INNER JOIN Stores s
        ON r.RegionID = s.RegionID

    INNER JOIN Orders o
        ON s.StoreID = o.StoreID

    INNER JOIN CleanOrderItems oi
        ON o.OrderID = oi.OrderID

    WHERE o.OrderStatus = 'Completed'
    AND o.OrderDate >= '2026-10-01'
    AND o.OrderDate < '2026-11-01'

    GROUP BY r.RegionID, r.RegionName
)

SELECT *
FROM Sales
ORDER BY Gross_Sales DESC, RegionName ASC
LIMIT 1;

#query 10

SELECT
    r.RegionName,
    s.StoreID,
    s.StoreName,

    COUNT(DISTINCT o.OrderID) AS Completed_Orders,

    ROUND(
        SUM(oi.Quantity * oi.UnitPrice), 2
    ) AS Gross_Sales

FROM Stores s

INNER JOIN Regions r
    ON s.RegionID = r.RegionID

LEFT JOIN Orders o
    ON s.StoreID = o.StoreID
    AND o.OrderStatus = 'Completed'
    AND o.OrderDate >= '2026-10-01'
    AND o.OrderDate < '2026-11-01'

LEFT JOIN CleanOrderItems oi
    ON o.OrderID = oi.OrderID

GROUP BY
    r.RegionID,
    r.RegionName,
    s.StoreID,
    s.StoreName

ORDER BY
    r.RegionName,
    Gross_Sales DESC;
    
    
    SELECT
    r.RegionName,
    s.StoreID,
    s.StoreName,

    ROUND(
        SUM(ret.ReturnQuantity * oi.UnitPrice), 2
    ) AS Return_Value

FROM Returns ret

INNER JOIN CleanOrderItems oi
    ON ret.OrderItemID = oi.OrderItemID

INNER JOIN Orders o
    ON oi.OrderID = o.OrderID

INNER JOIN Stores s
    ON o.StoreID = s.StoreID

INNER JOIN Regions r
    ON s.RegionID = r.RegionID

WHERE ret.ReturnDate >= '2026-10-01'
AND ret.ReturnDate < '2026-11-01'

AND o.OrderStatus = 'Completed'

GROUP BY
    r.RegionID,
    r.RegionName,
    s.StoreID,
    s.StoreName

ORDER BY
    r.RegionName,
    Return_Value DESC;
    
    
 WITH GrossSales AS (

    SELECT
        s.StoreID,

        COUNT(DISTINCT o.OrderID) AS Completed_Orders,

        SUM(oi.Quantity * oi.UnitPrice) AS Gross_Sales

    FROM Stores s

    LEFT JOIN Orders o
        ON s.StoreID = o.StoreID
        AND o.OrderStatus = 'Completed'
        AND o.OrderDate >= '2026-10-01'
        AND o.OrderDate < '2026-11-01'

    LEFT JOIN CleanOrderItems oi
        ON o.OrderID = oi.OrderID

    GROUP BY s.StoreID
),

ReturnSales AS (

    SELECT
        s.StoreID,

        SUM(ret.ReturnQuantity * oi.UnitPrice) AS Return_Value

    FROM Returns ret

    INNER JOIN CleanOrderItems oi
        ON ret.OrderItemID = oi.OrderItemID

    INNER JOIN Orders o
        ON oi.OrderID = o.OrderID

    INNER JOIN Stores s
        ON o.StoreID = s.StoreID

    WHERE ret.ReturnDate >= '2026-10-01'
    AND ret.ReturnDate < '2026-11-01'
    AND o.OrderStatus = 'Completed'

    GROUP BY s.StoreID
),

StoreTotals AS (

    SELECT
        r.RegionName,
        s.StoreID,
        s.StoreName,

        COALESCE(g.Completed_Orders, 0) AS Completed_Orders,

        COALESCE(g.Gross_Sales, 0) AS Gross_Sales,

        COALESCE(rs.Return_Value, 0) AS Return_Value,

        COALESCE(g.Gross_Sales, 0)
        - COALESCE(rs.Return_Value, 0) AS Net_Sales

    FROM Stores s

    INNER JOIN Regions r
        ON s.RegionID = r.RegionID

    LEFT JOIN GrossSales g
        ON s.StoreID = g.StoreID

    LEFT JOIN ReturnSales rs
        ON s.StoreID = rs.StoreID
),

RankedStores AS (

    SELECT
        *,

        SUM(Net_Sales) OVER (
            PARTITION BY RegionName
        ) AS Region_Net_Sales,

        RANK() OVER (
            PARTITION BY RegionName
            ORDER BY Net_Sales DESC
        ) AS Store_Rank,

        ROW_NUMBER() OVER (
            PARTITION BY RegionName
            ORDER BY Net_Sales DESC, StoreID ASC
        ) AS Winner_Row

    FROM StoreTotals
)

SELECT
    RegionName,
    StoreID,
    StoreName,
    Completed_Orders,

    ROUND(Gross_Sales, 2) AS Gross_Sales,

    ROUND(Return_Value, 2) AS Return_Value,

    ROUND(Net_Sales, 2) AS Net_Sales,

    Store_Rank,

    CASE
        WHEN Winner_Row = 1 THEN 'Winner'
        ELSE 'Other'
    END AS Store_Result,

    CASE
        WHEN Region_Net_Sales = 0 THEN NULL

        ELSE ROUND(
            Net_Sales / Region_Net_Sales * 100, 2
        )
    END AS Region_Share_Percentage

FROM RankedStores

ORDER BY
    RegionName,
    Store_Rank,
    StoreID;   
    
    
#query 11

SELECT
    r.RegionName,

    SUM(ret.ReturnQuantity * oi.UnitPrice) AS Return_Value

FROM Returns ret

INNER JOIN CleanOrderItems oi
    ON ret.OrderItemID = oi.OrderItemID

INNER JOIN Orders o
    ON oi.OrderID = o.OrderID

INNER JOIN Stores s
    ON o.StoreID = s.StoreID

INNER JOIN Regions r
    ON s.RegionID = r.RegionID

WHERE ret.ReturnDate >= '2026-10-01'
AND ret.ReturnDate < '2026-11-01'

AND o.OrderStatus = 'Completed'

GROUP BY r.RegionID, r.RegionName

ORDER BY Return_Value DESC, r.RegionName ASC

LIMIT 1;

WITH ReturnByRegion AS (

    SELECT
        r.RegionID,
        r.RegionName,

        SUM(ret.ReturnQuantity * oi.UnitPrice) AS Return_Value

    FROM Returns ret

    INNER JOIN CleanOrderItems oi
        ON ret.OrderItemID = oi.OrderItemID

    INNER JOIN Orders o
        ON oi.OrderID = o.OrderID

    INNER JOIN Stores s
        ON o.StoreID = s.StoreID

    INNER JOIN Regions r
        ON s.RegionID = r.RegionID

    WHERE ret.ReturnDate >= '2026-10-01'
    AND ret.ReturnDate < '2026-11-01'
    AND o.OrderStatus = 'Completed'

    GROUP BY r.RegionID, r.RegionName
),

TopRegion AS (

    SELECT *
    FROM ReturnByRegion
    ORDER BY Return_Value DESC, RegionName ASC
    LIMIT 1
),

CategoryReturns AS (

    SELECT
        p.Category,

        SUM(ret.ReturnQuantity * oi.UnitPrice) AS Category_Return

    FROM Returns ret

    INNER JOIN CleanOrderItems oi
        ON ret.OrderItemID = oi.OrderItemID

    INNER JOIN Orders o
        ON oi.OrderID = o.OrderID

    INNER JOIN Stores s
        ON o.StoreID = s.StoreID

    INNER JOIN Products p
        ON oi.ProductID = p.ProductID

    INNER JOIN TopRegion tr
        ON s.RegionID = tr.RegionID

    WHERE ret.ReturnDate >= '2026-10-01'
    AND ret.ReturnDate < '2026-11-01'
    AND o.OrderStatus = 'Completed'

    GROUP BY p.Category
)

SELECT
    tr.RegionName,
    cr.Category,

    ROUND(cr.Category_Return, 2) AS Category_Return,

    ROUND(tr.Return_Value, 2) AS Total_Region_Return,

    ROUND(
        cr.Category_Return / NULLIF(tr.Return_Value, 0) * 100,
        2
    ) AS Return_Share_Percentage

FROM CategoryReturns cr

CROSS JOIN TopRegion tr

ORDER BY
    cr.Category_Return DESC,
    cr.Category ASC;


#query 12
SELECT
    r.RegionName,
    COUNT(DISTINCT o.OrderID) AS Total_Orders,

    ROUND(
        SUM(oi.Quantity * oi.UnitPrice), 2
    ) AS Gross_Revenue,

    ROUND(
        AVG(oi.UnitPrice), 2
    ) AS Average_Unit_Price,

    COUNT(DISTINCT o.CustomerID) AS Customers

FROM Regions r

INNER JOIN Stores s
    ON r.RegionID = s.RegionID

INNER JOIN Orders o
    ON s.StoreID = o.StoreID

INNER JOIN CleanOrderItems oi
    ON o.OrderID = oi.OrderID

WHERE o.OrderStatus = 'Completed'

AND o.OrderDate >= '2026-10-01'
AND o.OrderDate < '2026-11-01'

GROUP BY r.RegionID, r.RegionName

ORDER BY Gross_Revenue DESC;






