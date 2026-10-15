#!/usr/bin/env bash
# One-time, operator-authorized setup. No changes to existing buckets, identities or providers.
set -euo pipefail
project=sesori-ai
number=1068630921159
bucket=sesori-ai-linux-packages
pool=linux-packages
account="linux-package-publisher@$project.iam.gserviceaccount.com"
workflow='sesori-ai/sesori_apps_monorepo/.github/workflows/linux-repository.yml@refs/heads/main'

# Numeric identities prevent a renamed/recreated repository from inheriting this grant.
condition="assertion.repository_id == '1187455604' && assertion.repository_owner_id == '267088852'"
condition+=" && assertion.ref == 'refs/heads/main'"
condition+=" && ('job_workflow_ref' in assertion ? assertion.job_workflow_ref : assertion.workflow_ref) == '$workflow'"

gcloud storage buckets create "gs://$bucket" --project="$project" --location=europe-west1 \
  --uniform-bucket-level-access --quiet
gcloud iam service-accounts create linux-package-publisher --project="$project" \
  --display-name='Linux package repository publisher' --quiet
gcloud iam workload-identity-pools create "$pool" --project="$project" --location=global \
  --display-name='Linux package publishing' --quiet
gcloud iam workload-identity-pools providers create-oidc github --project="$project" --location=global \
  --workload-identity-pool="$pool" --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping='google.subject=assertion.sub,attribute.repository=assertion.repository' \
  --attribute-condition="$condition" --quiet
principal="principalSet://iam.googleapis.com/projects/$number/locations/global/workloadIdentityPools/$pool"
principal+='/attribute.repository/sesori-ai/sesori_apps_monorepo'
gcloud iam service-accounts add-iam-policy-binding "$account" --project="$project" \
  --role=roles/iam.workloadIdentityUser --member="$principal" --quiet
gcloud storage buckets add-iam-policy-binding "gs://$bucket" \
  --member="serviceAccount:$account" --role=roles/storage.objectUser --quiet
gcloud storage buckets add-iam-policy-binding "gs://$bucket" \
  --member=allUsers --role=roles/storage.objectViewer --quiet
