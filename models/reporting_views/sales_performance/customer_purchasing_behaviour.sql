select 
sum(fs.total_sales_amount) Sales,
dc.customer_segment_impact
FROM {{ref("fact_sales")}} fs 
JOIN {{ref("dim_customer")}} dc on dc.customer_sk = fs.customer_sk
GROUP BY dc.customer_segment_impact