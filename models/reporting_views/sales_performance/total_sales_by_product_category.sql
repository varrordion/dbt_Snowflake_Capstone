SELECT 
    dp.category, 
    dp.subcategory,
    sum(fs.total_sales_amount) as Total_Amount
FROM {{ ref("fact_sales")}} fs 
JOIN {{ ref("dim_product")}} dp 
    ON fs.product_key = fs.product_key
GROUP BY dp.category,dp.subcategory