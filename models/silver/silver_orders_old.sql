{{ config(
    materialized='view',
    tags=['silver']
) }}

with order_source as (

    select
        orders.value as order_record,
        item.value as item_record,

        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at

    from {{ ref('bronze_orders') }},

    lateral flatten(
        input => raw_record:orders_data
    ) orders,

    lateral flatten(
        input => orders.value:order_items
    ) item

)

, cleaned as (

    select

        -------------------------------------------------
        -- IDs
        -------------------------------------------------

        order_record:order_id::string as order_id,
        order_record:customer_id::string as customer_id,
        order_record:employee_id::string as employee_id,
        order_record:store_id::string as store_id,
        order_record:campaign_id::string as campaign_id,

        item_record:product_id::string as product_id,

        -------------------------------------------------
        -- Item Metrics
        -------------------------------------------------

        try_to_number(item_record:quantity::string) as quantity,

        try_to_decimal(
            item_record:unit_price::string,
            18,2
        ) as unit_price,

        try_to_decimal(
            item_record:cost_price::string,
            18,2
        ) as cost_price,

        try_to_decimal(
            item_record:discount_amount::string,
            18,2
        ) as item_discount_amount,

        -------------------------------------------------
        -- Dates
        -------------------------------------------------

        try_to_timestamp(order_record:created_at::string) as created_at,

        try_to_timestamp(order_record:order_date::string) as order_date,

        try_to_timestamp(order_record:shipping_date::string) as shipping_date,

        try_to_timestamp(order_record:delivery_date::string) as delivery_date,

        try_to_timestamp(order_record:estimated_delivery_date::string)
            as estimated_delivery_date,

        -------------------------------------------------
        -- Time Intelligence
        -------------------------------------------------

        extract(
            hour from try_to_timestamp(order_record:order_date::string)
        ) as order_hour,

        case
            when extract(hour from try_to_timestamp(order_record:order_date::string))
                >= 5
                and extract(hour from try_to_timestamp(order_record:order_date::string)) < 12
                then 'Morning'

            when extract(hour from try_to_timestamp(order_record:order_date::string))
                >= 12
                and extract(hour from try_to_timestamp(order_record:order_date::string)) < 17
                then 'Afternoon'

            when extract(hour from try_to_timestamp(order_record:order_date::string))
                >= 17
                and extract(hour from try_to_timestamp(order_record:order_date::string)) < 22
                then 'Evening'

            else 'Night'
        end as order_time_of_day,

        week(
            try_to_timestamp(order_record:order_date::string)
        ) as order_week,

        month(
            try_to_timestamp(order_record:order_date::string)
        ) as order_month,

        quarter(
            try_to_timestamp(order_record:order_date::string)
        ) as order_quarter,

        year(
            try_to_timestamp(order_record:order_date::string)
        ) as order_year,

        -------------------------------------------------
        -- Shipping Metrics
        -------------------------------------------------

        datediff(
            day,
            try_to_timestamp(order_record:order_date::string),
            try_to_timestamp(order_record:shipping_date::string)
        ) as processing_days,

        datediff(
            day,
            try_to_timestamp(order_record:shipping_date::string),
            try_to_timestamp(order_record:delivery_date::string)
        ) as shipping_days,

        case
            when try_to_timestamp(order_record:delivery_date::string) is not null
                 and try_to_timestamp(order_record:delivery_date::string)
                 <= try_to_timestamp(order_record:estimated_delivery_date::string)
                then 'On Time'

            when try_to_timestamp(order_record:delivery_date::string) is not null
                 and try_to_timestamp(order_record:delivery_date::string)
                 > try_to_timestamp(order_record:estimated_delivery_date::string)
                then 'Delayed'

            when try_to_timestamp(order_record:delivery_date::string) is null
                 and current_date()
                 > try_to_date(order_record:estimated_delivery_date::string)
                then 'Potentially Delayed'

            else 'In Transit'
        end as delivery_status,

        -------------------------------------------------
        -- Order Details
        -------------------------------------------------

        upper(order_record:order_status::string) as order_status,
        initcap(order_record:order_source::string) as order_source,
        initcap(order_record:payment_method::string) as payment_method,
        initcap(order_record:shipping_method::string) as shipping_method,

        -------------------------------------------------
        -- Order Amounts
        -------------------------------------------------

        try_to_decimal(order_record:total_amount::string,18,2) as total_amount,
        try_to_decimal(order_record:discount_amount::string,18,2) as discount_amount,
        try_to_decimal(order_record:tax_amount::string,18,2) as tax_amount,
        try_to_decimal(order_record:shipping_cost::string,18,2) as shipping_cost,

        -------------------------------------------------
        -- Billing Address
        -------------------------------------------------

        initcap(order_record:billing_address.city::string)
            as billing_city,

        upper(order_record:billing_address.state::string)
            as billing_state,

        initcap(order_record:billing_address.street::string)
            as billing_street,

        order_record:billing_address.zip_code::string
            as billing_zip_code,

        -------------------------------------------------
        -- Shipping Address
        -------------------------------------------------

        initcap(order_record:shipping_address.city::string)
            as shipping_city,

        upper(order_record:shipping_address.state::string)
            as shipping_state,

        initcap(order_record:shipping_address.street::string)
            as shipping_street,

        order_record:shipping_address.zip_code::string
            as shipping_zip_code,

        -------------------------------------------------
        -- Metadata
        -------------------------------------------------

        _source_file,
        _loaded_at

    from order_source

)

