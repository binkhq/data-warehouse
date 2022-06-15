/*
Created by:         Sam Pibworth
Created date:       2022-06-15
Last modified by:   
Last modified date: 

Description:
	Fact LC removed with reduced columns

Parameters:
    ref_object      - fact_loyalty_card_removed_secure
*/

WITH
lc AS (
    SELECT * 
    FROM {{ref('fact_loyalty_card_removed_secure')}}
)

,lc_select AS (
    SELECT
		EVENT_ID
		,EVENT_DATE_TIME
		,LOYALTY_CARD_ID
		,LOYALTY_PLAN
		// ,MAIN_ANSWER
		,CHANNEL
		,ORIGIN
		,USER_ID
		,EXTERNAL_USER_REF
		// ,EMAIL
		,EMAIL_DOMAIN
		,INSERTED_DATE_TIME
    FROM
        lc
)


SELECT *
FROM lc_select