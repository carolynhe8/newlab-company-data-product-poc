{% macro newlab_surrogate_key(fields) -%}
TO_HEX(
  SHA256(
    CONCAT(
      {%- for field in fields -%}
        COALESCE(CAST({{ field }} AS STRING), '')
        {%- if not loop.last -%}, '|', {%- endif -%}
      {%- endfor -%}
    )
  )
)
{%- endmacro %}

