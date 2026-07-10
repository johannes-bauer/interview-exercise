#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname ${0})"; pwd)

cd ${PROJECT_DIR}

mkdir -p .tooling/gcloud .tooling/kube .tooling/terraform-cache

CONTAINER_HOME='/home/cloudsdk'

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" \
  -v "$PWD/.tooling/gcloud:${CONTAINER_HOME}/.config/gcloud" \
  -v "$PWD/.tooling/kube:${CONTAINER_HOME}/.kube" \
  -v "$PWD/.tooling/terraform-cache:${CONTAINER_HOME}/.terraform.d/plugin-cache" \
  -v "$PWD/.tooling/docker:${CONTAINER_HOME}/.docker" \
  -e CLOUDSDK_CONFIG=${CONTAINER_HOME}/.config/gcloud \
  -e KUBECONFIG=${CONTAINER_HOME}/.kube/config \
  -e TF_PLUGIN_CACHE_DIR=${CONTAINER_HOME}/.terraform.d/plugin-cache \
  -w /workspace \
  zeit-interview-tools:latest \
  bash
