{% snapshot snapshot_bronze_customer %}

{{
    config(
      target_schema='CAPSTONE_SNAPSHOT',
      unique_key=['_source_file', '_source_file_last_modified'],
      strategy='timestamp',
      updated_at='_source_file_last_modified',
      invalidate_hard_deletes=True
    )
}}

select *
from {{ ref('bronze_customer') }}

{% endsnapshot %}