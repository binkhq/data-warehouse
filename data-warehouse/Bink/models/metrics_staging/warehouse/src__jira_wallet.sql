with source as (
    select * from {{ source('JIRA', 'WALLET') }}
),

renamed as (
    select
        name,
        goal,
        start_date,
        end_date,
        ticket_total,
        ticket_carry_over_count,
        user_story_count,
        investigation_count,
        bug_count,
        defect_count,
        tickets_accepted_in_sprint,
        story_points_in_sprint_goal,
        story_points_carried_over,
        defects_in_sprint,
        api_banking_release,
        api_consumer_release,
        tech_tickets,
        security_tickets,
        devops_tickets,
        misc_technical_tickets,
        product_tickets,
        bau_product,
        project
    from source
)

select * from renamed
