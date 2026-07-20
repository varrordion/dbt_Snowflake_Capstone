SELECT 
de.role,
sum(fs.total_sales_amount) as Total_Sales
FROM {{ref("fact_sales")}} as fs 
JOIN {{ref("dim_employee")}} de on fs.employee_key = de.employee_key
GROUP BY de.role