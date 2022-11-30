/*
Created by:         Sam Pibworth
Created date:       2022-05-19
Last modified by:   
Last modified date: 

Description:
    Fact table for loyalty join request / fail / success
	Incremental strategy: loads all newly inserted records, transforms, then loads
	all loyalty card events which require updating, finally calculating is_most_recent
	flag, and merging based on the event id

Parameters:
    ref_object      - transformed_hermes_events
*/

{{
    config(
		alias='fact_loyalty_card_join'
        ,materialized='incremental'
		,unique_key='EVENT_ID'
		,merge_update_columns = ['IS_MOST_RECENT', 'UPDATED_DATE_TIME']
    )
}}

WITH
join_events AS (
	SELECT *
	FROM {{ ref('transformed_hermes_events')}}
	WHERE EVENT_TYPE like 'lc.join%'
	{% if is_incremental() %}
  	AND _AIRBYTE_EMITTED_AT >= (SELECT MAX(INSERTED_DATE_TIME) from {{ this }})
	{% endif %}
)

,join_events_unpack AS (
	SELECT
		EVENT_ID
		,EVENT_TYPE
		,EVENT_DATE_TIME
		,JSON:origin::varchar as ORIGIN
		,JSON:channel::varchar as CHANNEL
		,JSON:external_user_ref::varchar as EXTERNAL_USER_REF
		,JSON:internal_user_ref::varchar as USER_ID
		,JSON:email::varchar as EMAIL
		,JSON:scheme_account_id::varchar as LOYALTY_CARD_ID
		,JSON:loyalty_plan::varchar as LOYALTY_PLAN
		,JSON:main_answer::varchar as MAIN_ANSWER
		,JSON:status::int as STATUS
	FROM join_events
)

,join_events_select AS (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,LOYALTY_PLAN
		,CASE WHEN EVENT_TYPE = 'lc.join.request'
			THEN 'REQUEST'
			WHEN EVENT_TYPE = 'lc.join.success'
			THEN 'SUCCESS'
			WHEN EVENT_TYPE = 'lc.join.failed'
			THEN 'FAILED'
			ELSE NULL
			END AS EVENT_TYPE
		,NULL AS IS_MOST_RECENT
		,CASE WHEN MAIN_ANSWER = '' // Unique identifier for schema account record - this is empty???
			THEN NULL
			ELSE MAIN_ANSWER
			END AS MAIN_ANSWER
		,STATUS
		,CHANNEL
		,ORIGIN
		,USER_ID
		,EXTERNAL_USER_REF
		,LOWER(EMAIL) AS EMAIL
		,SPLIT_PART(EMAIL,'@',2) AS EMAIL_DOMAIN
		,SYSDATE() AS INSERTED_DATE_TIME
		,NULL AS UPDATED_DATE_TIME
	FROM join_events_unpack
	ORDER BY EVENT_DATE_TIME DESC
)

,union_old_lc_records AS (
	SELECT *
	FROM join_events_select
	{% if is_incremental() %}
	UNION
	SELECT *
	FROM {{ this }}
	WHERE LOYALTY_CARD_ID IN (
		SELECT LOYALTY_CARD_ID
		FROM join_events_select
	)
	{% endif %}
)

,alter_is_most_recent_flag AS (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,LOYALTY_PLAN
		,EVENT_TYPE
		,CASE WHEN
			(EVENT_DATE_TIME = MAX(EVENT_DATE_TIME) OVER (PARTITION BY LOYALTY_CARD_ID))
			THEN TRUE
			ELSE FALSE
			END AS IS_MOST_RECENT
		,MAIN_ANSWER
		,STATUS
		,CHANNEL
		,ORIGIN
		,USER_ID
		,EXTERNAL_USER_REF
		,EMAIL
		,EMAIL_DOMAIN
		,INSERTED_DATE_TIME
		,SYSDATE() AS UPDATED_DATE_TIME
	FROM
		union_old_lc_records
)

SELECT
	*
FROM
	alter_is_most_recent_flag
	