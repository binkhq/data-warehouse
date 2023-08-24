/*
Created by:         Christopher Mitchell
Created date:       2023-06-07
Last modified by:   Christopher Mitchell
Last modified date: 2023-08-24

Description:
    User Transaction Metrics monthly by retailer
Parameters:
    source_object       - txns_trans
                        - stg_metrics__dim_date
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
        u.loyalty_plan_company,
        u.loyalty_plan_name,
        count(
            distinct user_ref
        ) as u108_active_users_brand_retailer_monthly__cdcount_uid
    from user_events u
    left join dim_date d on date(u.date) <= d.end_of_month
    group by d.start_of_month, u.loyalty_plan_company, u.loyalty_plan_name
),

user_period as (
    select
        d.start_of_month as date,
        u.loyalty_plan_company,
        u.loyalty_plan_name,
        coalesce(
            count(distinct user_ref), 0
        ) as u107_active_users_brand_retailer_monthly__dcount_uid
    from user_events u
    left join dim_date d on d.start_of_month = date_trunc('month', u.date)
    group by d.start_of_month, u.loyalty_plan_company, u.loyalty_plan_name
),

combine_all as (
    select
        coalesce(s.date, p.date) as date,
        coalesce(
            s.loyalty_plan_company, p.loyalty_plan_company
        ) as loyalty_plan_company,
        coalesce(s.loyalty_plan_name, p.loyalty_plan_name) as loyalty_plan_name,
        coalesce(
            s.u108_active_users_brand_retailer_monthly__cdcount_uid, 0
        ) as u108_active_users_brand_retailer_monthly__cdcount_uid,
        coalesce(
            p.u107_active_users_brand_retailer_monthly__dcount_uid, 0
        ) as u107_active_users_brand_retailer_monthly__dcount_uid
    from user_snap s
    full outer join
        user_period p
        on
            s.date = p.date
            and s.loyalty_plan_company = p.loyalty_plan_company
)

select *
from combine_all
