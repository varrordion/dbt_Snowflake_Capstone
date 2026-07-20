{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

select

    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_valid_from']) }}
        as customer_sk,

    customer_id,
    full_name,
    email,
    phone,

    city,
    state,
    country,
    street,
    zip_code,
    full_address,

    birth_date,
    income_bracket,
    occupation,
    customer_age,
    age_bucket,

    customer_value_bucket as customer_segment_impact,
    loyalty_tier,

    dbt_valid_from as valid_from,
    coalesce(dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    case when dbt_valid_to is null then true else false end as is_current

from {{ ref('snapshot_customer') }}