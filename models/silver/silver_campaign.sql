{{ config(
    materialized='view',
    tags=['silver']
) }}

with campaign_source as (
    select
        campaign.value as campaign_record,
        _source_file,
        _source_file_row_number,
        _source_file_last_modified,
        _loaded_at
    from {{ ref('bronze_campaign') }},
    lateral flatten(
        input => raw_record:campaigns_data
    ) campaign
)

, cleaned as (
    select
        campaign_record:campaign_id::string as campaign_id,
        -------------------------------------------------
        -- Campaign Details
        -------------------------------------------------
        initcap(campaign_record:campaign_name::string) as campaign_name,
        initcap(campaign_record:campaign_type::string) as campaign_type,
        initcap(campaign_record:channel::string) as channel,
        campaign_record:description::string as description,
        campaign_record:target_audience::string as target_audience,
        -------------------------------------------------
        -- Financial Metrics
        -------------------------------------------------
        try_to_decimal(regexp_replace(campaign_record:budget::string,'[$,]',''),18,2) as budget,
        try_to_decimal(regexp_replace(campaign_record:total_cost::string,'[$,]',''),18,2) as total_cost,
        try_to_decimal(regexp_replace(campaign_record:total_revenue::string,'[$,]',''),18,2) as total_revenue,
        try_to_decimal(campaign_record:roi_calculation::string,10,2) as roi_calculation,
        -------------------------------------------------
        -- Dates
        -------------------------------------------------
        try_to_timestamp(campaign_record:start_date::string) as start_date,
        try_to_timestamp(campaign_record:end_date::string) as end_date,
        try_to_date(campaign_record:last_modified_date::string) as last_modified_date,
        -------------------------------------------------
        -- Metadata
        -------------------------------------------------
        _source_file,
        _loaded_at
    from campaign_source
)

, deduplicated as (
    select *
    from cleaned
    qualify row_number() over (
        partition by campaign_id
        order by
            last_modified_date desc,
            _loaded_at desc
    ) = 1
)

select *
from deduplicated