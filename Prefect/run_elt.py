from prefect import Flow, task, Parameter
from prefect.tasks.dbt import DbtShellTask
from prefect.tasks.airbyte.airbyte import AirbyteConnectionTask
from prefect.run_configs import DockerRun
from prefect.storage import Docker
from prefect.schedules import Schedule, clocks
import os

DBT_DIRECTORY = 'Bink'
DBT_PROFILE = 'Bink'
AIRBYTE_EVENTS_CONNECTION_ID='62d2288c-11b2-4a5c-bbc1-4f0db35a9a93'
AIRBYTE_HERMES_CONNECTION_ID='aa27ccee-6641-4de6-982a-37daf0700c16'

param_run_tests = os.getenv('run_tests')

def make_airbyte_task(name, connection_id):
    return AirbyteConnectionTask(
            airbyte_server_host='51.132.44.255'
            ,connection_id=connection_id
            ,name=name
        )


def make_dbt_task(command, name):
    return DbtShellTask(
        command=command
        ,name=name
        ,profiles_dir='.'
        ,profile_name=DBT_PROFILE
        ,environment='dev'
        ,helper_script='cd dbt' ##  refers to the dbt dir within the docker image
        ,return_all=True
        ,log_stderr=True
    )

dbt_deps_task = make_dbt_task('dbt deps', 'DBT Dependencies')
dbt_run_task = make_dbt_task('dbt run', 'DBT Run')
dbt_src_test_task = make_dbt_task('dbt test --select tag:source', 'DBT Source Tests')
dbt_outp_test_task = make_dbt_task('dbt test --exclude tag:source', 'DBT Output Tests')

docker_storage = Docker(
    image_name="box_elt_flow_image"
    ,files={ ## dictionary of local-path:docker-image-path items
        f'{os.getcwd()}/../{DBT_DIRECTORY}':'/dbt'
        ,f'{os.getcwd()}/profiles.yml':'/dbt/profiles.yml'
    }
    ,python_dependencies=['dbt-snowflake'] ## List all pip packages here
    )

schedule = Schedule(clocks=[clocks.CronClock("0 7 * * *")]) ## Runs at 7:00 every day

with Flow(
        name="Bink ELT"
        ,run_config=DockerRun()
        ,storage=docker_storage
        ,schedule=schedule
        ) as flow:

        airbyte_sync_events = make_airbyte_task('Sync Events',AIRBYTE_EVENTS_CONNECTION_ID)

        airbyte_sync_hermes = make_airbyte_task('Sync Hermes',AIRBYTE_HERMES_CONNECTION_ID)

        dbt_deps = dbt_deps_task(
            upstream_tasks=[airbyte_sync_events, airbyte_sync_hermes]
        )

        dbt_src_test = dbt_src_test_task(
            upstream_tasks=[dbt_deps]
        )

        dbt_run = dbt_run_task(
            upstream_tasks=[dbt_src_test]
        )

        dbt_outp_test = dbt_outp_test_task(
            upstream_tasks=[dbt_run]
        )