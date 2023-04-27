from prefect import flow, task
from prefect.blocks.system import Secret, String
from prefect_dbt.cli.commands import trigger_dbt_cli_command
from prefect_dbt.cli.configs import SnowflakeTargetConfigs
from prefect_dbt.cli.credentials import DbtCliProfile
from prefect_snowflake.credentials import SnowflakeCredentials
from prefect_snowflake.database import SnowflakeConnector


@task
def get_dbt_cli_profile(env):
    dbt_connector = SnowflakeConnector(
        schema="BINK",
        database={"dev": "DEV", "prod": "BINK"}[env],
        warehouse="ENGINEERING",
        credentials=SnowflakeCredentials.load("snowflake-transform-user"),
    )
    dbt_cli_profile = DbtCliProfile(
        name="Bink",
        target="target",
        target_configs=SnowflakeTargetConfigs(connector=dbt_connector),
    )
    return dbt_cli_profile


def dbt_cli_task(dbt_cli_profile, command):
    return trigger_dbt_cli_command(
        command=command,
        overwrite_profiles=True,
        profiles_dir="/app/data-warehouse/Prefect",
        project_dir="/app/data-warehouse/Bink",
        dbt_cli_profile=dbt_cli_profile,
    )


@flow(name="Full_Refresh_Flow")
def run(
    env: str,
    is_run_transformations: bool = True,
    is_run_output_tests: bool = True,
):
    dbt_cli_profile = get_dbt_cli_profile(env)
    dbt_cli_task(dbt_cli_profile, "dbt deps")
    if is_run_transformations:
        dbt_cli_task(dbt_cli_profile, "dbt run --full-refresh")
    if is_run_output_tests:
        dbt_cli_task(dbt_cli_profile, 'dbt test --exclude tag:"source" tag:"business"')
        dbt_cli_task(dbt_cli_profile, "dbt test --select tag:business")
