/*
Created by:         Anand Bhakta
Created date:       2023-06-27
Last modified by:   
Last modified date: 

Description:
    Datasource to produce lloyds mi dashboard - loyalty_cards_error_funnel
Parameters:
    source_object       - LC201__LOYALTY_CARD_JOURNEY_FUNNEL__USER_LEVEL__UID
*/

SELECT * 
FROM  {{ref('LC201__LOYALTY_CARD_JOURNEY_FUNNEL__USER_LEVEL__UID')}}
WHERE CHANNEL = 'LLOYDS'
