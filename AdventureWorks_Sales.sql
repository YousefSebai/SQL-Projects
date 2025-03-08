USE AdventureWorks2022;
SELECT * FROM Sales.Customer;
go
SELECT * FROM Sales.SalesOrderHeader;
go
SELECT * FROM Sales.SalesTerritory;
go
SELECT * FROM Sales.SalesOrderDetail;
go
SELECT* FROM Production.ProductSubcategory;
go
SELECT * FROM Production.Product

----------- Knowing THe data Type of COlumns 
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'SalesOrderDetail'
  AND TABLE_SCHEMA = 'Sales';



-------- Removing Unnecessary columns
ALTER TABLE Sales.SalesOrderDetail
DROP COLUMN CarrierTrackingNumber;


-------- Checking Missing Values



SELECT * FROM Sales.SalesOrderDetail
WHERE  
   OrderQty IS NULL
   OR UnitPrice IS NULL
   OR SpecialOfferID IS NULL
   OR SalesOrderID IS NUll
   OR rowguid IS NULL
   OR ModifiedDate IS NUll


---- Now WE See WE dont Have Any NUll Values  
----- Lets  Check the Duplicates
----- We Use a unique Identifier for checking Duplicates

with cte as (
SELECT * , ROW_NUMBER() OVER(PARTITION BY SalesOrderDetailID order by SalesOrderID) as dup_l 
FROM Sales.SalesOrderDetail

)
SELECT * FROM cte where dup_l > 1 ;


------ Another Way On Checking Duplicates
SELECT SalesOrderDetailID, COUNT(*) AS duplicate_count
FROM Sales.SalesOrderDetail
GROUP BY SalesOrderDetailID
HAVING COUNT(*) > 1;

------------------------------ Checking Outliers Above 
SELECT UnitPrice
FROM Sales.SalesOrderDetail
WHERE UnitPrice > (SELECT AVG(UnitPrice) + 3 * STDEV(UnitPrice) FROM Sales.SalesOrderDetail);

------------------------- Checking Outliers Below
SELECT UnitPrice
FROM Sales.SalesOrderDetail
WHERE  UnitPrice < (SELECT AVG(UnitPrice) - 3 * STDEV(UnitPrice) FROM Sales.SalesOrderDetail);
-------------------------------------------------------------- No Outliers Below

------------------- Finding the Cheapest Product
SELECT 
    p.ProductID, 
    p.Name, 
    MIN(o.UnitPrice) AS Price
FROM Sales.SalesOrderDetail o
LEFT JOIN Production.Product p
ON o.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY Price ASC;
------------------- Expensive Product
SELECT 
    p.ProductID, 
    p.Name, 
    MAX(o.UnitPrice) AS Price
FROM Sales.SalesOrderDetail o
LEFT JOIN Production.Product p
ON o.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY Price desc;



  ------------------ Indentifying KPis and Trends
ALTER TABLE Sales.SalesOrderDetail
ADD Year AS YEAR(ModifiedDate); 
ALTER TABLE Sales.SalesOrderDetail
ADD Month AS Format(ModifiedDate, 'MMM');

------------------------- Total Sales 
SELECT SUM(LineTotal) Total_Sales
FROM Sales.SalesOrderDetail

SELECT Year , SUM(OrderQty)  as Total_Quantity , Sum(LineTotal) as Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY Year 
Order by Total_Quantity Desc ; 

------------------------- Sales by Month 
SELECT Year, Month, SUM(OrderQty) AS Total_QTY_month, SUM(LineTotal) AS Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY Year, Month
ORDER BY Year, Total_QTY_month DESC;

----------------------------------- Another Way of Identifying Trends Over Time
SELECT DATETRUNC(Month , ModifiedDate) Months_Sales , SUM(LineTotal) as Total_Sales 
FROM  Sales.SalesOrderDetail
GROUP BY DATETRUNC(Month , ModifiedDate)
ORDER BY SUM(LineTotal) desc;
---------------------------------------------------------- Average Sales Per Year
SELECT  AVG(LineTotal) as Total_Sales 
FROM  Sales.SalesOrderDetail

ORDER BY AVG(LineTotal) desc;

-------------- Number of Products Sold
SELECT COUNT(DISTINCT ProductID) as Num_of_products
FROM Sales.SalesOrderDetail;



