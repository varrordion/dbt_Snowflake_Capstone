{{ config(
    materialized='view',
    tags=['silver']
) }}

with product_source as (

    select
        product.value as product_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at
    from {{ ref('bronze_product') }},

    lateral flatten(
        input => raw_record:products_data
    ) product

)

, cleaned as (

    select

        trim(product_record:product_id::string) as product_id,
        trim(product_record:supplier_id::string) as supplier_id,

        initcap(trim(product_record:name::string)) as product_name,
        initcap(trim(product_record:brand::string)) as brand,
        
        initcap(trim(product_record:product_line::string)) as product_line,

        initcap(trim(product_record:category::string)) as category,
        initcap(trim(product_record:subcategory::string)) as subcategory,

        concat(
            initcap(trim(product_record:category::string)),
            ' > ',
            initcap(trim(product_record:subcategory::string)),
            ' > ',
            upper(trim(product_record:product_line::string))
        ) as product_hierarchy,

        initcap(trim(product_record:color::string)) as color,
        initcap(trim(product_record:size::string)) as size,

        initcap(trim(product_record:short_description::string)) as short_description,
        trim(product_record:technical_specs::string) as technical_specs,

        concat(
            initcap(trim(product_record:name::string)),
            ' - ',
            initcap(trim(product_record:short_description::string)),
            ' - ',
            trim(product_record:technical_specs::string)
        ) as product_full_description,

        -------------------------------------------------
        -- Pricing
        -------------------------------------------------

        try_to_decimal(product_record:cost_price::string,18,2) as cost_price,
        try_to_decimal(product_record:unit_price::string,18,2) as unit_price,

        case
            when try_to_decimal(product_record:unit_price::string,18,2) > 0
            then (
                (
                    try_to_decimal(product_record:unit_price::string,18,2)
                    - try_to_decimal(product_record:cost_price::string,18,2)
                )
                / try_to_decimal(product_record:unit_price::string,18,2)
            ) * 100
            else null
        end as profit_margin_percentage,

        -------------------------------------------------
        -- Inventory
        -------------------------------------------------

        try_to_number(product_record:stock_quantity::string) as stock_quantity,
        try_to_number(product_record:reorder_level::string) as reorder_level,

        case
            when try_to_number(product_record:stock_quantity::string)
                < try_to_number(product_record:reorder_level::string)
            then true
            else false
        end as is_low_stock,

        -------------------------------------------------
        -- Product Attributes
        -------------------------------------------------

        trim(product_record:dimensions::string) as dimensions,
        trim(product_record:weight::string) as weight,
        trim(product_record:warranty_period::string) as warranty_period,

        -------------------------------------------------
        -- Boolean
        -------------------------------------------------

        product_record:is_featured::boolean as is_featured,

        -------------------------------------------------
        -- Dates
        -------------------------------------------------

        try_to_date(product_record:launch_date::string) as launch_date,
        try_to_date(product_record:last_modified_date::string) as last_modified_date,

        -------------------------------------------------
        -- Metadata
        -------------------------------------------------

        _source_file,
        _loaded_at

    from product_source

)

, deduplicated as (

    select *

    from cleaned

    qualify row_number() over (

        partition by product_id

        order by
            last_modified_date desc,
            _loaded_at desc

    ) = 1

)

select *
from deduplicated