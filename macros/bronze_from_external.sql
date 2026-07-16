{% macro bronze_from_external(
    source_name,
    source_table,
    business_key,
    raw_column='VALUE',
    modified_field='last_modified_date'
) %}

with source_records as (

    select
        {{ raw_column }} as raw_record,

        {{ raw_column }}:{{ business_key }} as _business_key,

        {{ raw_column }}:{{ modified_field }} as _source_last_modified_date,

        metadata$filename as _source_file,

        metadata$file_row_number as _source_file_row_number,

        metadata$file_last_modified as _source_file_last_modified,

        current_timestamp() as _loaded_at,

        '{{ invocation_id }}' as _dbt_invocation_id

    from {{ source(source_name, source_table) }}

    {% if is_incremental() %}

        where metadata$file_last_modified >
        (
            select coalesce(
                max(_source_file_last_modified),
                '1900-01-01'::timestamp_ntz
            )
            from {{ this }}
        )

    {% endif %}

)

select
    raw_record,
    _business_key,
    _source_last_modified_date,
    _source_file,
    _source_file_row_number,
    _source_file_last_modified,
    _loaded_at,
    _dbt_invocation_id
from source_records

{% endmacro %}