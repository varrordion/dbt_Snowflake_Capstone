{% snapshot snapshot_store %}

{{
    config(
      target_schema='CAPSTONE_SNAPSHOT',
      unique_key='store_id',
      strategy='timestamp',
      updated_at='last_modified_date',
      invalidate_hard_deletes=True
    )
}}

select *
from {{ ref('silver_store') }}

{% endsnapshot %}