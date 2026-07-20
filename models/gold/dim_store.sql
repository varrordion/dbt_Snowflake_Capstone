{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

select

    {{ dbt_utils.generate_surrogate_key(['store_id', 'dbt_valid_from']) }}
        as store_key,

    store_id,
    manager_id,

    store_name,
    store_type,
    region,
    store_size_category,

    full_address,
    street,
    city,
    state,
    country,
    zip_code,
    validated_zip_code,

    email,
    phone_number,

    employee_count,
    size_sq_ft,
    monthly_rent,

    opening_date,
    store_age_years,

    is_active,
    services,

    weekdays_hours,
    weekends_hours,
    holidays_hours,

    current_sales,
    sales_target,
    sales_target_achievement_percentage,
    revenue_per_sq_ft,
    employee_efficiency,
    has_performance_issue,

    dbt_valid_from as valid_from,
    coalesce(dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    case when dbt_valid_to is null then true else false end as is_current

from {{ ref('snapshot_store') }}