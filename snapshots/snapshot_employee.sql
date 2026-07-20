{% snapshot snapshot_employee %}

{{
    config(
      target_schema='CAPSTONE_SNAPSHOT',
      unique_key='employee_id',
      strategy='timestamp',
      updated_at='last_modified_date',
      invalidate_hard_deletes=True
    )
}}

select *
from {{ ref('silver_employee') }}

{% endsnapshot %}