--------- The top 10  Product Sold 
SELECT top(10) p.Name, p.ProductID , Sum(o.OrderQty) as Total_quantity , SUM(o.LineTotal) as Total_Sales
FROM Sales.SalesOrderDetail o
Left JOIN Production.Product p 
ON o.ProductID = p.ProductID
GROUP by p.Name , p.ProductID
Order by Total_quantity desc ;


------------ Bottom Products Sold
SELECT top(30) p.Name, p.ProductID , Sum(o.OrderQty) as Total_quantity , SUM(LineTotal) as Total_Sales
FROM Sales.SalesOrderDetail o
Left JOIN Production.Product p 
ON o.ProductID = p.ProductID
GROUP by p.Name , p.ProductID
Order by Total_quantity asc ;
------------------------------------------------------ Product Sub Category sales 
SELECT ps.Name AS Subcategory, SUM(sod.LineTotal) AS Total_Sales
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
GROUP BY ps.Name
ORDER BY Total_Sales DESC;

----------------------------------------------------  Sales by Territory 
SELECT st.Name AS Territory, SUM(sod.LineTotal) AS Total_Sales
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY st.Name
ORDER BY Total_Sales DESC;
----------------------------------------------------- Most Profitable Product
-- Profit by Product
SELECT p.ProductID, p.Name, SUM(sod.LineTotal) AS Revenue, 
       SUM(sod.OrderQty * p.StandardCost) AS Cost,
       SUM(sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS Profit
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p ON sod.ProductID = p.ProductID
GROUP BY p.ProductID, p.Name
ORDER BY Profit DESC;
-------------------------------------------------- Customer Behavior Analysis
SELECT 
    c.CustomerID, 
    CONCAT(p.FirstName, ' '  ,p.LastName) as Full_Name ,
    
    SUM(sod.LineTotal) AS Total_Spent
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID -- Join to get customer names
GROUP BY 
    c.CustomerID, 
    CONCAT(p.FirstName,' '  ,p.LastName)
ORDER BY 
    Total_Spent DESC;


------------ Cumalative Sum of Sales BY Years
SELECT Year , SUM(Total_Sales) OVER (order by Year) as Cum_Sales
FROM (
SELECT Year ,  SUM(LineTotal) as Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY Year ) as t ;

----------------------------------------------  Sales by Quarter 

SELECT DATEPART(QUARTER, ModifiedDate) AS Quarter, SUM(LineTotal) AS Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY DATEPART(QUARTER, ModifiedDate)
ORDER BY Quarter;

------------- Lets Check The Performance Over Years 

SELECT Year , Total_Sales , LAG(Total_Sales) OVER(order by Year) as Laggs,
(Total_Sales  - LAG(Total_Sales) OVER(order by Year)) as Per_Over_years ,
(CASE WHEN Total_Sales  - LAG(Total_Sales) OVER(order by Year) > 0 THEN 'Sales_Increases'
WHEN Total_Sales  - LAG(Total_Sales) OVER(order by Year) < 0 THEN 'Sales_Decreases'
Else 'Constant'
END ) as Performance 


FROM (
SELECT Year ,  SUM(LineTotal) as Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY Year ) as t ;
----------------------------- Calculating Percentage Change 
SELECT Year, Total_Sales,
       LAG(Total_Sales) OVER (ORDER BY Year) AS Previous_Year_Sales,
       (Total_Sales - LAG(Total_Sales) OVER (ORDER BY Year)) / LAG(Total_Sales) OVER (ORDER BY Year) * 100 AS Percent_Change
FROM (
    SELECT Year, SUM(LineTotal) AS Total_Sales
    FROM Sales.SalesOrderDetail
    GROUP BY Year
) AS t;

------------------------- 2014 The Sales decreases Because it Contains the Sales of Only the First 6 Months of the Year

 


------------------------------------------------------------------------------------- Checking The Impact of Disscounts
SELECT SpecialOfferID, UnitPriceDiscount , SUM(LineTotal) AS Total_Sales
FROM Sales.SalesOrderDetail
GROUP BY SpecialOfferID ,UnitPriceDiscount
ORDER BY Total_Sales DESC;
------------------------------------------------------------------------------------------------------------------
