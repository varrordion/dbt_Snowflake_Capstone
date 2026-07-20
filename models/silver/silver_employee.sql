{{ config(
    materialized='view',
    tags=['silver']
) }}

with employee_source as (
    select
        employee.value as employee_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at
    from {{ ref('snapshot_bronze_employee') }},
    lateral flatten(
        input => raw_record:employees_data
    ) employee
)

, cleaned as (
    select
        employee_record:employee_id::string as employee_id,
        employee_record:manager_id::string as manager_id,
        initcap(employee_record:first_name::string) as first_name,
        initcap(employee_record:last_name::string) as last_name,
        concat(initcap(employee_record:first_name::string),' ',initcap(employee_record:last_name::string)) as full_name,

        case
            when regexp_like(lower(employee_record:email::string),'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$')
            then lower(employee_record:email::string)
            else null
        end as email,

        case
            when length(regexp_replace(employee_record:phone::string,'[^0-9]','')) >= 10
            then regexp_replace(employee_record:phone::string,'[^0-9]','')
            else null
        end as phone,

        initcap(employee_record:department::string) as department,

        case
            when lower(employee_record:role::string) = 'sales associate' then 'Associate'
            when lower(employee_record:role::string) = 'store manager' then 'Manager'
            when lower(employee_record:role::string) = 'senior manager' then 'Senior Manager'
            else initcap(employee_record:role::string)
        end as role,

        upper(employee_record:employment_status::string) as employment_status,
        upper(employee_record:work_location::string) as work_location,
        initcap(employee_record:education::string) as education,
        employee_record:certifications as certifications,
        try_to_decimal(employee_record:salary::string,18,2) as salary,
        try_to_decimal(employee_record:current_sales::string,18,2) as current_sales,
        try_to_decimal(employee_record:sales_target::string,18,2) as sales_target,

        case
            when try_to_decimal(employee_record:sales_target::string,18,2) > 0
            then
                (try_to_decimal(employee_record:current_sales::string,18,2)/try_to_decimal(employee_record:sales_target::string,18,2)) * 100
            else null
        end as target_achievement_percentage,

        null as orders_processed,
        try_to_decimal(employee_record:current_sales::string,18,2) as total_sales_amount,
        try_to_decimal(employee_record:performance_rating::string,5,2) as performance_rating,
        try_to_date(employee_record:date_of_birth::string) as date_of_birth,
        try_to_date(employee_record:hire_date::string) as hire_date,
        datediff(year,try_to_date(employee_record:hire_date::string),current_date()) as tenure_years,
        try_to_date(employee_record:last_modified_date::string) as last_modified_date,
        initcap(employee_record:address.city::string) as city,
        upper(employee_record:address.state::string) as state,
        initcap(employee_record:address.street::string) as street,
        employee_record:address.zip_code::string as zip_code,
     

        -- Metadata
        _source_file,
        _loaded_at
    from employee_source
)

, deduplicated as (
    select *
    from cleaned
    qualify row_number() over (
        partition by employee_id
        order by
            last_modified_date desc,
            _loaded_at desc
    ) = 1
)

select *
from deduplicated