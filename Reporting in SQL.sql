/*
=============================================================================================
Customer Report
=============================================================================================
Purpose:
    This report consolidates key customer metrices and behaviours
	
Highlights:
    1. Gather essential fields such as names, ages and transaction details.
	2. Segment customer into categories such as VIP, Regular and New and age groups.
	3. Aggregate customer-level metrices:
	   - total orders
	   - total sales
	   - total quantity purchased
	   - lifespan (in months)
	4. Calculate KPIs:
	   - recency (months since last order)
	   - average order value
	   - average monthly spend
=============================================================================================
*/

/*--------------------------------------------------------------------------------------------
Base Query - Select relevant columns from tables
--------------------------------------------------------------------------------------------*/
IF OBJECT_ID('tempdb..#base_query') IS NOT NULL DROP TABLE #base_query;

SELECT
    year(s.order_date) as _Year,
	s.order_number,
    s.product_key,
    s.order_date,
    s.sales_amount,
    s.quantity,
    c.customer_key,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    DATEDIFF(year, c.birthdate, GETDATE()) AS age,
    s.order_date AS order_date_raw -- Raw order date for use in aggregation
INTO #base_query
FROM dbo.sales s
INNER JOIN gold.dim_customers c ON s.customer_key = c.customer_key;

/*--------------------------------------------------------------------------------------------
 Query to Aggregate Data - Use base query columns to aggregate data as per request
--------------------------------------------------------------------------------------------*/
IF OBJECT_ID('tempdb..#customer_aggregations') IS NOT NULL DROP TABLE #customer_aggregations;

SELECT 
    _Year,
	customer_key,
    customer_id,
    customer_name,
    age,
    COUNT(order_number) AS total_orders, 
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity_purchased,
    MAX(order_date_raw) AS last_order_date,
    MIN(order_date_raw) AS first_order_date,
    DATEDIFF(month, MIN(order_date_raw), MAX(order_date_raw)) AS lifespan
INTO #customer_aggregations
FROM #base_query
GROUP BY _Year, customer_key, customer_id, customer_name, age;

SELECT 
    _Year,
	customer_key,
    customer_id,
    customer_name,
    age,
	-- Segment data into different age groups
	CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and Above'
    END AS age_group,
	-- Segment Customers based on customer spending and lifespan of their membership
	CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        WHEN lifespan < 12 THEN 'New'
    END AS customer_segment,
    total_orders,
    total_sales,
    total_quantity_purchased,
    last_order_date,
    DATEDIFF(month, COALESCE(last_order_date, GETDATE()), GETDATE()) AS month_since_last_order,
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_value,
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM #customer_aggregations;

DROP TABLE #base_query;
DROP TABLE #customer_aggregations;

/*
=============================================================================================
Product Report
=============================================================================================
Purpose:
    This report consolidates key customer metrices and behaviours
	
Highlights:
    1. Gather essential fields such as product name, category, subcategory and cost.
	2. Segment products by revenue to identify high-performers, mid-range, or low-performers.
	3. Aggregate product-level metrices:
	   - total orders
	   - total sales
	   - total quantity sold
	   - total customers (unique)
	   - lifespan (in months)
	4. Calculate valuable KPIs:
	   - recency (months since last order)
	   - average order revenue (AOR)
	   - average monthly revenue
=============================================================================================
*/

create view product_report as

/*=========================================================================================
 Step 1 - Base Query- Extracting core columns from sales and dim_products table
===========================================================================================*/

With base_query as
 (
	Select
	 year(s.order_date) as _Year
	 , p.product_key
	 , p.product_name
	 , p.category
	 , p.subcategory
	 , p.cost
	 , p.start_date
	 ,s.order_number
	 ,s.sales_amount
	 , s.quantity
	 , s.customer_key
	 , s.order_date
	from gold.dim_products p
	join sales s on s.product_key=p.product_key
 ),

/*=========================================================================================
 Step 2 - Product Aggregations- Summarizing key metrices requested in Product Report
===========================================================================================*/
product_aggregations as
 (
	select
	 _Year
	 , product_key
	 , product_name
	 , category
	 , subcategory
	 , cost
	 ,start_date
	 , max(order_date) as last_sale_date
	 , datediff(month, min(order_date), max(order_date)) as lifespan
	 , count(distinct order_number) as total_orders
	 , count(distinct customer_key) as total_customers
	 , sum(sales_amount) as total_sales_revenue
	 , datediff(year, max(order_date), getdate()) as recency_in_years
	 , sum(quantity) as total_quantity_sold
	 , round(avg(cast(sales_amount as float)/ nullif(quantity,0)),1) as average_selling_price
	from base_query
	group by _year, product_key , product_name , category , subcategory , cost, start_date
)

/*=========================================================================================
 Step 3 - Final Query - Combines all product results into one output 
===========================================================================================*/
Select
 _Year
 , product_key
 , product_name
 , category
 , subcategory
 , cost
 , start_date
 , last_sale_date
 , recency_in_years
 , case 
    when total_sales_revenue > AVG(total_sales_revenue) over (partition by category) then 'High-Performer'
    when total_sales_revenue < AVG(total_sales_revenue) over (partition by category) then 'Low-Performer'
    else 'Mid-Performer'
   end as performance_matrix
 ,lifespan
 , total_orders
 , total_sales_revenue
 , total_quantity_sold
 , total_customers
 , average_selling_price
 , case when total_orders=0 then 0 
	    else Total_sales_revenue/ total_orders 
   end as AOR										--AVERAGE ORDER REVENUE
 , case when lifespan=0 then total_sales_revenue 
	 	else total_sales_revenue/lifespan 
   end as  average_monthly_revenue					--AVERAGE MONTHLY REVENUE
from product_aggregations
where _year in ('2011','2012','2013');