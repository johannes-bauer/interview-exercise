#!/usr/bin/env bash
set -euo pipefail

OUTFILE="terraform/terraform.tfvars"
K8S_ENV_FILE="k8s/.env"

for f in "$OUTFILE" "$K8S_ENV_FILE"; do
  if [[ -e "$f" ]]; then
    echo "$f already exists.  Remove it first to create a new project."
    exit 1
  fi
done

ensure_gcloud_auth() {
  local active_account

  active_account="$(gcloud auth list \
    --filter=status:ACTIVE \
    --format='value(account)' || true)"

  if [[ -z "$active_account" ]]; then
    echo "Let's log you in with gcloud, first."
    gcloud auth login
  else
    echo "gcloud already authenticated as $active_account"
  fi

  if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    gcloud auth application-default login
  else
    echo "ADC already configured"
  fi
}

ensure_gcloud_auth

PROJECT_ID=""
until [[ -n "${PROJECT_ID}" ]]; do read -rp "Please enter an ID for the GCP project to create: " PROJECT_ID ; done

MLFLOW_BUCKET=""
until [[ -n "${MLFLOW_BUCKET}" ]]; do read -rp "GCS bucket name for MLflow artifacts: " MLFLOW_BUCKET ; done

DATA_BUCKET=""
until [[ -n "${DATA_BUCKET}" ]]; do read -rp "GCS bucket name for training/scoring data: " DATA_BUCKET ; done

GITHUB_OWNER=""
until [[ -n "${GITHUB_OWNER}" ]]; do read -rp "GitHub user or organisation owning the repository: " GITHUB_OWNER ; done

GITHUB_REPO=""
until [[ -n "${GITHUB_REPO}" ]]; do read -rp "GitHub repository name (without owner): " GITHUB_REPO ; done

BILLING_ACCOUNT_ID=""
until (gcloud billing accounts describe ${BILLING_ACCOUNT_ID} >/dev/null 2>&1) ; do 
	echo "Existing billing accounts:"
	gcloud billing accounts list
	read -rp "Please enter an existing billing account to use: " BILLING_ACCOUNT_ID ; 
done

gcloud projects create "$PROJECT_ID" --name="Zeit job interview"

# test that the project exists now.
gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1

gcloud billing projects link "$PROJECT_ID" \
  --billing-account="$BILLING_ACCOUNT_ID"

gcloud auth application-default set-quota-project "$PROJECT_ID"

gcloud config set project "$PROJECT_ID"

cat > "$OUTFILE" <<EOF
project_id                         = "$PROJECT_ID"
region                             = "europe-west3"
zone                               = "europe-west3-a"
mlflow_artifact_bucket_name        = "$MLFLOW_BUCKET"
training_scoring_data_bucket_name  = "$DATA_BUCKET"
github_owner                       = "$GITHUB_OWNER"
github_repository                  = "$GITHUB_REPO"
EOF

cat > "$K8S_ENV_FILE" <<EOF
GKE_PROJECT=$PROJECT_ID
GKE_REGION=europe-west3
DATA_BUCKET_NAME=$DATA_BUCKET
EOF
