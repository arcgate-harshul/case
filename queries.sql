-- use case1
-- 1. What is the total amount each customer spent at the restaurant?

-- first approach 
select customer_id  , SUM(price) from sales 
JOIN menu 
ON  menu.product_id = sales.product_id 
group by(customer_id);


-- second approach 
select distinct customer_id  , SUM(price) OVER(PARTITION BY customer_id) from sales 
JOIN menu 
ON  menu.product_id = sales.product_id ;



-- 2. How many days has each customer visited the restaurant?  

-- first approach 
SELECT  customer_id ,COUNT(DISTINCT(DATE(order_date))) as days from sales group by customer_id ;



-- second Approach
create view unique_dates as
SELECT  customer_id ,COUNT(DISTINCT(DATE(order_date))) as days from sales group by customer_id ;

select * from unique_dates;



-- also you can apply more filtering in this method

select * from unique_dates where days > 5; 


-- 3. What was the first item from the menu purchased by each customer?


-- Approach 1 
select * from (
select customer_id , sales.product_id , product_name ,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date ) AS count 
from sales  JOIN menu ON menu.product_id = sales.product_id) as ranked 
having count=1;




-- approach 2
WITH first as(
select * from (
select customer_id , sales.product_id , product_name ,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date ) AS count 
from sales  JOIN menu ON menu.product_id = sales.product_id) as ranked 
)
select * from first having count =1;



-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?


-- approach 1 
-- this will create a view for product id of highest ordered product 
create view highest_product as
select menu.product_id as highest_ordered_product ,COUNT(sales.product_id) as count from sales 
JOIN menu ON sales.product_id = menu.product_id group by sales.product_id
order by count desc limit 1; 


-- this wil print the product id of the highest ordered product 


select product_name  from highest_product JOIN menu ON menu.product_id = highest_product.highest_ordered_product ;


-- this will at last print the customer id and the count of that product ordered by each customer by
-- matching the product id ofhighest ordered product 


select customer_id , COUNT(product_id) as counts_per_customer from sales where product_id = (select highest_ordered_product from highest_product)
group by customer_id;
 

 -- approach 2



select customer_id ,
(select menu.product_id 
  from sales JOIN menu ON sales.product_id = menu.product_id group by sales.product_id 
order by COUNT(sales.product_id)  desc limit 1 ) as product_id,
COUNT(sales.product_id) as counts_per_customer,
RANK() 
OVER(PARTITION by customer_id ORDER BY COUNT(sales.product_id)) as ranks from sales where product_id =(select menu.product_id 
  from sales JOIN menu ON sales.product_id = menu.product_id group by sales.product_id 
order by COUNT(sales.product_id)  desc limit 1 )
group by customer_id;





-- 5. Which item was the most popular for each customer?
--

--
-- approach 1

select * from(
select customer_id , product_name ,COUNT(sales.product_id),
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY COUNT(sales.product_id) DESC) as ranks
from sales JOIN menu ON menu.product_id = sales.product_id group by  customer_id , menu.product_name 
)RANKED
where ranks=1;




-- APPROACH 2 

select * from(
select customer_id , product_name ,COUNT(sales.product_id),
RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(sales.product_id) DESC) as ranks
from sales JOIN menu ON menu.product_id = sales.product_id group by  customer_id , menu.product_name 
)RANKED
where ranks=1;

-- APPROACH 3

WITH output AS 
(
SELECT  sales.customer_id,menu.product_name,
        COUNT(sales.product_id) as count,
        DENSE_RANK() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id) DESC) AS k
FROM menu 
JOIN sales  
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id, sales.product_id, menu.product_name
) 
SELECT customer_id, product_name, count
FROM output
WHERE k = 1;





-- 6. Which item was purchased first by the customer after they became a member?


-- approach 1

select* from (
 select sales.customer_id,product_name ,join_date, order_date as first_order_afterjoining ,
 RANK() OVER(PARTITION BY sales.customer_id ORDER BY order_date) as f
 from sales JOIN menu ON menu.product_id= sales.product_id JOIN members ON members.customer_id = sales.customer_id
 where order_date > join_date 
 group by sales.customer_id , join_date, order_date, product_name
)RANKED
where f=1;



-- approach 2 
WITH ranks AS
(
SELECT s.customer_id,
       m.product_name,
    DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS ranks
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members AS mem
ON mem.customer_id = s.customer_id
WHERE s.order_date >= mem.join_date
)
SELECT * FROM ranks
WHERE ranks = 1;





-- 7. Which item was purchased just before the customer became a member?


