/*
 Test to ensure all lc are not ending with error states
 
 Created By:     SP
 Created Date:   2022/07/1
 */


{{ config(tags = ['business']) }}

with lc_errors as (
    SELECT
        LOYALTY_CARD_ID
    FROM {{ref('fact_loyalty_card_status_change')}}
    WHERE
        IS_MOST_RECENT = true
        AND TO_STATUS_ID not in (0,1)
        AND TIMEDIFF(
                hour, EVENT_DATE_TIME, (
                    SELECT max(EVENT_DATE_TIME)
                    FROM {{ref('fact_loyalty_card_status_change')}}
                    )
                ) < 24
    )
  
,previously_valid as (
    SELECT
        LOYALTY_CARD_ID
    FROM
        {{ref('fact_loyalty_card_status_change')}}
    WHERE
        LOYALTY_CARD_ID IN (SELECT LOYALTY_CARD_ID FROM LC_ERRORS)
        AND TO_STATUS_ID IN (1)
    GROUP BY
        LOYALTY_CARD_ID

)

select * from previously_valid
