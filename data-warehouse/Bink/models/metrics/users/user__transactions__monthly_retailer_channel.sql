/*
CREATED BY:         CHRISTOPHER MITCHELL
CREATED DATE:       2023-11-02
LAST MODIFIED BY:   
LAST MODIFIED DATE: 

DESCRIPTION:
    USER TRANSACTION METRICS MONTHLY BY RETAILER
PARAMETERS:
    SOURCE_OBJECT       - TXNS_TRANS
                        - STG_METRICS__DIM_DATE
*/
with
user_events as (select * from {{ ref("txns_trans") }}),

dim_date as (
    select distinct
        start_of_month,
        end_of_month
    from {{ ref("stg_metrics__dim_date") }}
    where date >= (select min(date) from user_events) and date <= current_date()
),

user_snap as (
    select
        d.start_of_month as date,
        u.channel,
        u.brand,
        u.loyalty_plan_company,
        u.loyalty_plan_name,
        coalesce(count(
            DISTINCT CASE WHEN STATUS = 'TXNS' THEN user_ref END
        ),0) as u108_active_users_retailer_monthly__cdcount_uid,
        coalesce(count(
            DISTINCT CASE WHEN STATUS IN ('TXNS', 'REFUND') THEN user_ref END
        ),0) as u111_active_users_inc_refunds__retailer_monthly__cdcount_uid
    from user_events u
    left join dim_date d on date(u.date) <= d.end_of_month
    group by d.start_of_month, u.channel, u.brand, u.loyalty_plan_company, u.loyalty_plan_name
),

user_period as (
    select
        d.start_of_month as date,
        u.channel,
        u.brand,
        u.loyalty_plan_company,
        u.loyalty_plan_name,
        coalesce(
            count(DISTINCT CASE WHEN STATUS = 'TXNS' THEN user_ref END), 0
        ) as u107_active_users__retailer_monthly__dcount_uid,
        coalesce(
            count(DISTINCT CASE WHEN STATUS IN ('TXNS', 'REFUND') THEN user_ref END), 0
        ) as u112_active_users_inc_refunds__retailer_monthly__dcount_uid
    from user_events u
    left join dim_date d on d.start_of_month = date_trunc('month', u.date)
    group by d.start_of_month, u.channel, u.brand, u.loyalty_plan_company, u.loyalty_plan_name
),

combine_all as (
    select
        coalesce(s.date, p.date) as date,
        coalesce(s.channel, p.channel) as channel,
        coalesce(s.brand, p.brand) as brand,
        coalesce(
            s.loyalty_plan_company, p.loyalty_plan_company
        ) as loyalty_plan_company,
        coalesce(s.loyalty_plan_name, p.loyalty_plan_name) as loyalty_plan_name,
        coalesce(
            s.u108_active_users_retailer_monthly__cdcount_uid, 0
        ) as u108_active_users_retailer_monthly__cdcount_uid,
        coalesce(
            p.u107_active_users__retailer_monthly__dcount_uid, 0
        ) as u107_active_users__retailer_monthly__dcount_uid,
        coalesce(
            s.u111_active_users_inc_refunds__retailer_monthly__cdcount_uid, 0
        ) as u111_active_users_inc_refunds__retailer_monthly__cdcount_uid,
        coalesce(
            p.u112_active_users_inc_refunds__retailer_monthly__dcount_uid, 0
        ) as u112_active_users_inc_refunds__retailer_monthly__dcount_uid
    from user_snap s
    full outer join
        user_period p
        on
            s.date = p.date
            and s.loyalty_plan_company = p.loyalty_plan_company
            and s.channel = p.channel
            and s.brand = p.brand
)

select *
from combine_all
