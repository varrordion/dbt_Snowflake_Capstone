{% snapshot snapshot_customer %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='last_modified_date',
    )
}}

select *
from {{ ref('silver_customer') }}
{% endsnapshot %}