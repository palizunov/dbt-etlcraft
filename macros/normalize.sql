{%- macro normalize(source_table=none, included_fields=[], excluded_fields=[], defaults_dict=etlcraft_defaults()) -%}
{%- if execute -%}
    {%- set model_name_parts = this.name.split('_') -%}
    {%- if model_name_parts|length < 5 or model_name_parts[0] != 'normalize' -%}
        {{ exceptions.raise_compiler_error('Model name "' ~ this.name ~ '" does not follow the expected pattern: "normalize_{sourcetype}_{templatename}_{streamname}(__auto)?", where suffix is "auto" is optional') }}
    {%- endif -%}
    {%- set source_type = model_name_parts[1] -%}
    {%- set template_name = model_name_parts[3] -%}
    {%- set stream_name_parts = model_name_parts[4:-2] if model_name_parts[-1] == 'auto' else model_name_parts[4:] -%}
    {%- set stream_name = '_'.join(stream_name_parts) -%}
    {%- set schema_pattern = this.schema -%}
    {%- set table_pattern = '_airbyte_raw_' ~ source_type ~ '_%_' ~ template_name ~ '_' ~ stream_name -%}

    {%- if source_table is none -%}
        {%- set relations = dbt_utils.get_relations_by_pattern(schema_pattern=target.schema, 
                                                              table_pattern=table_pattern) -%}
        {%- if relations|length < 1 -%}
            {{ exceptions.raise_compiler_error('No relations were found matching the pattern "' ~ table_pattern ~ '". Please ensure that your source data follows the expected structure.') }}
        {%- endif -%}
        {%- set source_table = dbt_utils.union_relations(relations) -%}    
    {%- endif -%}

    {%- set json_keys = fromjson(run_query('SELECT ' ~ json_list_keys('_airbyte_data') ~ ' FROM ' ~ source_table ~ ' LIMIT 1').columns[0].values()[0])  -%}    
    
    {%- set default_included_fields = [] -%}
    {%- set default_excluded_fields = [] -%}
    {%- if defaults_dict['sourcetypes'][source_type] is defined -%}
        {%- set default_included_fields = defaults_dict.get('sourcetypes', {}).get(source_type, {}).get('included_fields', []) -%}
        {%- set default_excluded_fields = defaults_dict.get('sourcetypes', {}).get(source_type, {}).get('excluded_fields', []) -%}
        {%- if defaults_dict.get('sourcetypes', {}).get(source_type, {}).get('streams', {})[stream_name] is defined -%}
            {%- set default_included_fields = default_included_fields + defaults_dict.get('sourcetypes', {}).get(source_type, {}).get('streams', {}),get(stream_name, {}).get('included_fields', []) -%}
            {%- set default_excluded_fields = default_excluded_fields + defaults_dict.get('sourcetypes', {}).get(source_type, {}).get('streams', {}).get(stream_name, {}).get('excluded_fields', []) -%}
        {%- endif -%}
    {%- endif -%}

    {%- set column_list = set(json_keys).union(set(included_fields)).union(set(default_included_fields)).difference(set(excluded_fields)).difference(set(default_excluded_fields)) -%}
    {%- set column_list = [] -%}
    {%- for key in column_list -%}
        {%- do column_list.append(json_extract_string('_airbyte_data', key) ~ " AS " ~ normalize_name(key)) -%}
    {%- endfor -%}
    SELECT
        _dbt_source_relation AS _table_name,        
        _airbyte_emited_at AS _emited_at,
        NOW() as _normalized_at,
        {{ column_list|join(', \n') }}
    FROM {{ source_table }}
{%- endif -%}
{%- endmacro -%}