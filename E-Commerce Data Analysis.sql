use mini_project_2;

# Q1 - Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)

create table combined_table as
(select cd.Cust_id, cd.Customer_Name, cd.Province, cd.Region, cd.Customer_Segment, mf.Ord_id, 
mf.Prod_id, mf.Sales, mf.Discount, mf.Order_Quantity, mf.Profit, mf.Shipping_Cost, mf.Product_Base_Margin,
od.Order_ID, od.Order_Date, od.Order_Priority,
pd.Product_Category, pd.Product_Sub_Category,
sd.Ship_id, sd.Ship_Mode, sd.Ship_Date
from market_fact mf inner join cust_dimen cd on mf.Cust_id = cd.Cust_id
inner join orders_dimen od on od.Ord_id = mf.Ord_id
inner join prod_dimen pd on pd.Prod_id = mf.Prod_id
inner join shipping_dimen sd on sd.Ship_id = mf.Ship_id
);

select * from combined_table;

# Q2 - Find the top 3 customers who have the maximum number of orders.

select c.cust_id, c.customer_name, count(distinct Ord_id) as number_of_orders from 
cust_dimen c inner join market_fact mf on c.cust_id = mf.cust_id
group by c.cust_id, c.customer_name order by number_of_orders desc limit 3; 

# Q3 - Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

alter table combined_table add column DaysTakenForDelivery int;

update combined_table set DaysTakenForDelivery =
datediff(str_to_date(Ship_Date,'%d-%m-%Y'),str_to_date(Order_Date,'%d-%m-%Y'));

select Order_ID, Order_Date, Ship_Date, DaysTakenForDelivery from combined_table;

# Q4 - Find the customer whose order took the maximum time to get delivered.

select Cust_id, Customer_Name, Order_Date, Ship_Date, DaysTakenForDelivery from combined_table 
where DaysTakenForDelivery in (select max(DaysTakenForDelivery) from combined_table);

# Q5 - Retrieve total sales made by each product from the data (use Windows function)

select Prod_id, sum(Sales) over (partition by Prod_id) as total_sales from market_fact;

# Q6 - Retrieve total profit made from each product from the data (use windows function)

select Prod_id, sum(Profit) over (partition by Prod_id) as total_profit from market_fact;

# Q7 - Count the total number of unique customers in January and 
# how many of them came back every month over the entire year in 2011

select count(distinct Cust_id) as unique_customers from combined_table where Order_Date like '__-01-2011';

SELECT distinct Year(str_to_date(Order_date,'%d-%m-%Y')), Month(str_to_date(Order_date,'%d-%m-%Y')), count(cust_id)
OVER (PARTITION BY month(str_to_date(Order_date,'%d-%m-%Y')) order by month(str_to_date(Order_date,'%d-%m-%Y'))) AS
Total_Unique_Customers FROM combined_table WHERE year(str_to_date(Order_date,'%d-%m-%Y'))=2011 AND cust_id IN 
(SELECT DISTINCT cust_id FROM combined_table WHERE Order_Date like '__-01-2011');


# Q8 - Retrieve month-by-month customer retention rate since the start of the business.(using views)
 
#TIPS:

#1: Create a view where each user’s visits are logged by month, allowing for
#the possibility that these will have occurred over multiple # years since
#whenever business started operations

create view user_visit as select  cust_id, month((str_to_date(Order_date,'%d-%m-%Y'))) as Month, 
count(*) as Count_in_month from combined_table group by 1,2;

# 2: Identify the time lapse between each visit. So, for each person and for each
#month, we see when the next visit is.

create view Time_lapse_vw as 
select  *, lead(month) over (partition by cust_id order by month) as Next_month_Visit
from user_visit; 

select * from time_lapse_vw;
    
# 3: Calculate the time gaps between visits

create view  time_gap_vw as select *, Next_month_Visit - month as Time_gap from time_lapse_vw;

select * from time_gap_vw;


# 4: categorise the customer with time gap 1 as retained, >1 as irregular and
#NULL as churned

create view Customer_value_vw as 
select distinct cust_id, avg(time_gap)over(partition by cust_id) as Average_time_gap,
case 
	when (avg(time_gap)over(partition by cust_id))<=1 then 'Retained'
    when (avg(time_gap)over(partition by cust_id))>1 then 'Irregular'
    when (avg(time_gap)over(partition by cust_id)) is null then 'Churned'
    else 'Unknown data'
end  as  'Customer_Value'
from time_gap_vw;

select * from customer_value_vw;

# 5: calculate the retention month wise

create view retention_vw as 
select distinct next_month_visit as Retention_month,
sum(time_gap) over (partition by next_month_visit) as Retention_Sum_monthly
from time_gap_vw where time_gap=1;

select * from retention_vw;