{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

select

    {{ dbt_utils.generate_surrogate_key(['employee_id', 'dbt_valid_from']) }}
        as employee_key,

    employee_id,
    manager_id,

    first_name,
    last_name,
    full_name,

    role,
    department,
    employment_status,
    work_location,

    hire_date,
    tenure_years,

    email,
    phone,

    salary,
    current_sales,
    sales_target,
    target_achievement_percentage,
    total_sales_amount,
    performance_rating,

    education,
    certifications,

    date_of_birth,

    street,
    city,
    state,
    zip_code,

    dbt_valid_from as valid_from,
    coalesce(dbt_valid_to, '9999-12-31'::timestamp) as valid_to,
    case when dbt_valid_to is null then true else false end as is_current

from {{ ref('snapshot_employee') }}