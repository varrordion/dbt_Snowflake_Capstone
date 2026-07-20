{% snapshot snapshot_bronze_employee %}

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
from {{ ref('bronze_employee') }}

{% endsnapshot %}


select
    _business_key,
    _source_file_last_modified,
    count(*)
from {{ ref('bronze_employee') }}
group by _business_key, _source_file_last_modified
having count(*) > 1;