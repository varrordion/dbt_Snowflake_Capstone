{{ config(
    materialized='view',
    tags=['reporting_views']
) }}

select

    dc.loyalty_tier,
    dc.customer_segment_impact,

    count(distinct dc.customer_id) as total_customers,
    count(distinct fs.order_id) as total_orders,

    sum(fs.total_sales_amount) as total_revenue,
    sum(fs.profit_amount) as total_profit,

    sum(fs.total_sales_amount) / nullif(count(distinct dc.customer_id), 0)
        as avg_lifetime_revenue_per_customer,

    sum(fs.profit_amount) / nullif(count(distinct dc.customer_id), 0)
        as avg_lifetime_profit_per_customer,

    sum(fs.total_sales_amount) / nullif(count(distinct fs.order_id), 0)
        as avg_order_value,

    min(dd.full_date) as first_purchase_date,
    max(dd.full_date) as last_purchase_date

from {{ ref('fact_sales') }} fs

join {{ ref('dim_customer') }} dc
    on fs.customer_sk = dc.customer_sk

join {{ ref('dim_date') }} dd
    on fs.date_key = dd.date_key

where dc.is_current

group by
    dc.loyalty_tier,
    dc.customer_segment_impact

order by avg_lifetime_profit_per_customer desc