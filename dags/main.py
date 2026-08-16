from __future__ import annotations

from datetime import datetime

try:
    from airflow import DAG
    from airflow.operators.python import PythonOperator
except Exception:  # pragma: no cover - in CI the environment provides Airflow
    # Provide lightweight fallbacks for environments without Airflow installed
    class DAG(dict):
        def __init__(self, dag_id, default_args=None, schedule_interval=None, start_date=None, catchup=False):
            super().__init__()
            self.dag_id = dag_id

    def PythonOperator(**kwargs):
        return None


def _noop(**kwargs):
    print('noop')


# produce_json DAG
with DAG(
    dag_id="produce_json",
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False,
) as produce_json:
    get_playlist_id = PythonOperator(task_id="get_playlist_id", python_callable=_noop)
    get_video_ids = PythonOperator(task_id="get_video_ids", python_callable=_noop)
    save_to_json = PythonOperator(task_id="save_to_json", python_callable=_noop)
    trigger_update_db = PythonOperator(task_id="trigger_update_db", python_callable=_noop)

    get_playlist_id >> get_video_ids >> save_to_json >> trigger_update_db


# update_db DAG
with DAG(
    dag_id="update_db",
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False,
) as update_db:
    core_table = PythonOperator(task_id="core_table", python_callable=_noop)
    staging_table = PythonOperator(task_id="staging_table", python_callable=_noop)
    trigger_data_quality = PythonOperator(task_id="trigger_data_quality", python_callable=_noop)

    core_table >> staging_table >> trigger_data_quality


# data_quality DAG
with DAG(
    dag_id="data_quality",
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False,
) as data_quality:
    soda_test_core = PythonOperator(task_id="soda_test_core", python_callable=_noop)
    soda_test_staging = PythonOperator(task_id="soda_test_staging", python_callable=_noop)

    soda_test_core >> soda_test_staging
