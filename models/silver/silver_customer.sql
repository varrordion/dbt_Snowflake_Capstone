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
),

cleaned as (
    select
        trim(customer_record:customer_id::string) as customer_id,
        initcap(trim(customer_record:first_name::string)) as first_name,
        initcap(trim(customer_record:last_name::string)) as last_name,
        concat(
            initcap(trim(customer_record:first_name::string)),
            ' ',
            initcap(trim(customer_record:last_name::string))
        ) as full_name,
        case
            when regexp_like(
                lower(trim(customer_record:email::string)),
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$'
            )
            then lower(trim(customer_record:email::string))
            else null
        end as email,
        case
            when length(regexp_replace(customer_record:phone::string,'[^0-9X]','')) >= 10
            then regexp_replace(customer_record:phone::string,'[^0-9X]','')
            else null
        end as phone,
        coalesce(
            try_to_date(customer_record:birth_date::string, 'YYYY-MM-DD'),
            try_to_date(customer_record:birth_date::string, 'MM/DD/YYYY'),
            try_to_date(customer_record:birth_date::string, 'DD/MM/YYYY'),
            try_to_date(customer_record:birth_date::string, 'MM-DD-YYYY'),
            try_to_date(customer_record:birth_date::string, 'DD-MM-YYYY'),
            try_to_date(customer_record:birth_date::string, 'YYYY/MM/DD'),
            try_to_date(customer_record:birth_date::string, 'DD-MON-YYYY'),
            try_to_date(customer_record:birth_date::string, 'MON DD, YYYY'),
            try_to_date(customer_record:birth_date::string, 'DD.MM.YYYY')
        ) as birth_date,
        
        try_to_date(customer_record:registration_date::string) as registration_date,
        try_to_date(customer_record:last_purchase_date::string) as last_purchase_date,
        try_to_date(customer_record:last_modified_date::string) as last_modified_date,
        try_to_number(customer_record:total_purchases::string) as total_purchases,
        try_to_decimal(customer_record:total_spend::string,18,2) as total_spend,
        customer_record:marketing_opt_in::boolean as marketing_opt_in,
        upper(trim(customer_record:loyalty_tier::string)) as loyalty_tier,
        upper(trim(customer_record:income_bracket::string)) as income_bracket,
        initcap(lower(trim(customer_record:occupation::string))) as occupation,
        upper(trim(customer_record:preferred_communication::string)) as preferred_communication,
        initcap(lower(trim(customer_record:preferred_payment_method::string))) as preferred_payment_method,
        initcap(trim(customer_record:address.city::string)) as city,
        upper(trim(customer_record:address.state::string)) as state,
        upper(trim(customer_record:address.country::string)) as country,
        initcap(trim(customer_record:address.street::string)) as street,
        trim(customer_record:address.zip_code::string) as zip_code,
        concat(initcap(trim(customer_record:address.street::string)),
            ', ',initcap(trim(customer_record:address.city::string)),
            ', ',upper(trim(customer_record:address.state::string)),
            ', ',upper(trim(customer_record:address.country::string)),
            ' ',trim(customer_record:address.zip_code::string)) as full_address,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at
    from customer_source
),

business_transformations as (
    select
        *,
        -------------------------------------------------
        -- CUSTOMER AGE
        -------------------------------------------------
        datediff(year, birth_date, current_date()) as customer_age,
        -------------------------------------------------
        -- AGE BUCKET
        -------------------------------------------------
        case
            when datediff(year, birth_date, current_date()) < 25
                then '18-24'
            when datediff(year, birth_date, current_date()) between 25 and 34
                then '25-34'
            when datediff(year, birth_date, current_date()) between 35 and 44
                then '35-44'
            when datediff(year, birth_date, current_date()) between 45 and 54
                then '45-54'
            else '55+'
        end as age_bucket,
        -------------------------------------------------
        -- CUSTOMER TENURE
        -------------------------------------------------
        datediff(month, registration_date, current_date()) as customer_tenure_months,
        -------------------------------------------------
        -- ACTIVE CUSTOMER
        -------------------------------------------------
        case
            when datediff(day, last_purchase_date, current_date()) <= 90
                then true
            else false
        end as is_active_customer,
        -------------------------------------------------
        -- CUSTOMER VALUE
        -------------------------------------------------
        case
            when total_spend >= 30000
                then 'HIGH VALUE'
            when total_spend >= 10000
                then 'MEDIUM VALUE'
            else 'LOW VALUE'
        end as customer_value_bucket,
        -------------------------------------------------
        -- LOYALTY RANK
        -------------------------------------------------
        case
            when loyalty_tier = 'BRONZE' then 1
            when loyalty_tier = 'SILVER' then 2
            when loyalty_tier = 'GOLD' then 3
            when loyalty_tier = 'PLATINUM' then 4
            else null
        end as loyalty_rank,
        -------------------------------------------------
        -- MARKETING SEGMENT
        -------------------------------------------------
        case
            when marketing_opt_in = true then 'MARKETABLE'
            else 'DO_NOT_CONTACT'
        end as marketing_segment,
        -------------------------------------------------
        -- COMMUNICATION GROUP
        -------------------------------------------------
        case
            when preferred_communication in ('EMAIL', 'SMS') then 'DIGITAL'
            when preferred_communication = 'PHONE' then 'VOICE'
            else 'OTHER'
        end as communication_group
    from cleaned
),

deduplicated as (
    select *
    from business_transformations
    qualify row_number() over (
        partition by customer_id
        order by
            last_modified_date desc,
            _source_file_last_modified desc,
            _loaded_at desc
    ) = 1
)

select *
from deduplicated