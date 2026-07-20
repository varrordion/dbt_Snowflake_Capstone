with customer_order_counts as (

    select
        customer_sk,
        count(*) as sales_count
    from {{ ref('fact_sales') }}
    group by customer_sk

),

summary as (
    select
        count(*) as total_customers,
        count(case when sales_count > 1 then 1 end) as repeating_customers
    from customer_order_counts
)
select
    total_customers,
    repeating_customers,
    case
        when total_customers > 0
        then (repeating_customers::float / total_customers) * 100
        else null
    end as repeating_customer_ratio_percentage
from summary