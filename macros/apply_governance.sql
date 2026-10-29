{% macro apply_governance() %}
  {% set enabled_targets = var('governance_targets', ['prod']) %}

  {% if execute and target.name in enabled_targets %}

    {% set obj = 'VIEW' if config.get('materialized') == 'view' else 'TABLE' %}
    {% set model_meta = model.config.meta or model.meta or {} %}

    {# 1. Row-level security (model-level meta) #}
    {% set rap = model_meta.get('row_access_policy') %}
    {% if rap %}
      {# Drop any existing row policy first so re-runs (incremental) don't fail #}
      {% set check_sql %}
        select count(*) from table(
          {{ this.database }}.information_schema.policy_references(
            ref_entity_name => '{{ this }}', ref_entity_domain => '{{ obj }}'))
        where policy_kind = 'ROW_ACCESS_POLICY'
      {% endset %}
      {% set existing = run_query(check_sql).columns[0].values()[0] %}
      {% if existing | int > 0 %}
        {% do run_query("ALTER " ~ obj ~ " " ~ this ~ " DROP ALL ROW ACCESS POLICIES") %}
      {% endif %}
      {% do run_query("ALTER " ~ obj ~ " " ~ this ~ " ADD ROW ACCESS POLICY " ~ rap.policy ~ " ON (" ~ rap.column ~ ")") %}
      {% do log("Row access policy applied on " ~ this, info=True) %}
    {% endif %}

    {# 2. Column-level: masking policy + tag #}
    {% for col in model.columns.values() %}
      {% set cmeta = col.meta or {} %}

      {% if cmeta.get('masking_policy') %}
        {% do run_query("ALTER " ~ obj ~ " " ~ this ~ " MODIFY COLUMN " ~ col.name ~ " SET MASKING POLICY " ~ cmeta.masking_policy ~ " FORCE") %}
        {% do log("Masking policy applied: " ~ col.name, info=True) %}
      {% endif %}

      {% if cmeta.get('tag_name') and cmeta.get('tag_value') %}
        {% do run_query("ALTER " ~ obj ~ " " ~ this ~ " MODIFY COLUMN " ~ col.name ~ " SET TAG " ~ cmeta.tag_name ~ " = '" ~ cmeta.tag_value ~ "'") %}
        {% do log("Tag applied: " ~ col.name, info=True) %}
      {% endif %}
    {% endfor %}

  {% endif %}
{% endmacro %}