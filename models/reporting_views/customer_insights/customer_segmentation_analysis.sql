select

    dc.customer_segment_impact,
    dc.loyalty_tier,
    dc.age_bucket,

    count(distinct dc.customer_id) as total_customers,
    count(distinct fs.order_id) as total_orders,

    sum(fs.total_sales_amount) as total_revenue,
    sum(fs.profit_amount) as total_profit,

    sum(fs.total_sales_amount) / nullif(count(distinct dc.customer_id), 0)
        as avg_revenue_per_customer,

    sum(fs.total_sales_amount) / nullif(count(distinct fs.order_id), 0)
        as avg_order_value,

    count(distinct fs.order_id) / nullif(count(distinct dc.customer_id), 0)
        as avg_orders_per_customer

from {{ ref('dim_customer') }} dc

left join {{ ref('fact_sales') }} fs
    on dc.customer_sk = fs.customer_sk

where dc.is_current

group by
    dc.customer_segment_impact,
    dc.loyalty_tier,
    dc.age_bucket

order by total_revenue desc