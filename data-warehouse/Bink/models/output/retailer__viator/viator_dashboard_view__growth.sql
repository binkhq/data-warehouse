/*
Created by:         Christopher Mitchell
Created date:       2023-07-05
Last modified by:   Christopher Mitchell
Last modified date: 2024-01-15

Description:
    Datasource to produce tableau dashboard for Viator
Parameters:
    source_object       - lc__links_joins__monthly_retailer
                        - trans__trans__monthly_retailer
                        - trans__avg__monthly_retailer
                        - user__transactions__monthly_retailer
                        - voucher__counts__monthly_retailer
*/

with lc_metric as (
    select
        *,
        'JOINS' as category
    from {{ ref('lc__links_joins__monthly_retailer__growth') }}
    where loyalty_plan_company = 'Viator'
),

txn_metrics as (
    select
        *,
        'SPEND' as category
    from {{ ref('trans__trans__monthly_retailer__growth') }}
    where loyalty_plan_company = 'Viator'
),

txn_avg as (
    select
        *,
        'SPEND' as category
    from {{ ref('trans__avg__monthly_retailer__growth') }}
    where loyalty_plan_company = 'Viator'
),

user_metrics as (
    select
        *,
        'USERS' as category
    from {{ ref('user__transactions__monthly_retailer__growth') }}
    where loyalty_plan_company = 'Viator'
),

voucher_metrics as (
    select
        *,
        'VOUCHERS' as category
    from {{ ref('voucher__counts__monthly_retailer__growth') }}
    where loyalty_plan_company = 'Viator'
),

