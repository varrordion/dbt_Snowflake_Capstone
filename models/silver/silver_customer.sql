{{ config(
    materialized='view',
    tags=['silver']
) }}

with customer_source as (
    select
        customer.value as customer_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at

    from {{ ref('bronze_customer') }},

    lateral flatten(
        input => raw_record:customers_data
    ) customer

)
, cleaned as (

    select


        -- IDs
        trim(customer_record:customer_id::string) as customer_id,

        -- Names
        initcap(trim(customer_record:first_name::string)) as first_name,
        initcap(trim(customer_record:last_name::string)) as last_name,
        concat(initcap(trim(customer_record:first_name::string)),' ',initcap(trim(customer_record:last_name::string))
        ) as full_name,

        -- Email


        case
            when regexp_like(
                lower(trim(customer_record:email::string)),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$'
            )
            then lower(trim(customer_record:email::string))
            else null
        end as email,

        case
            when regexp_like(
                lower(trim(customer_record:email::string)),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$'
            )
            then true
            else false
        end as is_valid_email,
 
        --PHONE

        case
            when length(
                regexp_replace(
                    upper(customer_record:phone::string),
                    '[^0-9X]',
                    ''
                )
            ) >= 10
            then regexp_replace(
                upper(customer_record:phone::string),
                '[^0-9X]',
                ''
            )
            else null
        end as phone,

        case
            when length(
                regexp_replace(
                    upper(customer_record:phone::string),
                    '[^0-9X]',
                    ''
                )
            ) >= 10
            then true
            else false
        end as is_valid_phone,

        -- Dates

        try_to_date(customer_record:birth_date::string) as birth_date,
        try_to_date(customer_record:registration_date::string) as registration_date,
        try_to_date(customer_record:last_purchase_date::string) as last_purchase_date,
        try_to_date(customer_record:last_modified_date::string) as last_modified_date,
        datediff(
            year,
            try_to_date(customer_record:birth_date::string),
            current_date()
        ) as customer_age,

        case
            when datediff(
                year,
                try_to_date(customer_record:birth_date::string),
                current_date()
            ) between 18 and 35
                then 'YOUNG'

            when datediff(
                year,
                try_to_date(customer_record:birth_date::string),
                current_date()
            ) between 36 and 55
                then 'MIDDLE_AGED'

            when datediff(
                year,
                try_to_date(customer_record:birth_date::string),
                current_date()
            ) >= 56
                then 'SENIOR'

            else 'UNKNOWN'
        end as customer_segment,

        -- Numeric
        try_to_number(customer_record:total_purchases::string) as total_purchases,
        try_to_decimal(customer_record:total_spend::string,18,2) as total_spend,

        -- Boolean
        customer_record:marketing_opt_in::boolean
            as marketing_opt_in,

        -- Text Standardization
        upper(trim(customer_record:loyalty_tier::string)) as loyalty_tier,
        upper(trim(customer_record:income_bracket::string)) as income_bracket,
        initcap(lower(trim(customer_record:occupation::string))) as occupation,
        upper(trim(customer_record:preferred_communication::string)) as preferred_communication,

        initcap(lower(trim(customer_record:preferred_payment_method::string))) as preferred_payment_method,


        --Address

        initcap(trim(customer_record:address.street::string)) as street,
        initcap(trim(customer_record:address.city::string)) as city,
        upper(trim(customer_record:address.state::string)) as state,
        upper(trim(customer_record:address.country::string)) as country,
        trim(customer_record:address.zip_code::string) as zip_code,

        concat(
            initcap(trim(customer_record:address.street::string)),
            ', ',
            initcap(trim(customer_record:address.city::string)),
            ', ',
            upper(trim(customer_record:address.state::string)),
            ', ',
            upper(trim(customer_record:address.country::string)),
            ' ',
            trim(customer_record:address.zip_code::string)
        ) as full_address,

        -------------------------------------------------
        -- Metadata
        --------------------------------------------d-----

        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at

    from customer_source

)
, deduplicated as (
    select *
    from cleaned
    qualify row_number() over (
        partition by customer_id
        order by
            last_modified_date desc,
            _loaded_at desc
    ) = 1
)

select *
from deduplicated