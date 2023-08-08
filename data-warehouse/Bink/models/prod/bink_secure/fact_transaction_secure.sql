/*
Created by:         Sam Pibworth
Created date:       2022-04-19
Last modified by:   Sam Pibworth
Last modified date: 2022-06-08

Description:
    Transaction table from the the hermes events.

Parameters:
    ref_object      - transformed_transactions
*/

{{
    config(
		alias='fact_transaction'
        ,materialized='incremental'
		,unique_key='EVENT_ID'
    )
}}

WITH
transaction_events AS (
	SELECT *
	FROM {{ ref('transformed_hermes_events')}}
	WHERE EVENT_TYPE IN ('transaction.exported', 'transaction.duplicate')
	{% if is_incremental() %}
  	AND _AIRBYTE_NORMALIZED_AT>= (SELECT MAX(INSERTED_DATE_TIME) from {{ this }})
	{% endif %}
)

,loyalty_plan AS (
	SELECT *
	FROM {{ ref('stg_hermes__SCHEME_SCHEME')}}
)

,dim_user AS (
	SELECT *
	FROM {{ref('stg_hermes__USER')}}
)

,dim_channel AS (
	SELECT *
	FROM {{ref('stg_hermes__CLIENT_APPLICATION')}}
)

,transaction_events_unpack AS (
	SELECT
		EVENT_ID
		,EVENT_TYPE
		,EVENT_DATE_TIME
		,JSON:internal_user_ref :: VARCHAR AS USER_ID
		,JSON:transaction_id :: VARCHAR AS TRANSACTION_ID
		,JSON:provider_slug :: VARCHAR AS PROVIDER_SLUG
		,JSON:feed_type :: VARCHAR AS FEED_TYPE
		,JSON:transaction_date :: DATETIME AS TRANSACTION_DATE
		,JSON:spend_amount / 100 :: NUMBER(12,2) AS SPEND_AMOUNT
		,JSON:spend_currency :: VARCHAR AS SPEND_CURRENCY
		,JSON:loyalty_id :: VARCHAR AS LOYALTY_ID
		,JSON:scheme_account_id :: VARCHAR AS LOYALTY_CARD_ID
		,JSON:mid :: VARCHAR AS MERCHANT_ID 
		// ,JSON:location_id :: VARCHAR AS LOCATION_ID // Joins to Harmonia merchant data
		// ,JSON:merchant_internal_id :: VARCHAR AS MERCHANT_INTERNAL_ID // Joins to Harmonia merchant data
		,JSON:payment_card_account_id :: VARCHAR AS PAYMENT_ACCOUNT_ID
		,JSON:settlement_key :: VARCHAR AS SETTLEMENT_KEY
		,JSON:authorisation_code :: VARCHAR AS AUTH_CODE
		,JSON:approval_code :: VARCHAR AS APPROVAL_CODE

	FROM transaction_events
)

,select_transactions as (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,t.USER_ID
		,u.EXTERNAL_ID AS EXTERNAL_USER_REF
		,CASE WHEN c.CHANNEL_NAME IN ('Bank of Scotland', 'Lloyds', 'Halifax')  THEN 'LLOYDS'
        	WHEN c.CHANNEL_NAME = 'Barclays Mobile Banking' THEN 'BARCLAYS'
        	WHEN c.CHANNEL_NAME = 'Bink' THEN 'BINK'
        	ELSE NULL
        	END AS CHANNEL
    	,CASE WHEN c.CHANNEL_NAME IN ('Bink', 'Lloyds', 'Halifax') THEN UPPER(c.CHANNEL_NAME)
			WHEN c.CHANNEL_NAME = 'Barclays Mobile Banking' THEN 'BARCLAYS'
			WHEN c.CHANNEL_NAME = 'Bank of Scotland' THEN 'BOS'
			ELSE NULL
			END AS BRAND
		,TRANSACTION_ID
		,PROVIDER_SLUG
		,FEED_TYPE
		,EVENT_TYPE = 'transaction.duplicate' AS DUPLICATE_TRANSACTION
		,lp.LOYALTY_PLAN_NAME
		,lp.LOYALTY_PLAN_COMPANY
		,TRANSACTION_DATE
		,SPEND_AMOUNT
		,SPEND_CURRENCY
		,LOYALTY_ID
		,LOYALTY_CARD_ID
		,MERCHANT_ID
		,PAYMENT_ACCOUNT_ID
		,SETTLEMENT_KEY
		,AUTH_CODE
		,APPROVAL_CODE
		,SYSDATE() AS INSERTED_DATE_TIME
		,SYSDATE() AS UPDATED_DATE_TIME
	FROM
		transaction_events_unpack t
	LEFT JOIN
		loyalty_plan lp ON lp.LOYALTY_PLAN_SLUG = t.PROVIDER_SLUG
	LEFT JOIN
		dim_user u ON u.USER_ID	= t.USER_ID
	LEFT JOIN
		dim_channel c ON u.CHANNEL_ID = c.CHANNEL_ID
)

SELECT
    *
FROM
    select_transactions
