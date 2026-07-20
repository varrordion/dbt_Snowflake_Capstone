
SELECT
SUM(fs.quantity_sold) as SALES_TREND
FROM {{ref("fact_sales")}} fs 
JOIN {{ref("dim_store")}} ds ON fs.store_key = ds.store_key
GROUP BY ds.region