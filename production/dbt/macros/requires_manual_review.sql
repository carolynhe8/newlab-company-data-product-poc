{% macro requires_manual_review(field_expression) -%}
COALESCE({{ field_expression }}, TRUE)
{%- endmacro %}

