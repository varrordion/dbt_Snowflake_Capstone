{{ config(
    materialized='view',
    tags=['silver']
) }}

with supplier_source as (
    select
        supplier.value as supplier_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at

    from {{ ref('bronze_supplier') }},

    lateral flatten(
        input => raw_record:suppliers_data
    ) supplier

)

, cleaned as (

    select

        -------------------------------------------------
        -- IDs
        -------------------------------------------------

        supplier_record:supplier_id::string as supplier_id,

        -------------------------------------------------
        -- Supplier Details
        -------------------------------------------------

        initcap(supplier_record:supplier_name::string)
            as supplier_name,

        initcap(supplier_record:supplier_type::string)
            as supplier_type,

        upper(supplier_record:credit_rating::string)
            as credit_rating,

        supplier_record:tax_id::string
            as tax_id,

        lower(supplier_record:website::string)
            as website,

        try_to_number(
            supplier_record:year_established::string
        ) as year_established,

        -------------------------------------------------
        -- Contact Information
        -------------------------------------------------

        initcap(
            supplier_record:contact_information.contact_person::string
        ) as contact_person,

        lower(
            supplier_record:contact_information.email::string
        ) as email,

        regexp_replace(
            supplier_record:contact_information.phone::string,
            '[^0-9]',
            ''
        ) as phone,

        supplier_record:contact_information.address::string
            as address,

        -------------------------------------------------
        -- Contract Details
        -------------------------------------------------

        supplier_record:contract_details.contract_id::string
            as contract_id,

        try_to_date(
            supplier_record:contract_details.start_date::string
        ) as contract_start_date,

        try_to_date(
            supplier_record:contract_details.end_date::string
        ) as contract_end_date,

        supplier_record:contract_details.exclusivity::boolean
            as exclusivity,

        supplier_record:contract_details.renewal_option::boolean
            as renewal_option,

        -------------------------------------------------
        -- Operational Details
        -------------------------------------------------

        supplier_record:is_active::boolean
            as is_active,

        initcap(supplier_record:preferred_carrier::string)
            as preferred_carrier,

        supplier_record:payment_terms::string
            as payment_terms,

        try_to_number(
            supplier_record:lead_time_days::string
        ) as lead_time_days,

        try_to_number(
            supplier_record:minimum_order_quantity::string
        ) as minimum_order_quantity,

        -------------------------------------------------
        -- Performance Metrics
        -------------------------------------------------

        try_to_decimal(
            supplier_record:performance_metrics.average_delay_days::string,
            10,2
        ) as average_delay_days,

        try_to_decimal(
            supplier_record:performance_metrics.defect_rate::string,
            10,2
        ) as defect_rate,

        try_to_decimal(
            supplier_record:performance_metrics.on_time_delivery_rate::string,
            10,2
        ) as on_time_delivery_rate,

        lower(
            supplier_record:performance_metrics.quality_rating::string
        ) as quality_rating,

        try_to_decimal(
            supplier_record:performance_metrics.response_time_hours::string,
            10,2
        ) as response_time_hours,

        try_to_decimal(
            supplier_record:performance_metrics.returns_percentage::string,
            10,2
        ) as returns_percentage,

        -------------------------------------------------
        -- Categories
        -------------------------------------------------

        supplier_record:categories_supplied
            as categories_supplied,

        -------------------------------------------------
        -- Dates
        -------------------------------------------------

        try_to_date(
            supplier_record:last_order_date::string
        ) as last_order_date,

        try_to_date(
            supplier_record:last_modified_date::string
        ) as last_modified_date,

        -------------------------------------------------
        -- Metadata
        -------------------------------------------------

        _source_file,
        _loaded_at

    from supplier_source

)

, deduplicated as (

    select *

    from cleaned

    qualify row_number() over (

        partition by supplier_id

        order by
            last_modified_date desc,
            _loaded_at desc

    ) = 1

)

select *
from deduplicated