{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

select

    -------------------------------------------------
    -- Surrogate Key (grain: order_id + product_id)
    -------------------------------------------------

    {{ dbt_utils.generate_surrogate_key(['so.order_id', 'so.product_id']) }}
        as sales_key,

    -------------------------------------------------
    -- Degenerate Dimension
    -------------------------------------------------

    so.order_id,

    -------------------------------------------------
    -- Foreign Keys
    -------------------------------------------------

    dc.customer_sk,
    dp.product_key,
    dst.store_key,
    dd.date_key,
    de.employee_key,

    -------------------------------------------------
    -- Measures
    -------------------------------------------------

    so.quantity as quantity_sold,
    so.unit_price,

    so.quantity * so.unit_price as total_sales_amount,

    so.quantity * dp.cost_price as cost_amount,

    so.item_discount_amount as discount_amount,

    so.shipping_cost,

    (so.quantity * so.unit_price)
        - (so.quantity * dp.cost_price)
        - so.item_discount_amount
        - so.shipping_cost
        as profit_amount,

    -------------------------------------------------
    -- Descriptive Attributes
    -------------------------------------------------

    dst.region,

    dp.category as product_category,

    so.order_source as sales_channel,

    dc.customer_segment_impact

from {{ ref('silver_orders') }} so

left join {{ ref('dim_product') }} dp
    on so.product_id = dp.product_id
    and dp.is_current

left join {{ ref('dim_customer') }} dc
    on so.customer_id = dc.customer_id
    and dc.is_current

left join {{ ref('dim_store') }} dst
    on so.store_id = dst.store_id
    and dst.is_current

left join {{ ref('dim_employee') }} de
    on so.employee_id = de.employee_id
    and de.is_current

left join {{ ref('dim_date') }} dd
    on to_date(so.order_date) = dd.full_date