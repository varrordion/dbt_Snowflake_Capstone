{{ config(
    materialized='view',
    tags=['silver']
) }}

with store_source as (

    select
        store.value as store_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at
    from {{ ref('bronze_store') }},

    lateral flatten(
        input => raw_record:stores_data
    ) store

)

, cleaned as (

    select

        -------------------------------------------------
        -- IDs
        -------------------------------------------------

        store_record:store_id::string as store_id,
        store_record:manager_id::string as manager_id,

        -------------------------------------------------
        -- Store Details
        -------------------------------------------------

        initcap(store_record:store_name::string) as store_name,
        initcap(store_record:store_type::string) as store_type,
        upper(store_record:region::string) as region,
        case
            when try_to_number(store_record:size_sq_ft::string) < 5000
                then 'Small'

            when try_to_number(store_record:size_sq_ft::string)
                between 5000 and 10000
                then 'Medium'

            when try_to_number(store_record:size_sq_ft::string) > 10000
                then 'Large'

            else null
        end as store_size_category,

        -------------------------------------------------
        -- Contact Information
        -------------------------------------------------

        lower(store_record:email::string) as email,

        case
            when length(
                regexp_replace(
                    store_record:phone_number::string,
                    '[^0-9]',
                    ''
                )
            ) >= 10
            then regexp_replace(
                store_record:phone_number::string,
                '[^0-9]',
                ''
            )
            else null
        end as phone_number,

        -------------------------------------------------
        -- Store Metrics
        -------------------------------------------------

        try_to_number(
            store_record:employee_count::string
        ) as employee_count,

        try_to_number(
            store_record:size_sq_ft::string
        ) as size_sq_ft,

        try_to_decimal(
            store_record:current_sales::string,
            18,2
        ) as current_sales,

        try_to_decimal(
            store_record:sales_target::string,
            18,2
        ) as sales_target,

        case
            when try_to_decimal(store_record:sales_target::string,18,2) > 0
            then (
                try_to_decimal(store_record:current_sales::string,18,2)
                /
                try_to_decimal(store_record:sales_target::string,18,2)
            ) * 100

            else null
        end as sales_target_achievement_percentage,

        case
            when try_to_number(store_record:size_sq_ft::string) > 0
            then
                try_to_decimal(store_record:current_sales::string,18,2)
                /
                try_to_number(store_record:size_sq_ft::string)

            else null
        end as revenue_per_sq_ft,

        case
            when try_to_number(store_record:employee_count::string) > 0
            then
                try_to_decimal(store_record:current_sales::string,18,2)
                /
                try_to_number(store_record:employee_count::string)

            else null
        end as employee_efficiency,

        case
            when
                (
                    try_to_decimal(store_record:current_sales::string,18,2)
                    /
                    nullif(
                        try_to_decimal(store_record:sales_target::string,18,2),
                        0
                    )
                ) * 100 < 90
            then true

            else false

        end as has_performance_issue,

        try_to_decimal(
            store_record:monthly_rent::string,
            18,2
        ) as monthly_rent,

        -------------------------------------------------
        -- Store Attributes
        -------------------------------------------------

        store_record:is_active::boolean as is_active,

        store_record:services as services,

        -------------------------------------------------
        -- Operating Hours
        -------------------------------------------------

        store_record:operating_hours.weekdays::string
            as weekdays_hours,

        store_record:operating_hours.weekends::string
            as weekends_hours,

        store_record:operating_hours.holidays::string
            as holidays_hours,

        -------------------------------------------------
        -- Dates
        -------------------------------------------------

        try_to_date(
            store_record:opening_date::string
        ) as opening_date,

        datediff(
            year,
            try_to_date(store_record:opening_date::string),
            current_date()
        ) as store_age_years,

        try_to_date(
            store_record:last_modified_date::string
        ) as last_modified_date,

        -------------------------------------------------
        -- Address
        -------------------------------------------------

        initcap(store_record:address.city::string) as city,
        upper(store_record:address.state::string) as state,
        upper(store_record:address.country::string) as country,
        initcap(store_record:address.street::string) as street,
        store_record:address.zip_code::string as zip_code,

        concat(
            initcap(store_record:address.street::string),
            ', ',
            initcap(store_record:address.city::string),
            ', ',
            upper(store_record:address.state::string),
            ', ',
            upper(store_record:address.country::string),
            ' ',
            store_record:address.zip_code::string
        ) as full_address,

        case
            when regexp_like(
                store_record:address.zip_code::string,
                '^[0-9]{5}$'
            )
            then store_record:address.zip_code::string

            else null
        end as validated_zip_code,
        -------------------------------------------------
        -- Metadata
        -------------------------------------------------

        _source_file,
        _loaded_at

    from store_source

)

, deduplicated as (

    select *

    from cleaned

    qualify row_number() over (

        partition by store_id

        order by
            last_modified_date desc,
            _loaded_at desc

    ) = 1

)

select *
from deduplicated