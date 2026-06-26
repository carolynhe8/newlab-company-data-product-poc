{% macro normalize_membership_category(field_expression) -%}
COALESCE({{ field_expression }}, 'Uncategorized')
{%- endmacro %}

