#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname ${0})"; pwd)

cd ${PROJECT_DIR}

mkdir -p .tooling/gcloud .tooling/kube .tooling/terraform-cache .tooling/docker

IMAGE_NAME="zeit-interview-tools:latest"

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Building tooling container..."
  docker build -t "${IMAGE_NAME}" "${PROJECT_DIR}/images/docker_tools/"
fi

CONTAINER_HOME='/home/cloudsdk'

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "${PROJECT_DIR}:/workspace" \
  -v "${PROJECT_DIR}/.tooling/gcloud:${CONTAINER_HOME}/.config/gcloud" \
  -v "${PROJECT_DIR}/.tooling/kube:${CONTAINER_HOME}/.kube" \
  -v "${PROJECT_DIR}/.tooling/terraform-cache:${CONTAINER_HOME}/.terraform.d/plugin-cache" \
  -e CLOUDSDK_CONFIG=${CONTAINER_HOME}/.config/gcloud \
  -e KUBECONFIG=${CONTAINER_HOME}/.kube/config \
  -e TF_PLUGIN_CACHE_DIR=${CONTAINER_HOME}/.terraform.d/plugin-cache \
  -w /workspace \
  zeit-interview-tools:latest \
  bash
