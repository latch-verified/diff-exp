set shell := ["bash", "-c"]

@help:
  just --list --unsorted

#
# Dev setup.
#

@fmt:
  black .
  isort .

@lint:
  black --check .

@clean:
  find . | grep -E "(__pycache__|\.pyc|\.pyo)" | xargs rm -rf

@piptools:
  pip install -U pip-tools

@setup-dev: piptools
  pip-sync dev-requirements.txt


#
# Flyte integration.
#

workflow_version := `cat wf/version`
client_id := "0oa1lnwv2ouNe4t3N697"
secret_path := "/root/client_secret.txt"

app_name := "wf-core-deseq2"
docker_registry := "812206152185.dkr.ecr.us-west-2.amazonaws.com"
docker_image_version := `inp=$(cat wf/version); echo "${inp//+/_}"`
docker_image_prefix := docker_registry + "/" + app_name
docker_image_full := docker_image_prefix + ":" + docker_image_version

def_environment := "latch.bio"
def_project := "4107"
# def_environment := "ligma.ai"
# def_project := "4"
def_endpoint :=  "admin.lyte." + def_environment + ":81"
def_nucleus_endpoint := "https://nucleus." + def_environment

@docker-login:
  aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin {{docker_registry}}

@docker-build:
  docker build --build-arg tag={{docker_image_full}} --build-arg nucleus_endpoint={{def_nucleus_endpoint}} -t {{docker_image_full}} .

@docker-push:
  docker push {{docker_image_full}}

@print-full-docker-image-name:
  echo {{docker_image_full}}

@dbnp: docker-login docker-build docker-push

#
# Entrypoint.
#

register project=def_project endpoint=def_endpoint: docker-build docker-push
  just only-register {{project}} {{endpoint}}

only-register project=def_project endpoint=def_endpoint:
  docker run -i --rm \
    -e REGISTRY={{docker_registry}} \
    -e PROJECT={{project}} \
    -e VERSION={{workflow_version}} \
    -e FLYTE_ADMIN_ENDPOINT={{endpoint}} \
    -e FLYTE_CLIENT_ID={{client_id}} \
    -e FLYTE_SECRET_PATH={{secret_path}} \
    -e FLYTE_INTERNAL_IMAGE={{docker_image_full}} \
    {{docker_image_full}} make register

test project=def_project endpoint=def_endpoint:
  docker run -i --rm \
    -e REGISTRY={{docker_registry}} \
    -e PROJECT={{project}} \
    -e VERSION={{workflow_version}} \
    -e FLYTE_ADMIN_ENDPOINT={{endpoint}} \
    -e FLYTE_CLIENT_ID={{client_id}} \
    -e FLYTE_SECRET_PATH={{secret_path}} \
    -e FLYTE_INTERNAL_IMAGE={{docker_image_full}} \
    -e AWS_ACCESS_KEY_ID={{env_var("AWS_ACCESS_KEY_ID")}} \
    -e AWS_SECRET_ACCESS_KEY={{env_var("AWS_SECRET_ACCESS_KEY")}} \
    {{docker_image_full}} make test

sleep project=def_project endpoint=def_endpoint: docker-build
  docker run -i --rm \
    -e REGISTRY={{docker_registry}} \
    -e PROJECT={{project}} \
    -e VERSION={{workflow_version}} \
    -e FLYTE_ADMIN_ENDPOINT={{endpoint}} \
    -e FLYTE_CLIENT_ID={{client_id}} \
    -e FLYTE_SECRET_PATH={{secret_path}} \
    {{docker_image_full}} sleep 100000000
