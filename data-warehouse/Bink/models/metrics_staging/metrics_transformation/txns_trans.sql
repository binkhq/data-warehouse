/*
Created by:         Christopher Mitchell
Created date:       2023-07-17
Last modified by:
Last modified date:

Description:
    User table, which relates to the transform date into do date and from date for metrics layer

Parameters:
    ref_object      - stg_metrics__fact_transaction
*/
with
trans_events as (select * from {{ ref("stg_metrics__fact_transaction") }}),

filter_data as (
    select *
    from trans_events
    where
    {% for retailor, dates in var("retailor_live_dates").items() %}
        ((loyalty_plan_company = '{{retailor}}' and date >= '{{dates[0]}}' and date <= '{{dates[1]}}') or loyalty_plan_company != '{{retailor}}')
    {%- if not loop.last %} and {% endif -%}
    {% endfor %}
),

transforming_refs as (
    select
        date,
        user_id,
        -- external_user_ref,
        channel,
        brand,
        coalesce(nullif(external_user_ref, ''), user_id) as user_ref,
        transaction_id,
        -- provider_slug,
        duplicate_transaction,
        feed_type,
        loyalty_plan_name,
        loyalty_plan_company,
        transaction_date,
        spend_amount,
        -- loyalty_id,
        -- merchant_id, 
        -- payment_account_id,
        loyalty_card_id
    from filter_data
),

txn_flag as (
    select
        *,
        case
            when duplicate_transaction
                then 'DUPLICATE'
            when
                loyalty_plan_company = 'Viator'
                and (spend_amount = 1 or spend_amount = -1)
                then 'BNPL'
            when spend_amount > 0
                then 'TXNS'
            when spend_amount < 0
                then 'REFUND'
            else 'OTHER'
        end as status
    from transforming_refs
)

select *
from txn_flag
