/*
=============================================================
Create Database 
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouse' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally.
	
WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/
USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse2')
BEGIN
    ALTER DATABASE DataWarehouse2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse2;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse2;
GO

USE DataWarehouse2;

/*
===============================================================================
DDL Script: Create Table
===============================================================================
Script Purpose:
    This script creates a table, dropping existing table 
    if it's already exist.
	  Run this script to re-define the DDL structure of the Table
===============================================================================
*/

IF OBJECT_ID('retail_sales', 'U') IS NOT NULL
    DROP TABLE retail_sales;
GO

CREATE TABLE retail_sales (
	    transactions_id INT PRIMARY KEY,
	    sale_date       DATE,	
	    sale_time       TIME,
	    customer_id     INT,	
	    gender          VARCHAR(10),
	    age             INT,
	    category        VARCHAR(35),
	    quantity        INT,
	    price_per_unit  FLOAT,	
	    cogs            FLOAT,
	    total_sale      FLOAT
);

/*
===============================================================================
Stored Procedure: Load Data (Source -> Table)
===============================================================================
Script Purpose:
    This stored procedure loads data into the Table from external CSV files. 
    It performs the following actions:
    - Truncates the table before loading data.
    - Uses the `BULK INSERT` command to load data from csv File to the table.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC dbo.load_dbo;
===============================================================================
*/
EXEC dbo.load_dbo;

CREATE OR ALTER PROCEDURE dbo.load_dbo AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '================================================';
		PRINT 'Loading dbo Layer';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading retail_sales Table';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		PRINT '>> Truncating Table: dbo.retail_sales';
		TRUNCATE TABLE dbo.retail_sales;
		PRINT '>> Inserting Data Into: dbo.retail_sales';
		BULK INSERT dbo.retail_sales
		FROM 'C:\Users\ASUS\Desktop\New folder (2)\SQL - Retail Sales Analysis_utf .csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading dbo Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING dbo LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END

SELECT COUNT(*) FROM retail_sales;
SELECT COUNT(DISTINCT customer_id) FROM retail_sales;
SELECT DISTINCT category FROM retail_sales;

-- Data Cleaning

SELECT * FROM retail_sales
WHERE 
    sale_date IS NULL OR sale_time IS NULL OR customer_id IS NULL OR 
    gender IS NULL OR age IS NULL OR category IS NULL OR 
    quantity IS NULL OR price_per_unit IS NULL OR cogs IS NULL;

DELETE FROM retail_sales
WHERE 
    sale_date IS NULL OR sale_time IS NULL OR customer_id IS NULL OR 
    gender IS NULL OR age IS NULL OR category IS NULL OR 
    quantity IS NULL OR price_per_unit IS NULL OR cogs IS NULL;

--Write a SQL query to retrieve all columns for sales made on '2022-11-05

SELECT *
FROM dbo.retail_sales
WHERE sale_date = '2022-11-05';

--Write a SQL query to retrieve all transactions where the category is 'Clothing' and the quantity sold is more than 4 in the month of Nov-2022:

select * 
from dbo.retail_sales
where 
category = 'clothing' and quantity >=4 and 
month(sale_date) = 11 and year(sale_date)=2022 ;

--Write a SQL query to calculate the total sales (total_sale) for each category.:

SELECT 
    category,
    SUM(total_sale) as net_sale,
    COUNT(*) as total_orders
FROM retail_sales
GROUP BY category;

--Write a SQL query to find the average age of customers who purchased items from the 'Beauty' category.:

SELECT
    ROUND(AVG(age), 2) as avg_age
FROM retail_sales
WHERE category = 'Beauty';

--Write a SQL query to find all transactions where the total_sale is greater than 1000.:

SELECT * FROM retail_sales
WHERE total_sale > 1000;

--Write a SQL query to find the total number of transactions (transaction_id) made by each gender in each category.:

SELECT 
    category,
    gender,
    COUNT(*) as total_trans
FROM retail_sales
GROUP 
    BY 
    category,
    gender
ORDER BY gender;

--Write a SQL query to calculate the average sale for each month. Find out best selling month in each year:

select 
	   top 2
	   year(retail_sales.sale_date) as year,
       month(retail_sales.sale_date) as month,
       round(AVG(total_sale),2) as avg_sale,
	   DENSE_RANK() OVER(PARTITION BY DATEPART(YEAR, sale_date)ORDER BY AVG(total_sale) DESC) as rank
from
       dbo.retail_sales
group by 
	   year(retail_sales.sale_date),
       month(retail_sales.sale_date)
order by 
	   rank;

--Write a SQL query to find the top 5 customers based on the highest total sales

SELECT 
	top 5
    customer_id,
    SUM(total_sale) as total_sales
FROM retail_sales
GROUP BY customer_id
ORDER BY total_sales DESC;

--Write a SQL query to find the number of unique customers who purchased items from each category.

SELECT 
    category,    
    COUNT(DISTINCT customer_id) as cnt_unique_cs
FROM retail_sales
GROUP BY category;

--Write a SQL query to create each shift and number of orders (Example Morning <12, Afternoon Between 12 & 17, Evening >17)

WITH hourly_sale as
(
SELECT *,
    CASE
        WHEN DATEPART(HOUR, sale_time) < 12 THEN 'Morning'
        WHEN DATEPART(HOUR, sale_time) BETWEEN 12 AND 17 THEN 'Afternoon'
        ELSE 'Evening'
    END as shift
FROM retail_sales
)
SELECT 
    shift,
    COUNT(*) as total_orders    
FROM hourly_sale
GROUP BY shift;