combine_all as (
    select
        date,
        category,
        loyalty_plan_name,
        loyalty_plan_company,
        lc379__successful_loyalty_card_joins__monthly_retailer__csum__growth,
        lc347__successful_loyalty_card_joins__monthly_retailer__count__growth,
        lc333__successful_loyalty_card_join_mrkt_opt_in__monthly_retailer__count__growth,
        lc335__successful_loyalty_cards__monthly_retailer__pit__growth,
        null as t012__refund__monthly_retailer__dcount__growth,
        null as t011__txns__monthly_retailer__dcount__growth,
        null as t009__spend__monthly_retailer__sum__growth,
        null as t014__aov__monthly_retailer__avg__growth,
        null as t016__atf__monthly_retailer__avg__growth,
        null as t015__arpu__monthly_retailer__avg__growth,
        null as u107_active_users__retailer_monthly__dcount_uid__growth,
        null as u108_active_users_retailer_monthly__cdcount_uid__growth,
        null as v012__issued_vouchers__monthly_retailer__dcount__growth,
        null as v009__issued_vouchers__monthly_retailer__cdsum_voucher__growth,
        null as v013__redeemed_vouchers__monthly_retailer__dcount__growth,
        null as v010__redeemed_vouchers__monthly_retailer__cdsum_voucher__growth
    from lc_metric
    union all
    select
        date,
        category,
        loyalty_plan_name,
        loyalty_plan_company,
        null as lc379__successful_loyalty_card_joins__monthly_retailer__csum__growth,
        null as lc347__successful_loyalty_card_joins__monthly_retailer__count__growth,
        null as lc333__successful_loyalty_card_join_mrkt_opt_in__monthly_retailer__count__growth,
        null as lc335__successful_loyalty_cards__monthly_retailer__pit__growth,
        t012__refund__monthly_retailer__dcount__growth,
        t011__txns__monthly_retailer__dcount__growth,
        t009__spend__monthly_retailer__sum__growth,
        null as t014__aov__monthly_retailer__avg__growth,
        null as t016__atf__monthly_retailer__avg__growth,
        null as t015__arpu__monthly_retailer__avg__growth,
        null as u107_active_users__retailer_monthly__dcount_uid__growth,
        null as u108_active_users_retailer_monthly__cdcount_uid__growth,
        null as v012__issued_vouchers__monthly_retailer__dcount__growth,
        null as v009__issued_vouchers__monthly_retailer__cdsum_voucher__growth,
        null as v013__redeemed_vouchers__monthly_retailer__dcount__growth,
        null as v010__redeemed_vouchers__monthly_retailer__cdsum_voucher__growth
    from txn_metrics
    union all
    select
        date,
        category,
        loyalty_plan_name,
        loyalty_plan_company,
        null as lc379__successful_loyalty_card_joins__monthly_retailer__csum__growth,
        null as lc347__successful_loyalty_card_joins__monthly_retailer__count__growth,
        null as lc333__successful_loyalty_card_join_mrkt_opt_in__monthly_retailer__count__growth,
        null as lc335__successful_loyalty_cards__monthly_retailer__pit__growth,
        null as t012__refund__monthly_retailer__dcount__growth,
        null as t011__txns__monthly_retailer__dcount__growth,
        null as t009__spend__monthly_retailer__sum__growth,
        t014__aov__monthly_retailer__avg__growth,
        t016__atf__monthly_retailer__avg__growth,
        t015__arpu__monthly_retailer__avg__growth,
        null as u107_active_users__retailer_monthly__dcount_uid__growth,
        null as u108_active_users_retailer_monthly__cdcount_uid__growth,
        null as v012__issued_vouchers__monthly_retailer__dcount__growth,
        null as v009__issued_vouchers__monthly_retailer__cdsum_voucher__growth,
        null as v013__redeemed_vouchers__monthly_retailer__dcount__growth,
        null as v010__redeemed_vouchers__monthly_retailer__cdsum_voucher__growth
    from txn_avg
    union all
    select
        date,
        category,
        loyalty_plan_name,
        loyalty_plan_company,
        null as lc379__successful_loyalty_card_joins__monthly_retailer__csum__growth,
        null as lc347__successful_loyalty_card_joins__monthly_retailer__count__growth,
        null as lc333__successful_loyalty_card_join_mrkt_opt_in__monthly_retailer__count__growth,
        null as lc335__successful_loyalty_cards__monthly_retailer__pit__growth,
        null as t012__refund__monthly_retailer__dcount__growth,
        null as t011__txns__monthly_retailer__dcount__growth,
        null as t009__spend__monthly_retailer__sum__growth,
        null as t014__aov__monthly_retailer__avg__growth,
        null as t016__atf__monthly_retailer__avg__growth,
        null as t015__arpu__monthly_retailer__avg__growth,
        u107_active_users__retailer_monthly__dcount_uid__growth,
        u108_active_users_retailer_monthly__cdcount_uid__growth,
        null as v012__issued_vouchers__monthly_retailer__dcount__growth,
        null as v009__issued_vouchers__monthly_retailer__cdsum_voucher__growth,
        null as v013__redeemed_vouchers__monthly_retailer__dcount__growth,
        null as v010__redeemed_vouchers__monthly_retailer__cdsum_voucher__growth
    from user_metrics
    union all
    select
        date,
        category,
        loyalty_plan_name,
        loyalty_plan_company,
        null as lc379__successful_loyalty_card_joins__monthly_retailer__csum__growth,
        null as lc347__successful_loyalty_card_joins__monthly_retailer__count__growth,
        null as lc333__successful_loyalty_card_join_mrkt_opt_in__monthly_retailer__count__growth,
        null as lc335__successful_loyalty_cards__monthly_retailer__pit__growth,
        null as t012__refund__monthly_retailer__dcount__growth,
        null as t011__txns__monthly_retailer__dcount__growth,
        null as t009__spend__monthly_retailer__sum__growth,
        null as t014__aov__monthly_retailer__avg__growth,
        null as t016__atf__monthly_retailer__avg__growth,
        null as t015__arpu__monthly_retailer__avg__growth,
        null as u107_active_users__retailer_monthly__dcount_uid__growth,
        null as u108_active_users_retailer_monthly__cdcount_uid__growth,
        v012__issued_vouchers__monthly_retailer__dcount__growth,
        v009__issued_vouchers__monthly_retailer__cdsum_voucher__growth,
        v013__redeemed_vouchers__monthly_retailer__dcount__growth,
        v010__redeemed_vouchers__monthly_retailer__cdsum_voucher__growth
    from voucher_metrics
)

select *
from combine_all
