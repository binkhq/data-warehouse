/*
Created by:         Anand Bhakta
Created date:       2023-07-12
Last modified by:
Last modified date:

Description:
    Set up of error to and from data for loyalty card error statuses excluding pending and active
Parameters:
    source_object       - src__fact_lc_status_change
                        - src__lookup_status_mapping
*/
{{
    config(
        materialized="incremental",
        unique_key="EVENT_ID"
    )
}}

with
pll_events as (select * from {{ ref("stg_metrics__pll_link_status_change") }}
where
{# 
    {%- for retailor, exclusions in var("retailor_exclusion_lists").items() %}
        {%- for field, list in exclusions.items() %}
        ((loyalty_plan_company = '{{retailor}}' and  {{field}} not in (
                {%- for value in list -%}
                    '{{value}}'
                {%- if not loop.last %} , {% endif -%}
                {%- endfor -%}
            ) or loyalty_plan_company != '{{retailor}}')
        {%- if not loop.last %} and {% endif -%}
        {% endfor %}
    {%- if not loop.last %} and {% endif -%}
    {% endfor %}) -- ridiculous solution for excluding values per merchant
#}
    {% for retailor, dates in var("retailor_live_dates").items() %}
        ((loyalty_plan_company = '{{retailor}}' and event_date_time >= '{{dates[0]}}' and event_date_time <= '{{dates[1]}}') or loyalty_plan_company != '{{retailor}}')
    {%- if not loop.last %} and {% endif -%}
    {% endfor %}

    {% if is_incremental() %}
            and
            inserted_date_time >= (select max(inserted_date_time) from {{ this }})
    {% endif %}

),

union_old_lc_records as (
    select *
    from pll_events
    {% if is_incremental() %}
        union
        select *
        from {{ ref("stg_metrics__pll_link_status_change") }}
        where
            (loyalty_card_id, payment_account_id) in (
                select loyalty_card_id, payment_account_id from pll_events
            )
    {% endif %}
),

from_to_dates as (
    select
        event_id,
        coalesce(nullif(external_user_ref, ''), user_id) as user_ref,
        concat(
            coalesce(nullif(external_user_ref, ''), user_id),
            loyalty_plan_company
        ) as lc_user_ref,
        channel,
        brand,
        loyalty_card_id,
        loyalty_plan_company,
        loyalty_plan_name,
        payment_account_id,
        event_date_time as from_date,
        coalesce(
            lead(event_date_time, 1) over (
            partition by loyalty_card_id, payment_account_id
            order by event_date_time asc
        ),
            case loyalty_plan_company
                {% for retailor, dates in var("retailor_live_dates").items() %}
                     when '{{retailor}}' then '{{dates[1]}}'
                {% endfor %}
            else '9999-12-31'
            end
        ) as to_date,
        to_status as status,
        to_status = 'ACTIVE' as active_link,
        inserted_date_time,
        sysdate() as updated_date_time
    from union_old_lc_records
)

select *
from from_to_dates
