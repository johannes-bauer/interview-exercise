# ML Platform — Interview Exercise

A minimal but production-minded MLOps platform on GCP, built as a take-home exercise for the Zeit Verlag ML/AI Platform Engineer role.

## What it does

Trains and scores a churn-prediction model (XGBoost Random Forest) on GKE, with MLflow for experiment tracking and model registry.
All infrastructure is managed with Terraform.
Docker images are built and pushed by GitHub Actions.

## Architecture

```
GitHub Actions ──builds──▶ Artifact Registry (Docker images)
                                    │
                          ┌─────────▼──────────────────────────────┐
                          │  GKE Autopilot cluster                 │
                          │                                        │
                          │  [mlflow ns]  MLflow server            │
                          │               ├── SQLite DB (PVC)      │
                          │               └── artifacts ──▶ GCS    │
                          │                                        │
                          │  [training ns]  Job: train             │
                          │                 Job: score             │
                          │                 (GCS FUSE data mount)  │
                          └────────────────────────────────────────┘

GCS buckets:  ml-artifacts   (MLflow artifacts)
              ml-data        (training data, scoring data, predictions)
```

**Key design choices** are documented in [DECISION_LOG.md](DECISION_LOG.md).

## Repository layout

```
terraform/          Root Terraform configuration
modules/
  platform/         GKE cluster, Artifact Registry, GCP API enablement
  mlflow/           MLflow deployment: GCS bucket, K8s Deployment + Service, IAM
  training/         IAM and storage for training/scoring jobs
  github_ci/        Workload Identity Federation for GitHub Actions
images/
  production/
    mlflow/         Dockerfile for the MLflow tracking server
    training/       Dockerfile + requirements + train_and_score.py
  docker_tools/     Dev tooling container (gcloud, kubectl, terraform)
k8s/
  training.yml.in   Kubernetes Job template for training
  scoring.yml.in    Kubernetes Job template for scoring
.github/workflows/
  build-images.yml  CI: build and push Docker images to Artifact Registry
```

## Prerequisites

- A GCP project with billing enabled
- A GitHub repository (for CI and Workload Identity)
- Docker (to run the tooling container)

## Setup

**1. First-time initialisation**

```bash
./tools.sh        # builds the tooling container if needed, then drops you into a shell
./init.sh         # inside the container: authenticates with GCP, creates the project,
                  # and writes terraform/terraform.tfvars and k8s/.env
```

**2. Apply platform infrastructure**

> **Bootstrapping limitation:** a plain `terraform apply` will hang on the MLflow
> deployment because Terraform waits for the pod to become ready, the pod needs the
> MLflow image, and the image doesn't exist until GitHub Actions has run — which in
> turn requires the Artifact Registry and Workload Identity that Terraform is creating.
> Break the cycle by applying in two steps:

```bash
terraform init
terraform apply -target=module.platform -target=module.github
```

Then complete steps 3 and 4 below, wait for the CI build to finish, and run:

```bash
terraform apply
```

This second apply deploys the MLflow server and training infrastructure, by which
point the images are available.

**3. Configure GitHub Actions**

After `terraform apply`, note the two outputs:

```
github_workload_identity_provider  = ...
github_image_builder_service_account = ...
```

Add these as repository variables in GitHub (`Settings → Secrets and variables → Actions`):

| Variable | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `github_workload_identity_provider` output |
| `GCP_IMAGE_BUILDER_SERVICE_ACCOUNT` | `github_image_builder_service_account` output |
| `GCP_PROJECT_ID` | your GCP project ID |
| `GCP_REGION` | your GCP region |

Then trigger the **Build container images** workflow (push to `main` or run manually). This builds and pushes the `mlflow` and `trainandscore` images.

**5. Upload training and scoring data**

```bash
gsutil cp data/*.csv gs://<DATA_BUCKET_NAME>/
```

**6. Access MLflow**

The MLflow server is intentionally not exposed publicly. Access it via port-forward:

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --region <REGION>
kubectl port-forward -n mlflow svc/mlflow 5000:5000
```

Then open [http://localhost:5000](http://localhost:5000).

## Running training and scoring

Training and scoring are ephemeral Kubernetes Jobs, not managed by Terraform — they run when triggered by new data or a code change, not as permanent infrastructure.

The `k8s/` directory contains Job templates. `k8s/.env` (written by `init.sh`) provides the project and bucket variables; only the job name needs to be set at run time:

```bash
export JOB_NAME=train-$(date +%Y%m%d-%H%M%S)

set -a; source k8s/.env; set +a
envsubst < k8s/training.yml.in | kubectl apply -f -
```

The training job:
- mounts the data bucket via GCS FUSE at `/data`
- reads `train_data.csv`, trains the model, logs metrics and the model to MLflow
- registers the model and promotes it to the `champion` alias

Run scoring the same way:

```bash
export JOB_NAME=score-$(date +%Y%m%d-%H%M%S)

set -a; source k8s/.env; set +a
envsubst < k8s/scoring.yml.in | kubectl apply -f -
```

The scoring job loads the `champion` model from MLflow, scores `scoring_data.csv`, and writes `scored_output.csv` back to the data bucket.

## Notes on the training script

`train_and_score.py` was provided by the data scientist and modified minimally to make it deployable. 
Inline comments in the script flag several issues that should be addressed collaboratively before production use — notably: evaluation on training data only (no held-out set), one-hot encoding consistency between train and score, and an ID column that should be excluded from features.
