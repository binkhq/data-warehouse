/*
Created by:         Sam Pibworth
Created date:       2022-05-04
Last modified by:   
Last modified date: 

Description:
    extracts payment_account added and payment_account removed from the events table

Parameters:
    ref_object      - stg_hermes__events
*/


WITH

payment_events AS (
	SELECT *
	FROM {{ ref('stg_hermes__EVENTS')}}
	WHERE EVENT_TYPE IN ('payment.account.added', 'payment.account.removed')
)

,payment_events_unpack AS (
	SELECT
		EVENT_TYPE
		,EVENT_DATE_TIME
		,JSON:origin::varchar as ORIGIN
		,JSON:channel::varchar as CHANNEL
		,JSON:external_user_ref::varchar as EXTERNAL_USER_REF
		,JSON:internal_user_ref::varchar as USER_ID
		,JSON:email::varchar as EMAIL
		,JSON:payment_account_id::varchar as PAYMENT_ACCOUNT_ID
		,JSON:expiry_date::varchar as EXPIRARY_DATE
		,JSON:token::varchar as TOKEN
		,JSON:status::integer as STATUS

	FROM payment_events
)

,payment_events_select AS (
	SELECT
		PAYMENT_ACCOUNT_ID
		,CASE WHEN EVENT_TYPE = 'payment.account.added'
			THEN 'ADDED'
			WHEN EVENT_TYPE = 'payment.account.removed'
			THEN 'REMOVED'
			ELSE NULL
			END AS EVENT_TYPE
		,EVENT_DATE_TIME
		,CASE WHEN
			(EVENT_DATE_TIME = MAX(EVENT_DATE_TIME) OVER (PARTITION BY USER_ID))
			THEN TRUE
			ELSE FALSE
			END AS IS_MOST_RECENT
		,ORIGIN
		,CHANNEL
		,USER_ID
		,EXTERNAL_USER_REF
		,SPLIT_PART(EXPIRARY_DATE,'/',1)::integer AS EXPIRARY_MONTH
		,CASE WHEN SPLIT_PART(EXPIRARY_DATE,'/',2)::integer >= 2000
			THEN SPLIT_PART(EXPIRARY_DATE,'/',2)::integer
			ELSE SPLIT_PART(EXPIRARY_DATE,'/',2)::integer + 2000
			END AS EXPIRARY_YEAR
		,TOKEN
		,STATUS
		,LOWER(EMAIL) AS EMAIL
		,SPLIT_PART(EMAIL,'@',2) AS DOMAIN
	FROM payment_events_unpack
)



SELECT
	*
FROM
	payment_events_select
	