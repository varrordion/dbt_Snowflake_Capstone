
with tenure_bucketed as (
    select *,
        case
            when tenure_years < 1 then '0-1 years'
            when tenure_years between 1 and 2 then '1-2 years'
            when tenure_years between 3 and 5 then '3-5 years'
            else '5+ years'
        end as tenure_bucket
    from {{ ref('dim_employee') }}
    where is_current
)

select tenure_bucket,    
    count(*) as employee_count,
    round(avg(performance_rating),2) as avg_performance_rating,
    round(avg(target_achievement_percentage),2) as avg_target_achievement_percentage,
    round(avg(total_sales_amount),2) as avg_total_sales_amount
from tenure_bucketed
group by tenure_bucket
order by
    case tenure_bucket
        when '0-1 years' then 1
        when '1-2 years' then 2
        when '3-5 years' then 3
        else 4
    end