select* from (
 select sales.customer_id,product_name ,join_date, order_date as first_order_afterjoining ,
 RANK() OVER(PARTITION BY sales.customer_id ORDER BY order_date) as f
 from sales JOIN menu ON menu.product_id= sales.product_id JOIN members ON members.customer_id = sales.customer_id
 where order_date < join_date 
 group by sales.customer_id , join_date, order_date, product_name
)RANKED
where f=1;


-- 8. What is the total items and amount spent for each member before they became a member?


select sales.customer_id ,
COUNT(sales.product_id) as items_ordered,
SUM(price) as total_spend,
RANK() OVER(PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id)) as r
from 
sales JOIN menu ON  menu.product_id = sales.product_id JOIN
members ON members.customer_id = sales.customer_id
where order_date < join_date 
GROUP BY sales.customer_id ;


-- ----------------------OR approach 2 ------------------------------


-- this will create a view which will contain the items ordered for product_id and customer_id 
CREATE view step1 as 
select sales.customer_id ,
     product_name,
    COUNT(sales.product_id) as items_ordered,
    RANK() OVER(PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id)) as r
     from 
    sales JOIN menu ON  menu.product_id = sales.product_id JOIN
    members ON members.customer_id = sales.customer_id
    where order_date < join_date 
    GROUP BY sales.customer_id ,
    product_name;


-- this will multiply the qty into price as it will also be grouped by product name the output will be in 4 rows
-- of 4 different orders

select customer_id , step1.product_name,items_ordered , SUM(price*items_ordered) 
from step1 JOIN menu ON menu.product_name = step1.product_name 
group by customer_id,step1.product_name;



-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier — how many points would each customer have?

-- THIS WILL CREATE A JOINT VIEW OF BOTH POINTS ONE WHICH CONTAINS SUSHI ANS ONE WICH DOESN'T 



create view final as 
select sales.customer_id ,
SUM(price) * 20 as points,
RANK() OVER(PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id)) as r
from sales JOIN menu ON  menu.product_id = sales.product_id
where sales.product_id = 1 OR order_date BETWEEN join_date AND DATE_ADD('join_date',interval 7 DAY)
GROUP BY sales.customer_id 
UNION 
select sales.customer_id ,
SUM(price) * 10 as points,
RANK() OVER(PARTITION BY sales.customer_id ORDER BY COUNT(sales.product_id)) as r
from sales JOIN menu ON  menu.product_id = sales.product_id
where sales.product_id != 1
GROUP BY sales.customer_id ;


-- AND HERE WE WILL GROUP BY CUSTOMER ID TO GET A COMBINED VIEW 

select customer_id , SUM(points) from final group by customer_id;



-- APPROACH 2 using switch and view 

create view f as 
(
SELECT *,
    CASE 
    WHEN m.product_name = 'sushi' THEN price * 20
    WHEN m.product_name != 'sushi' THEN price * 10
    END AS points
FROM menu m
    );

SELECT customer_id, SUM(points) AS points
FROM sales s
JOIN f ON f.product_id = s.product_id
GROUP BY s.customer_id ;   


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points 
-- on all items, not just sushi — how many points do customer A and B have at the end of January?



WITH points AS
(
select sales.customer_id ,
order_date , 
sales.product_id ,
product_name,
price,
join_date,
CASE 
WHEN  product_name = "sushi" THEN price *20 
WHEN  product_name != "sushi" AND order_date BETWEEN 
join_date AND DATE_ADD(join_date ,INTERVAL 7 DAY) 
THEN price * 20 
ELSE price  * 10 
END AS points 
from sales JOIN menu ON sales.product_id = menu.product_id JOIN members ON members.customer_id = sales.customer_id
where order_date <='2021-01-31' 
)
SELECT  customer_id, SUM(points) AS points
FROM points
GROUP BY customer_id  ;  



-- bonus questions 





select sales.customer_id,
order_date,
product_name,
price,
CASE 
WHEN order_date >= join_date THEN 'Y'
WHEN order_date < join_date THEN 'N'
ELSE 'N'
END AS members
from 
sales JOIN menu ON menu.product_id = sales.product_id 
LEFT JOIN members ON members.customer_id = sales.customer_id;



---- BONUS QUESTION --------


-- Rank All The Things
-- Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.




create view a as 
select sales.customer_id,
order_date,
product_name,
price,
CASE 
WHEN order_date >= join_date THEN 'Y'
WHEN order_date < join_date THEN 'N'
ELSE 'N'
END AS members
from 
sales JOIN menu ON menu.product_id = sales.product_id 
LEFT JOIN members ON members.customer_id = sales.customer_id;


select *,
CASE 
WHEN members = 'N' THEN 'NULL'
ELSE RANK() OVER(PARTITION BY customer_id ORDER BY price)
END AS RANKING
from a ;
