/*
Created by:         Sam Pibworth
Created date:       2022-06-15
Last modified by:   
Last modified date: 

Description:
	Fact payment account status change with reduced columns

Parameters:
    ref_object      - fact_payment_account_status_change_secure
*/

WITH
pa AS (
    SELECT * 
    FROM {{ref('fact_payment_account_status_change_secure')}}
)

,pa_select AS (
    SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,PAYMENT_ACCOUNT_ID
		,ORIGIN
		,CHANNEL
		,USER_ID
		,EXTERNAL_USER_REF
		// ,EXPIRY_DATE
		,TOKEN
		,FROM_STATUS_ID
		,FROM_STATUS
		,TO_STATUS_ID
		,TO_STATUS
		// ,EMAIL
    FROM
        pa
)


SELECT *
FROM pa_select