import json
import os
import subprocess
import time
from textwrap import dedent

import boto3
import pytest
from botocore.exceptions import ClientError

PROJECT = os.environ["PROJECT"]
VERSION = os.environ["VERSION"]
FLYTE_ADMIN_ENDPOINT = os.environ["FLYTE_ADMIN_ENDPOINT"]
FLYTE_CLIENT_ID = os.environ["FLYTE_CLIENT_ID"]
FLYTE_SECRET_PATH = os.environ["FLYTE_SECRET_PATH"]
DOMAIN = "development"

s3_client = boto3.resource("s3")

managed_buckets = {
    "admin.lyte.latch.bio:81": "prod-ldata-managed",
}


@pytest.fixture
def bucket():
    return managed_buckets[FLYTE_ADMIN_ENDPOINT]


@pytest.fixture
def inputs():
    return [
        ".test/wf-core-deseq2/counts.csv",
        ".test/wf-core-deseq2/design.csv",
    ]


@pytest.fixture
def outputs(bucket):
    return [
        ".test/wf-core-deseq2/output/Report.deseqreport",
        ".test/wf-core-deseq2/output/Data/dds.rds",
    ]


def _s3_obj_exists(bucket_name: str, res_path: str) -> bool:
    obj = s3_client.Object(bucket_name, res_path)
    try:
        obj.load()
        return True
    except ClientError as e:
        return False


def _rm_s3_obj(bucket_name: str, res_path: str):
    s3_client.Object(bucket_name, res_path).delete()


def test_wf(bucket, inputs, outputs, capsys):

    try:
        for inpt in inputs:
            assert _s3_obj_exists(bucket, inpt) is True, "Inputs do not exist."
        for output in outputs:
            if _s3_obj_exists(bucket, output) is True:
                _rm_s3_obj(bucket, output)

        _execution_file = json.dumps(
            {
                "inputs": {
                    "conditions_source": "table",
                    "conditions_table": {
                        "__proto": {
                            "scalar": {
                                "union": {
                                    "type": {
                                        "annotation": {
                                            "annotations": {
                                                "_tmp_hack_deseq2": "design_matrix",
                                                "rules": [
                                                    {
                                                        "message": (
                                                            "Expected a CSV, TSV, or"
                                                            " XLSX file"
                                                        ),
                                                        "regex": ".*\\.(csv|tsv|xlsx)$",
                                                    }
                                                ],
                                            }
                                        },
                                        "blob": {},
                                        "structure": {"tag": "FlyteFilePath"},
                                    },
                                    "value": {
                                        "scalar": {
                                            "blob": {
                                                "metadata": {"type": {}},
                                                "uri": f"s3://{bucket}/{inputs[1]}",
                                            }
                                        }
                                    },
                                }
                            }
                        }
                    },
                    "count_table_gene_id_column": "gene_id",
                    "count_table_source": "single",
                    "design_formula": [
                        ["Condition", "explanatory"],
                    ],
                    "design_matrix_sample_id_column": {
                        "__proto": {
                            "scalar": {
                                "union": {
                                    "type": {
                                        "annotation": {
                                            "annotations": {
                                                "_tmp_hack_deseq2": "design_id_column"
                                            }
                                        },
                                        "simple": "STRING",
                                        "structure": {"tag": "str"},
                                    },
                                    "value": {
                                        "scalar": {
                                            "primitive": {"stringValue": "Sample"}
                                        }
                                    },
                                }
                            }
                        }
                    },
                    "output_location": {
                        "__proto": {
                            "scalar": {
                                "union": {
                                    "type": {
                                        "blob": {"dimensionality": "MULTIPART"},
                                        "structure": {"tag": "FlyteDirectory"},
                                    },
                                    "value": {
                                        "scalar": {
                                            "blob": {
                                                "metadata": {"type": {}},
                                                "uri": f"s3://{bucket}/{'/'.join(inputs[0].split('/')[:-1])}/output",
                                            }
                                        }
                                    },
                                }
                            }
                        }
                    },
                    "output_location_type": "custom",
                    "raw_count_table": {
                        "__proto": {
                            "scalar": {
                                "union": {
                                    "type": {
                                        "annotation": {
                                            "annotations": {
                                                "_tmp_hack_deseq2": "design_matrix",
                                                "rules": [
                                                    {
                                                        "message": (
                                                            "Expected a CSV, TSV, or"
                                                            " XLSX file"
                                                        ),
                                                        "regex": ".*\\.(csv|tsv|xlsx)$",
                                                    }
                                                ],
                                            }
                                        },
                                        "blob": {},
                                        "structure": {"tag": "FlyteFilePath"},
                                    },
                                    "value": {
                                        "scalar": {
                                            "blob": {
                                                "metadata": {"type": {}},
                                                "uri": f"s3://{bucket}/{inputs[0]}",
                                            }
                                        }
                                    },
                                }
                            }
                        }
                    },
                    "report_name": "test",
                },
                "targetDomain": DOMAIN,
                "targetProject": PROJECT,
                "version": VERSION,
                "workflow": "wf.__init__.deseq2_wf",
            }
        )

        command = [
            "/bin/flytectl",
            "create",
            "--admin.endpoint",
            FLYTE_ADMIN_ENDPOINT,
            "--admin.insecure",
            "--admin.clientId",
            FLYTE_CLIENT_ID,
            "--admin.clientSecretLocation",
            FLYTE_SECRET_PATH,
            "execution",
            "-p",
            PROJECT,
            "-d",
            DOMAIN,
            "--execFile",
            "/dev/stdin",
        ]
        with capsys.disabled():
            print("Running the workflow with flytectl")
            subprocess.run(command, input=_execution_file.encode("utf-8"), check=True)
            print("", flush=True)

        time.sleep(10 * 60)

        for inpt in inputs:
            assert _s3_obj_exists(bucket, inpt) is True
        for output in outputs:
            assert _s3_obj_exists(bucket, output) is True

    finally:
        for output in outputs:
            _rm_s3_obj(bucket, output)
