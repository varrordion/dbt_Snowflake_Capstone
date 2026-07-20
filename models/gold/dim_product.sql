--product_key, built as the hash of product_id + dbt_valid_from,
-- so each SCD2 version of a product gets its own unique surrogate key.

{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

select

    {{ dbt_utils.generate_surrogate_key(['product_id', 'dbt_valid_from']) }}
        as product_key,

    product_id,
    supplier_id,

    product_name,
    brand,
    product_line,
    category,
    subcategory,
    product_hierarchy,

    color,
    size,

    short_description,
    technical_specs,
    product_full_description,

    unit_price,
    cost_price,
    profit_margin_percentage,

    stock_quantity,
    reorder_level,
    is_low_stock,

    dimensions,
    weight,
    warranty_period,

    is_featured,
    launch_date,

    dbt_valid_from as valid_from,
    coalesce(dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    case when dbt_valid_to is null then true else false end as is_current

from {{ ref('snapshot_product') }}