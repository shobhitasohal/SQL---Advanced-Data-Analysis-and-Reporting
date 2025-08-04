
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