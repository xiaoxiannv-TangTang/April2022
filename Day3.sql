USE Northwind
GO



--1. List all cities that have both Employees and Customers.
-- use join 
SELECT DISTINCT E.City
FROM Employees  E INNER JOIN Customers C ON E.City = C.City 

-- OR USE INTERSECT to get the intersection 
SELECT DISTINCT city from Employees
INTERSECT 
SELECT DISTINCT city from Customers


--2.      List all cities that have Customers but no Employee.
--SELECT DISTINCT CITY FROM Customers
--a.      Use sub-query
SELECT DISTINCT City 
FROM Customers 
WHERE City NOT IN  (SELECT DISTINCT City FROM Employees)

--b.      Do not use sub-query
SELECT DISTINCT C.City
FROM Employees  E RIGHT JOIN Customers C ON E.City = C.City 
WHERE E.City IS NULL

-- we can also use EXCEPT, efficiency seems the best 26%
SELECT City FROM Customers 
EXCEPT 
SELECT City FROM Employees

--3. List all products and their total order quantities throughout all orders.
SELECT P.ProductID, P.ProductName,  SUM(OD.Quantity) TotalQuantityOrdered
FROM [Order Details]  OD RIGHT JOIN Products P ON P.ProductID = OD.ProductID
GROUP BY P.ProductID, P.ProductName

-- if we want to sort by TotalQuantityOrdered DESC
SELECT P.ProductID, P.ProductName,  SUM(OD.Quantity) TotalQuantityOrdered
FROM [Order Details]  OD RIGHT JOIN Products P ON P.ProductID = OD.ProductID
GROUP BY P.ProductID, P.ProductName
ORDER BY TotalQuantityOrdered DESC


--4.      List all Customer Cities and total products ordered by that city.
--
SELECT C.City, SUM(OD.Quantity) TotalQuantityOrdered
FROM [Order Details] OD INNER JOIN Orders O ON OD.OrderID = O.OrderID RIGHT JOIN Customers C ON C.CustomerID = O.CustomerID
GROUP BY C.City

-- if we want to sort by quantity desc 
SELECT C.City, SUM(OD.Quantity) TotalQuantityOrdered
FROM [Order Details] OD INNER JOIN Orders O ON OD.OrderID = O.OrderID RIGHT JOIN Customers C ON C.CustomerID = O.CustomerID
GROUP BY C.City
ORDER BY TotalQuantityOrdered DESC

--5.      List all Customer Cities that have at least two customers.
--direct approach cost: 9%
SELECT City, COUNT(CustomerID) TotalNbOfCustomers
FROM Customers 
GROUP BY City
HAVING COUNT(CustomerID) >= 2
--a.      Use union
-- except 0 and 1 , union 0 and 1  cost:57%
SELECT City, COUNT(CustomerID) TotalNbOfCustomers  FROM Customers
GROUP BY City
EXCEPT 
(
SELECT City, COUNT(CustomerID) TotalNbOfCustomers FROM Customers GROUP BY City HAVING COUNT(CustomerID) = 1
UNION 
SELECT City , COUNT(CustomerID) TotalNbOfCustomers FROM Customers GROUP BY City HAVING COUNT(CustomerID) = 0
)
--b.      Use sub-query and no union cost:34%
SELECT City, COUNT(CustomerID) TotalNbOfCustomers 
FROM Customers
GROUP BY City
EXCEPT 
(
SELECT City , COUNT(CustomerID) TotalNbOfCustomers
FROM Customers 
GROUP BY City 
HAVING COUNT(CustomerID) <2
)

--6.      List all Customer Cities that have ordered at least two <different kinds> of products.
-- CHECK CATEGORIEID for different kinds of products
SELECT C.City,  Count(DISTINCT P.CategoryID) KindsOfProducts
FROM Customers C INNER JOIN Orders O ON O.CustomerID = C.CustomerID INNER JOIN [Order Details] OD  ON OD.OrderID = O.OrderID 
INNER JOIN Products P ON P.ProductID = OD.ProductID
GROUP BY C.City
HAVING Count(DISTINCT P.CategoryID) >= 2


--???? if col is in group by, and the only not aggregated col in groupby, do we need distinct? 

