/*
Created by:         Christopher Mitchell
Created date:       2023-07-17
Last modified by: Anand Bhakta
Last modified date: 2023-12-19

Description:
    Transaction metrics by retailer on a daily granularity. 
Notes:
    source_object       - txns_trans
*/

{{
    config(
        materialized="incremental"
    )
}}

with
txn_events as (select * from {{ ref("txns_trans") }}
    {% if is_incremental() %}
            where
            inserted_date_time >= (select max(inserted_date_time) from {{ this }})
    {% endif %}
),

dim_date as (
    select distinct
        date
    from {{ ref("stg_metrics__dim_date") }}
    where date >= (select min(date) from txn_events) and date <= current_date()
),

stage as (
    select
        user_ref,
        transaction_id,
        loyalty_plan_name,
        loyalty_plan_company,
        channel,
        brand,
        status,
        DATE(date) as date,
        spend_amount,
        loyalty_card_id
    from txn_events
),

txn_period as (
    select
        d.date as date,
        s.loyalty_plan_company,
        s.loyalty_plan_name,
        s.channel,
        s.brand,
        sum(
            case when status = 'TXNS' then s.spend_amount end
        ) as spend_amount_period_positive,
        sum(
            case when status = 'REFUND' then s.spend_amount end
        ) as refund_amount_period,
        sum(
            case when status in ('TXNS','REFUND') then s.spend_amount end
        ) as net_spend_amount_period,
        count(
            distinct case when status = 'BNPL' then transaction_id end
        ) as count_bnpl_period,
        count(
            distinct case when status = 'TXNS' then transaction_id end
        ) as count_transaction_period,
        count(
            distinct case when status = 'REFUND' then transaction_id end
        ) as count_refund_period,
        count(
            distinct case when status = 'DUPLICATE' then transaction_id end
        ) as count_dupe_period
    from stage s
    left join dim_date d on d.date = s.date
    group by d.date, s.loyalty_plan_company, s.loyalty_plan_name, s.channel, s.brand
),

txn_union as (
    select * from txn_period
    {% if is_incremental() %}
    union
    select
        date,
        loyalty_plan_company,
        loyalty_plan_name,
        channel,
        brand,
        T073__SPEND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        T074__REFUND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        T079__NET_SPEND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        T078__BNPL_TXNS__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        T075__TXNS__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        T076__REFUND__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        T077__DUPLICATE_TXN__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT
    from {{ this }}
    {% endif %}
),

txn_combine as (
    select
        date,
        loyalty_plan_company,
        loyalty_plan_name,
        channel,
        brand,
        sum(spend_amount_period_positive) as spend_amount_period_positive,
        sum(refund_amount_period) as refund_amount_period,
        sum(net_spend_amount_period) as net_spend_amount_period,
        sum(count_bnpl_period) as count_bnpl_period,
        sum(count_transaction_period) as count_transaction_period,
        sum(count_refund_period) as count_refund_period,
        sum(count_dupe_period) as count_dupe_period
    from txn_union
    group by date, loyalty_plan_company, loyalty_plan_name, channel, brand
),

txn_cumulative as (
    select
        date,
        loyalty_plan_company,
        loyalty_plan_name,
        channel,
        brand,
        spend_amount_period_positive,
        refund_amount_period,
        net_spend_amount_period,
        count_bnpl_period,
        count_transaction_period,
        count_refund_period,
        count_dupe_period,
        sum(spend_amount_period_positive) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_spend,
        sum(refund_amount_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_refund,
        sum(net_spend_amount_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_net_spend,
        sum(count_bnpl_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_bnpl_txns,
        sum(count_transaction_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_txns,
        sum(count_refund_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_refund_txns,
        sum(count_dupe_period) over (
            partition by loyalty_plan_company, brand order by date
        ) as cumulative_dupe_txns
    from txn_combine
),

finalise as 
    (select
        date,
        loyalty_plan_company,
        loyalty_plan_name,
        channel,
        brand,
        cumulative_spend AS T067__SPEND__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        cumulative_refund AS T068__REFUND__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        cumulative_txns AS T069__TXNS__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        cumulative_refund_txns AS T070__REFUND__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        cumulative_dupe_txns AS T071__DUPLICATE_TXN__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        cumulative_bnpl_txns AS T072__BNPL_TXNS__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        spend_amount_period_positive AS T073__SPEND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        refund_amount_period AS T074__REFUND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        count_transaction_period AS T075__TXNS__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        count_refund_period AS T076__REFUND__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        count_dupe_period AS T077__DUPLICATE_TXN__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        count_bnpl_period AS T078__BNPL_TXNS__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        net_spend_amount_period AS T079__NET_SPEND__DAILY_CHANNEL_BRAND_RETAILER__SUM,
        cumulative_net_spend AS T080__NET_SPEND__DAILY_CHANNEL_BRAND_RETAILER__CSUM,
        count_transaction_period+count_refund_period AS T081__TXNS_AND_REFUNDS__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        count_dupe_period+count_transaction_period AS T082__TXNS_AND_DUPES__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT,
        DIV0(count_dupe_period,T082__TXNS_AND_DUPES__DAILY_CHANNEL_BRAND_RETAILER__DCOUNT) AS T083__DUPLICATE_TXN_PER_TXN__DAILY_CHANNEL_BRAND_RETAILER__PERCENTAGE,
        sysdate() as inserted_date_time
    from txn_cumulative
)


select *
from finalise
