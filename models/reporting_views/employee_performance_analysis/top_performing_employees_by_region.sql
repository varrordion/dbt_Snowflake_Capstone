with cte as (SELECT
rank() over(partition by ds.region order by de.target_achievement_percentage desc) as rank,
DE.MANAGER_ID,
DS.REGION
FROM
{{ref("dim_employee")}} de JOIN {{ref("dim_store")}} ds on de.manager_id = ds.manager_id
)

select
MANAGER_ID , REGION
FROM CTE WHERE RANK = 1

