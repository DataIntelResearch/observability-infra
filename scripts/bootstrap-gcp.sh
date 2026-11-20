#!/usr/bin/env bash
# One-time setup, run locally with gcloud before GitHub Actions can run Terraform:
# enables APIs, creates the Terraform state bucket, the terraform-ci service account,
# and the Workload Identity Federation trust between this GitHub repo and Google Cloud.
#
# Usage: scripts/bootstrap-gcp.sh <PROJECT_ID> <GITHUB_OWNER/REPO> [BUCKET_LOCATION]
# Safe to re-run: existing resources are left alone.
set -euo pipefail

PROJECT_ID="${1:?usage: $0 <PROJECT_ID> <GITHUB_OWNER/REPO> [BUCKET_LOCATION]}"
REPO="${2:?usage: $0 <PROJECT_ID> <GITHUB_OWNER/REPO> [BUCKET_LOCATION]}"
LOCATION="${3:-us-east1}"

BUCKET="gs://${PROJECT_ID}-tfstate"
SA_NAME="terraform-ci"
SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
POOL="github"
PROVIDER="github-repo"

gcloud config set project "$PROJECT_ID"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

echo "==> Enabling APIs"
gcloud services enable \
  container.googleapis.com compute.googleapis.com iam.googleapis.com \
  iamcredentials.googleapis.com sts.googleapis.com cloudresourcemanager.googleapis.com

echo "==> State bucket ${BUCKET}"
if ! gcloud storage buckets describe "$BUCKET" >/dev/null 2>&1; then
  gcloud storage buckets create "$BUCKET" --location="$LOCATION" --uniform-bucket-level-access
fi
gcloud storage buckets update "$BUCKET" --versioning

echo "==> Service account ${SA}"
if ! gcloud iam service-accounts describe "$SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" --display-name="Terraform CI (GitHub Actions)"
fi
for role in roles/container.admin roles/compute.networkAdmin roles/iam.serviceAccountAdmin \
            roles/iam.serviceAccountUser roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA}" --role="$role" --condition=None >/dev/null
done
gcloud storage buckets add-iam-policy-binding "$BUCKET" \
  --member="serviceAccount:${SA}" --role=roles/storage.objectAdmin >/dev/null

echo "==> Workload Identity Federation for ${REPO}"
if ! gcloud iam workload-identity-pools describe "$POOL" --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL" --location=global --display-name="GitHub Actions"
fi
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER" \
       --location=global --workload-identity-pool="$POOL" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
    --location=global --workload-identity-pool="$POOL" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${REPO}'"
fi
gcloud iam service-accounts add-iam-policy-binding "$SA" --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/attribute.repository/${REPO}" >/dev/null

cat <<OUT

Done. Add these as GitHub repository *variables* (Settings -> Secrets and variables -> Actions -> Variables):

  GCP_PROJECT_ID   = ${PROJECT_ID}
  GCP_SA_EMAIL     = ${SA}
  GCP_WIF_PROVIDER = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}

Or with the GitHub CLI:

  gh variable set GCP_PROJECT_ID   --repo ${REPO} --body '${PROJECT_ID}'
  gh variable set GCP_SA_EMAIL     --repo ${REPO} --body '${SA}'
  gh variable set GCP_WIF_PROVIDER --repo ${REPO} --body 'projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}'
OUT
