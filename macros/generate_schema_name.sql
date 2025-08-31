{% macro generate_schema_name(custom_schema_name, node) -%}
  {#
    Use a single dataset per environment for models, and a separate dataset for tests.
    - Models: <target.schema>
    - Tests:  <target.schema>_tests (e.g., dog_explorer_dev_tests / dog_explorer_tests)
  #}
  {% if node is defined and node.resource_type == 'test' %}
    {{ target.schema ~ '_tests' }}
  {% else %}
    {{ target.schema }}
  {% endif %}
{%- endmacro %}


