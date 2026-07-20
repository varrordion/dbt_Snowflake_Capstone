{{ config(
    materialized='view',
    tags=['reporting_views']
) }}

select

    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand,

    sum(fs.quantity_sold) as total_quantity_sold,
    sum(fs.total_sales_amount) as total_sales_amount,
    sum(fs.profit_amount) as total_profit_amount,

    count(distinct fs.order_id) as total_orders,

    case
        when sum(fs.total_sales_amount) > 0
        then (sum(fs.profit_amount) / sum(fs.total_sales_amount)) * 100
        else null
    end as profit_margin_percentage

from {{ ref('fact_sales') }} fs

join {{ ref('dim_product') }} dp
    on fs.product_key = dp.product_key
    and dp.is_current

group by
    dp.product_id,
    dp.product_name,
    dp.category,
    dp.subcategory,
    dp.brand

order by total_sales_amount desc