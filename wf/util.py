import os
from typing import Any, Dict

import requests


def message(typ: str, data: Dict[str, Any]) -> None:
    return
    try:
        task_project = os.environ["FLYTE_INTERNAL_TASK_PROJECT"]
        task_domain = os.environ["FLYTE_INTERNAL_TASK_DOMAIN"]
        task_name = os.environ["FLYTE_INTERNAL_TASK_NAME"]
        task_version = os.environ["FLYTE_INTERNAL_TASK_VERSION"]
        task_attempt_number = os.environ["FLYTE_ATTEMPT_NUMBER"]
        execution_token = os.environ["FLYTE_INTERNAL_EXECUTION_ID"]
    except KeyError:
        print(f"Local execution message:\n[{typ}]: {data}")
        return

    response = requests.post(
        url="https://nucleus.latch.bio/sdk/add-task-execution-message",
        json={
            "execution_token": execution_token,
            "task": {
                "project": task_project,
                "domain": task_domain,
                "name": task_name,
                "version": task_version,
            },
            "task_attempt_number": task_attempt_number,
            "type": typ,
            "data": data,
        },
    )

    if response.status_code != 200:
        raise RuntimeError("Could not add task execution message to Latch.")


def info(data: Dict[str, Any]):
    message("info", data)


def warning(data: Dict[str, Any]):
    message("warning", data)


def error(data: Dict[str, Any]):
    message("error", data)


def warn(*args, **kwargs):
    print("", "!>>> Warning", sep="\n")
    print(*args, **kwargs)
    print("!>>>", "", sep="\n")
