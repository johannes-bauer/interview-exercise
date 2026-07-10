FROM python:3.12-slim

ARG MLFLOW_VERSION=3.1.0

RUN pip install --no-cache-dir \
    "mlflow==${MLFLOW_VERSION}" \
    google-cloud-storage

EXPOSE 5000
