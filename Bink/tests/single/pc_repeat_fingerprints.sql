/*
 Test to ensure no duplicate transaction ids that are not net zero spends - i.e refunds
 
 Created By:     SP
 Created Date:   2022/07/19
 */


{{ config(tags = ['business']) }}

WITH new_pa AS (
    SELECT *
    FROM {{ref('fact_payment_account')}}
    WHERE EVENT_TYPE = 'ADDED'
    AND TIMEDIFF(
                        HOUR, EVENT_DATE_TIME, (
                            SELECT MAX(EVENT_DATE_TIME)
                            FROM {{ref('fact_payment_account')}}
                            )
                        ) < 24
)

,fingerprints AS (
    SELECT
        pa.USER_ID
        ,COUNT( DISTINCT dpa.FINGERPRINT) AS DISTINCT_FINGERPRINTS
        ,COUNT( dpa.FINGERPRINT) AS FINGERPRINTS
    FROM new_pa pa
    LEFT JOIN {{ref('dim_payment_account_secure')}} dpa
        ON pa.PAYMENT_ACCOUNT_ID=dpa.PAYMENT_ACCOUNT_ID
    GROUP BY
        USER_ID
)

SELECT *
FROM fingerprints
WHERE DISTINCT_FINGERPRINTS != FINGERPRINTS
