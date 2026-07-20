{{
    config(
        materialized='table',
        tags=['gold']
    )
}}

with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2024-04-01')",
        end_date="to_date('2024-09-28')"
    ) }}

),

holidays as (

    select column1 as holiday_date, column2 as holiday_name
    from values
        ('2024-05-27', 'Memorial Day'),
        ('2024-06-19', 'Juneteenth'),
        ('2024-07-04', 'Independence Day'),
        ('2024-09-02', 'Labor Day')

),

calculated as (

    select

        to_number(to_char(date_day, 'YYYYMMDD')) as date_key,

        date_day as full_date,

        year(date_day) as year,
        quarter(date_day) as quarter,
        month(date_day) as month,
        monthname(date_day) as month_name,

        week(date_day) as week,

        dayofweek(date_day) as day_of_week_number,
        dayname(date_day) as day_of_week,

        case
            when dayofweek(date_day) in (0, 6) then true
            else false
        end as is_weekend,

        case
            when h.holiday_date is not null then true
            else false
        end as is_holiday,

        h.holiday_name,

        case
            when month(date_day) in (12, 1, 2) then 'Winter'
            when month(date_day) in (3, 4, 5) then 'Spring'
            when month(date_day) in (6, 7, 8) then 'Summer'
            else 'Fall'
        end as season

    from date_spine ds
    left join holidays h
        on ds.date_day = to_date(h.holiday_date)

)

select *
from calculated