--7.      List all Customers who have ordered products, but have the ��ship city�� on the order different from their own customer cities.
-- 
SELECT DISTINCT C.CustomerID, C.ContactName, C.City, O.ShipCity
FROM Customers C INNER JOIN Orders O ON C.CustomerID = O.CustomerID
WHERE C.City != O.ShipCity 
 

--8.      List 5 most popular products, their average price, and the customer city that ordered most quantity of it.
--

WITH PopularTop5 
AS 
(
SELECT TOP 5 P.ProductID, P.ProductNAME, AVG(OD.UnitPrice) AvgPrice
FROM [Order Details] OD INNER JOIN Products P ON P.ProductID = OD.ProductID
GROUP BY P.ProductID,  P.ProductNAME
ORDER BY SUM(Quantity) DESC 
)

SELECT dt.ProductID, dt.ProductName,  dt.AvgPrice, dt.City, dt.TotalSold
FROM 
(SELECT OD.ProductID, P5.ProductName, P5.AvgPrice, C.City, SUM(OD.Quantity) TotalSold, RANK() OVER (Partition BY OD.ProductID Order by SUM(OD.Quantity) DESC ) AS OrderRank
FROM Customers C INNER JOIN Orders O ON C.CustomerID = O.CustomerID INNER JOIN [Order Details] OD 
ON OD.OrderID = O.OrderID INNER JOIN PopularTop5 P5 ON P5.ProductID = OD.ProductID
GROUP BY OD.ProductID, P5.ProductName, C.City, P5.AvgPrice) dt
WHERE dt.OrderRank = 1


-- we can use subquery in select 
SELECT TOP 5 OD2.ProductID, P.ProductName, AVG(OD2.UnitPrice) AvgPrice, 
(SELECT Top 1 C.City, sum(od1.quantity)
FROM [Order Details] OD1 INNER JOIN Orders O ON O.OrderID = OD1.OrderID INNER JOIN Customers C ON C.CustomerID = O.CustomerID
WHERE OD1.ProductID = OD2.ProductID
GROUP BY C.City
ORDER BY SUM(OD1.Quantity) DESC
)
FROM [Order Details] OD2 INNER JOIN Products P ON P.ProductID = OD2.ProductID
GROUP BY OD2.ProductID,  P.ProductNAME
ORDER BY SUM(OD2.Quantity) DESC 

-- what if we want to list TotalSold as well? only one col is allowed in subquery in select 






--9.      List all cities that have never ordered something but we have employees there.
--
--a.      Use sub-query 35%

SELECT E.City
FROM Employees E
WHERE E.City NOT IN (
SELECT DISTINCT City 
FROM Orders O INNER JOIN Customers C ON C.CustomerID = O.CustomerID );



--select count(distinct shipcity) from orders -- 70 different citys 
/*
select distinct city from Employees
Kirkland
London
Redmond not in O
Seattle
Tacoma  not in O */
--b.      Do not use sub-query
-- Att:  we have to use two left join to include all E.city
-- city not appear in Table Order have zero orders
-- USE JOIN  65%
SELECT distinct E.City, count(O.OrderID) TotalOrders
FROM Employees E LEFT JOIN Customers C ON C.City = E.City 
LEFT JOIN Orders O ON C.CustomerID = O.CustomerID
GROUP BY E.City
HAVING COUNT(O.OrderID) = 0 ;


--10.  List one city, if exists, that is the city from where the employee sold most orders (not the product quantity) is, 
-- and also the city of most total quantity of products ordered from. (tip: join  sub-query)

-- here , it means the city of employees, 
SELECT T1.City
FROM (
-- city with most orders
SELECT TOP 1 C.City
FROM Customers C LEFT JOIN Orders O ON O.CustomerID = C.CustomerID
GROUP BY C.City
ORDER BY COUNT(O.OrderID) DESC) T1 

INNER JOIN 
-- city with most products ordered
(SELECT TOP 1 C.City
FROM Customers C LEFT JOIN Orders O ON O.CustomerID = C.CustomerID LEFT JOIN [Order Details] OD ON OD.OrderID = O.OrderID
GROUP BY C.City
ORDER BY SUM(OD.Quantity) DESC) T2 

ON T1.City = T2.City;


--11. How do you remove the duplicates record of a table?


/*
we can use distinct * to get the table without duplicates and replace the old table with the new 
table without duplicates. 

we can also use group by or row_number to find duplicates and then delete the duplicate rows.
*/ 