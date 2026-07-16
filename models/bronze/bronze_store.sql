{{
    config(
        unique_key=['_business_key', '_source_file_last_modified'],
        incremental_strategy='merge'
    )
}}

{{
    bronze_from_external(
        source_name='capstone_external',
        source_table='store',
        business_key='store_id'
    )
}}