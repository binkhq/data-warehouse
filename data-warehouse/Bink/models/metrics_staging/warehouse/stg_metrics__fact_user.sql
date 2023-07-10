WITH source AS (
    SELECT * 
    FROM {{ ref('fact_user_secure') }}
    WHERE EVENT_TYPE iS NOT NULL
)

,renamed AS (
    SELECT
        EVENT_ID
        ,EVENT_DATE_TIME
        ,USER_ID
        ,EXTERNAL_USER_REF
        ,EVENT_TYPE
        ,IS_MOST_RECENT
        ,ORIGIN
        ,CHANNEL
        ,BRAND
        ,INSERTED_DATE_TIME
        ,UPDATED_DATE_TIME
    FROM source
)

SELECT *
FROM renamed
