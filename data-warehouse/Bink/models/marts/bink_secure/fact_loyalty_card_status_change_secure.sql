/*
Created by:         Sam Pibworth
Created date:       2022-05-19
Last modified by:   
Last modified date: 

Description:
    Fact table for loyalty card register request / fail / success
	Incremental strategy: loads all newly inserted records, transforms, then loads
	all loyalty card events which require updating, finally calculating is_most_recent
	flag, and merging based on the event id

Parameters:
    ref_object      - transformed_hermes_events
*/

{{
    config(
		alias='fact_loyalty_card_status_change'
    )
}}

/* Add this back in if you want incremental models agaion - roughly 5m rows is when this becomes worth it.
{#
{{
    config(
		alias='fact_loyalty_card_status_change'
        ,materialized='incremental'
		,unique_key='EVENT_ID'
		,merge_update_columns = ['IS_MOST_RECENT', 'UPDATED_DATE_TIME']
    )
}}
#}
*/


WITH
status_change_events AS (
	SELECT *
	FROM {{ ref('transformed_hermes_events')}}
	WHERE EVENT_TYPE = 'lc.statuschange'
	{% if is_incremental() %}
  	AND _AIRBYTE_EMITTED_AT >= (SELECT MAX(INSERTED_DATE_TIME) from {{ this }})
	{% endif %}
)

, account_status_lookup AS (
    SELECT *
    FROM {{ref('stg_lookup__SCHEME_ACCOUNT_STATUS')}}
)

, loyalty_plan AS (
    SELECT * 
    FROM {{ref('stg_hermes__SCHEME_SCHEME')}}
)

,status_change_events_unpack AS (
	SELECT
		EVENT_TYPE
		,EVENT_DATE_TIME
		,EVENT_ID
		,CHANNEL
        ,BRAND
        ,JSON:origin::varchar as ORIGIN
		,JSON:external_user_ref::varchar as EXTERNAL_USER_REF
		,JSON:internal_user_ref::varchar as USER_ID
		,JSON:email::varchar as EMAIL
		,JSON:scheme_account_id::varchar as LOYALTY_CARD_ID
		,JSON:loyalty_plan::varchar as LOYALTY_PLAN_ID
		,JSON:main_answer::varchar as MAIN_ANSWER
		,JSON:to_status::int as TO_STATUS_ID
	FROM status_change_events
)

,status_change_events_add_from_status AS (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,LOYALTY_PLAN_ID
		,MAIN_ANSWER
		,LAG(TO_STATUS_ID, 1) OVER (PARTITION BY LOYALTY_CARD_ID ORDER BY EVENT_DATE_TIME) AS FROM_STATUS_ID
		,TO_STATUS_ID
		,CHANNEL
        ,BRAND
		,ORIGIN
		,USER_ID
		,EXTERNAL_USER_REF
		,EMAIL
	FROM status_change_events_unpack sce
)

,status_change_events_select AS (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,sce.LOYALTY_PLAN_ID
		,lp.LOYALTY_PLAN_NAME
		,FROM_STATUS_ID
		,asl_from.STATUS AS FROM_STATUS
		,asl_from.STATUS_TYPE AS FROM_STATUS_TYPE
		,asl_from.STATUS_ROLLUP AS FROM_STATUS_ROLLUP
		,CASE CHANNEL
			WHEN 'LLOYDS'
			THEN asl_from.API2_STATUS 
			ELSE NULL
			END AS FROM_EXTERNAL_STATUS
		,CASE CHANNEL
			WHEN 'LLOYDS'
			THEN asl_from.API2_ERROR_SLUG
			ELSE NULL
			END AS FROM_ERROR_SLUG
		,TO_STATUS_ID
		,asl_to.STATUS AS TO_STATUS
		,asl_to.STATUS_TYPE AS TO_STATUS_TYPE
		,asl_to.STATUS_ROLLUP AS TO_STATUS_ROLLUP
		,CASE CHANNEL
			WHEN 'LLOYDS'
			THEN asl_to.API2_STATUS 
			ELSE NULL
			END AS TO_EXTERNAL_STATUS
		,CASE CHANNEL
			WHEN 'LLOYDS'
			THEN asl_to.API2_ERROR_SLUG
			ELSE NULL
			END AS TO_ERROR_SLUG
		,NULL AS IS_MOST_RECENT
		,NULLIF(MAIN_ANSWER,'') AS MAIN_ANSWER
		,ORIGIN
		,CHANNEL
        ,BRAND
		,USER_ID
		,EXTERNAL_USER_REF
		,LOWER(EMAIL) AS EMAIL
		,SPLIT_PART(EMAIL,'@',2) AS EMAIL_DOMAIN
		,SYSDATE() AS INSERTED_DATE_TIME
		,NULL AS UPDATED_DATE_TIME
	FROM status_change_events_add_from_status sce
	LEFT JOIN loyalty_plan lp
		ON sce.LOYALTY_PLAN_ID = lp.LOYALTY_PLAN_ID
	LEFT JOIN account_status_lookup asl_to
		ON sce.TO_STATUS_ID = asl_to.CODE
	LEFT JOIN account_status_lookup asl_from 
		ON sce.FROM_STATUS_ID = asl_from.CODE

)

,union_old_lc_records AS (
	SELECT *
	FROM status_change_events_select
	{% if is_incremental() %}
	UNION
	SELECT *
	FROM {{ this }}
	WHERE LOYALTY_CARD_ID IN (
		SELECT LOYALTY_CARD_ID
		FROM status_change_events_select
	)
	{% endif %}
)

,alter_is_most_recent_flag AS (
	SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,LOYALTY_PLAN_ID
		,LOYALTY_PLAN_NAME
		,FROM_STATUS_ID
		,FROM_STATUS
		,FROM_STATUS_TYPE
		,FROM_STATUS_ROLLUP
		,FROM_EXTERNAL_STATUS
		,FROM_ERROR_SLUG
		,TO_STATUS_ID
		,TO_STATUS
		,TO_STATUS_TYPE
		,TO_STATUS_ROLLUP
		,TO_EXTERNAL_STATUS
		,TO_ERROR_SLUG
		,CASE WHEN
			(EVENT_DATE_TIME = MAX(EVENT_DATE_TIME) OVER (PARTITION BY LOYALTY_CARD_ID))
			THEN TRUE
			ELSE FALSE
			END AS IS_MOST_RECENT
		,MAIN_ANSWER
		,ORIGIN
		,CHANNEL
        ,BRAND
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