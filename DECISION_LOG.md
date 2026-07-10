# Use GCP, not local MiniKube

## Why?

 * closer to real environment
 * less set up w/o a functioning MiniKube cluster


# Choose local Terraform storage over a remote storage backend

## Why?

 * Simplicity for this interview.
 * I'd use a remote storage in a separate project/bucket in practice, for
   robustness, safety, concurrent team work.
 * In fact, I'd consider applying changes from github actions

# Choose bucket over BigQuery

## Why?

 * Easy to keep training data with prediction data; great for diagnostics,
 * simpler interface,
 * no complex data selection needed (at this point),
 * less setup needed,
 * easy to limit read/write access for the job.


# Choose FUSE-mounted bucket over basic bucket access

## Why?

 * No need to change script; easy transfer from local model development on
   static data to production.
 * Fewer dependencies in image.


# Exposure of the MLFlow service only via kubectl port-forward

## Why?

 * Would have to implement access management for the service; too much
   work for now.


# MLFlow state DB (sqlite) on a PVC.

## Why?

 * Too much TF wiring for this exercise; a production setup would use Cloud SQL.
