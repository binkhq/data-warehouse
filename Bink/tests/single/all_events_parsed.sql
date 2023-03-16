{{ config(
    tags=['business']
    ,meta={"description": "Check if all events generated in raw make there way to a fact table in prod.", 
            "test_type": "Business"},
) }}

with events_src as (
    SELECT EVENT_ID
    FROM {{ ref('stg_hermes__EVENTS')}}
    -- WHERE EVENT_TYPE IN ('lc.auth.request', 'lc.addandauth.request', 'user.created', 'lc.register.failed', 'lc.auth.failed', 'lc.addandauth.success', 'user.deleted', 'lc.register.success', 'lc.join.failed', 'lc.auth.success', 'payment.account.added', 'payment.account.status.change', 'payment.account.removed', 'lc.join.request', 'lc.statuschange', 'transaction.exported', 'lc.join.success', 'lc.removed', 'lc.addandauth.failed', 'lc.register.request')
)

 ,fact_tables as (
    {% set get_tables  %}
    SELECT TABLE_NAME
    FROM {{target.database}}.INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = '{{target.schema}}'
    AND TABLE_NAME LIKE 'FACT%'
    {% endset %}

    {# Get column list #}
    {% set results = run_query(get_tables) %}

    {% if execute %}
    {# Return the first column as a list #}
    {% set results_list = results.columns[0].values() %}
    {% else %}
    {% set results_list = [] %}
    {% endif %}


    {%- for item in results_list
    -%}
        {%- if item != 'FACT_VOUCHER' %}
            {%- if not loop.first %} UNION ALL {% endif %}
            SELECT event_id FROM {{target.database}}.{{target.schema}}.{{ item }}
        {% endif %}
    {%- endfor -%}
)

,events_minus_facts as (
    SELECT EVENT_ID FROM events_src
    EXCEPT 
    SELECT EVENT_ID FROM fact_tables
)

,facts_minus_events as (
    SELECT EVENT_ID FROM fact_tables
    EXCEPT
    SELECT EVENT_ID FROM events_src
)

,sum_except_all as (
    SELECT * FROM events_minus_facts
    UNION ALL
    SELECT * FROM facts_minus_events
)

SELECT * FROM sum_except_all