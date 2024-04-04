{%- macro graph_lookup(
  params = none,
  override_target_metadata=none,
  stage_name=none
  ) -%}

{{
    config(
        materialized='table',
        order_by=('key_number')
    )
}}

with all_keys as
(select distinct hash as key_hash from {{ ref('graph_tuples') }}
union distinct select distinct node_left as key_hash from {{ ref('graph_tuples') }})

select *, row_number() over() as key_number from all_keys


{% endmacro %}