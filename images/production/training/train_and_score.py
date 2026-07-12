### Train an XGBoost Random Forest on the training data ###


# Note JB:
# --------
# This script requires a few changes so training and scoring can be run
# separately.  It also has a number of serious robustness issues that
# may or may not surface at development time, that would need, however, 
# to be addressed before it can be used safely in production. 
#
# In a real business context, I would not fix those issues myself, as
# a data engineer.  Fixing them may be the faster route to a working
# deployment, but it may break hidden assumptions the data scientist made, 
# possibly breaking something that worked in their hands.  It also 
# deprives them of feedback they need to develop more robust code in
# the future and it establishes a brittle data science/platform
# interface in which code is initially developed by one party and then
# modified by another without a shared understanding of what it should
# do.
# 
# Instead, I would work together with the data scientist to adapt the 
# code so it is production ready, or at least up to the point where any
# changes required are implementation details of the platform and do not
# modify the data science logic.  Depending on the situation, I might
# work with clients of the platform to develop common code, architecture,
# and data handling standards.
#
# For this exercise, I'll make as few changes as possible to get to a
# working deployment and point out the issues that would need to be
# addressed together with the original author of the script.


import os
import argparse
import pathlib
import pandas as pd
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score
from xgboost import XGBRFClassifier
import mlflow


FEATURES = ["objekt_name", "aboform_name", "lesedauer", "zahlung_weg_name"]

# This needs to be determined ahead of time; a), because we can't rely on
# the scoring data having the same dtypes as the training data and b) because
# this shouldn't be accidental; we should know what those features are and
# whether they are categorical.  Less of a problem when reading from a DB or
# parquet, or hdf5 than from CSV.
CATEGORICAL_FEATURES = ["objekt_name", "aboform_name", "zahlung_weg_name"]

TARGET = "churn"


def train(registered_model_name: str, data_dir: pathlib.Path):
    experiment_name = f'train-{registered_model_name}'
    mlflow.set_experiment(experiment_name)

    mlflow.xgboost.autolog(
        registered_model_name=registered_model_name
    )

    # 1. Load training data
    # Note JB: I notice the first column in the DF is an ID column.
    # The classifier probably won't be able to make sense of it, so
    # it probably won't use it, but it really should be dropped.
    # Something to discuss with the data scientist (see above).
    train_df = pd.read_csv(data_dir / "train_data.csv", sep=';')


    # Note JB: Leaving this in as a comment to mark the change.  See above.
    #
    # # Identify categorical features for one-hot encoding
    # categorical_features = [col for col in FEATURES if train_df[col].dtype == 'object']

    # Apply one-hot encoding to training data
    train_df_encoded = pd.get_dummies(train_df, columns=CATEGORICAL_FEATURES, drop_first=True)

    # Update features list to include new one-hot encoded columns
    X_train = train_df_encoded.drop(columns=TARGET)
    y_train = train_df_encoded[TARGET]

    # 2. Train an XGBoost Random Forest
    model = XGBRFClassifier(
        n_estimators=100,
        max_depth=4,
        random_state=42,
        use_label_encoder=False,
        eval_metric="logloss",
    )
    with mlflow.start_run() as run:
        model.fit(X_train, y_train)

        # 3. Evaluate
        y_pred = model.predict(X_train)
        y_prob = model.predict_proba(X_train)[:, 1]

        accuracy = accuracy_score(y_train, y_pred)
        f1 = f1_score(y_train, y_pred)
        auc = roc_auc_score(y_train, y_prob)

        # Note JB: Use logging instead of print statements.
        print(f"Training Accuracy : {accuracy:.4f}")
        print(f"Training F1 Score : {f1:.4f}")
        print(f"Training AUC      : {auc:.4f}")

        # Note JB: For proper metrics, we should evaluate the model
        # on held-out data; ideally using full cross validation.
        mlflow.log_metrics({
            "accuracy_train": accuracy,
            "f1_train": f1,
            "auc_train": auc
        })

        return run.info.run_id


def promote_model(model_name:str, run_id: str, alias:str):
    client = mlflow.MlflowClient()

    latest, = client.search_model_versions(
        f"name='{model_name}' AND run_id='{run_id}'"
    )

    client.set_registered_model_alias(
        name=model_name,
        alias=alias,
        version=latest.version,
    )


def score(model_name: str, model_alias: str, data_dir: pathlib.Path):

    model = mlflow.xgboost.load_model(
        f'models:/{model_name}@{model_alias}'
    )

    ### Compute survival probabilities on the scoring dataset.

    # 1. Load scoring data
    score_df = pd.read_csv(data_dir / "scoring_data.csv", sep=';')

    # Note JB: This may or may not produce the same one-hot encoding as during training, depending
    # on whether all the same categories occur in both the training and the scoring data set.
    # This should be handled by an sklearn Pipeline with a OneHotEncoder.
    # 
    # Apply one-hot encoding to scoring data, ensuring consistent columns with training data
    score_df_encoded = pd.get_dummies(score_df, columns=CATEGORICAL_FEATURES, drop_first=True)

    # Note JB: There's something seriously broken if the scoring data set lacks columns that
    # are in the training data set.
    # 
    # Adding missing columns and inserting zeros is probably not a good strategy.  As assertion 
    # that specifically tests that all required input columns are present (and optionally: that
    # dtypes, ranges etc are as expected) will surface unexpected changes.
    #
    # # Align columns - this is crucial to ensure that the scoring data has the exact same columns as the training data
    # # This handles cases where a category might be present in train but not in score, or vice-versa.
    # # missing_cols_in_score = set(X_train.columns) - set(score_df_encoded.columns)
    # for c in missing_cols_in_score:
    #    score_df_encoded[c] = 0
    #
    # # Ensure the order of columns is the same as in X_train
    # X_score = score_df_encoded[X_train.columns]
    #
    # Note JB: 
    # Changing as little as possible and hoping for the best; at least the column order in the
    # example data is consistent, so this may not fail completely:
    X_score = score_df_encoded

    # 2. Compute survival probabilities
    probabilities = model.predict_proba(X_score)[:, 1]

    score_df["churn_probability"] = probabilities

    # Note JB: read semicolon separated data, write comma separated data.  Intentional?
    score_df.to_csv(data_dir / "scored_output.csv", index=False)

    print(score_df[['id'] + FEATURES + ["churn_probability"]].head(10))
    print(f"\nScored {len(score_df)} records → saved to scored_output.csv")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['train', 'score'])
    parser.add_argument('model_name')
    parser.add_argument('data_dir', type=pathlib.Path)
    args = parser.parse_args()

    if tracking_uri := os.getenv("MLFLOW_TRACKING_URI"):
        # Otherwise, mlflow logs results to the local filesystem.
        mlflow.set_tracking_uri(tracking_uri)

    if args.action == 'train':
        run_id = train(args.model_name, args.data_dir)
        promote_model(args.model_name, run_id, 'champion')
    else:
        score(args.model_name, 'champion', args.data_dir)

