/*
Created by:         Anand Bhakta
Created date:       2023-02-02
Last modified by:   Christopher Mitchell
Last modified date: 202402-05

Description:
    Stages the freshservice table

Parameters:
    source_object      - SERVICE_DATA.FRESHSERVICE
*/

{{ config(materialized="incremental", unique_key="ID") }}

with
all_data as (
    select *
    from {{ ref("stg_service_data__FRESHSERVICE") }}
    {% if is_incremental() %}
        where
            _airbyte_emitted_at
            >= (select max(inserted_date_time) from {{ this }})
    {% endif %}
),

add_most_recent as (
    select
        id,
        ticket_id,
        mi,
        status,
        case
        channel
            when 'Barclays'
                then 'BARCLAYS'
            when 'LBG'
                then 'LLOYDS'
            else channel
        end as channel,
        service,
        created_at,
        updated_at,
        sla_breached,
        case
            when (updated_at = max(updated_at) over (partition by ticket_id))
                then true
            else false
        end as is_most_recent,
        _airbyte_emitted_at,
        sysdate() as inserted_date_time
    from all_data
)

select *
from add_most_recent