, calculated as (

    select

        *,

        (
            quantity * unit_price * (1 - item_discount_amount)
        ) as line_revenue,

        (
            quantity * cost_price
        ) as line_cost,

        (
            (
                quantity * unit_price * (1 - item_discount_amount)
            )
            * (1 - discount_amount)
        )
        -
        (
            quantity * cost_price
        )
        -
        shipping_cost
        -
        tax_amount
        as profit_amount

    from cleaned

)

, aggregated as (

    select

        order_id,

        count(product_id) as total_items,

        sum(quantity) as total_quantity,

        sum(quantity * unit_price) as items_total_amount,

        sum(quantity * cost_price) as items_total_cost,

        sum(item_discount_amount) as items_total_discount,

        sum(line_revenue) as line_revenue,

        sum(line_cost) as line_cost,

        sum(profit_amount) as profit_amount,

        case
            when sum(line_revenue) > 0
            then (sum(profit_amount) / sum(line_revenue)) * 100
            else null
        end as profit_margin_percentage,

        max(customer_id) as customer_id,
        max(employee_id) as employee_id,
        max(store_id) as store_id,
        max(campaign_id) as campaign_id,

        max(created_at) as created_at,
        max(order_date) as order_date,
        max(shipping_date) as shipping_date,
        max(delivery_date) as delivery_date,
        max(estimated_delivery_date) as estimated_delivery_date,

        max(order_status) as order_status,
        max(order_source) as order_source,
        max(payment_method) as payment_method,
        max(shipping_method) as shipping_method,

        max(total_amount) as total_amount,
        max(discount_amount) as discount_amount,
        max(tax_amount) as tax_amount,
        max(shipping_cost) as shipping_cost,

        max(order_time_of_day) as order_time_of_day,
        max(order_week) as order_week,
        max(order_month) as order_month,
        max(order_quarter) as order_quarter,
        max(order_year) as order_year,

        max(processing_days) as processing_days,
        max(shipping_days) as shipping_days,
        max(delivery_status) as delivery_status,

        max(billing_city) as billing_city,
        max(billing_state) as billing_state,
        max(billing_street) as billing_street,
        max(billing_zip_code) as billing_zip_code,

        max(shipping_city) as shipping_city,
        max(shipping_state) as shipping_state,
        max(shipping_street) as shipping_street,
        max(shipping_zip_code) as shipping_zip_code,
        max(_source_file) as _source_file,
        max(_loaded_at) as _loaded_at
        
    from calculated
    group by order_id
)

select *
from aggregated