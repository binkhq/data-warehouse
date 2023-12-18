/*
Created by:         Anand Bhakta
Created date:       2023-09-25
Last modified by:
Last modified date:

Description:
    Convert the trans__trans__monthly_retailer table to growth metrics.
Parameters:
    source_object       - trans__trans__monthly_retailer
*/

{{convert_to_growth("trans__trans__monthly_retailer_channel",
                    ["DATE", "LOYALTY_PLAN_NAME", "LOYALTY_PLAN_COMPANY","CHANNEL"],
                    ["BRAND"],
                    ["LOYALTY_PLAN_NAME", "LOYALTY_PLAN_COMPANY","CHANNEL"],
                    "DATE" )
}}
