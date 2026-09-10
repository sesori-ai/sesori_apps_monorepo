# Internal release scheduler dispatcher

Triggered by Alex's Google Cloud Scheduler. Job `sesori-internal-release` lives in
Google Cloud project `sesori-ai`, location `europe-west1`, and runs at `45 * * * *`
UTC. Scheduler console:
<https://console.cloud.google.com/cloudscheduler/jobs/edit/europe-west1/sesori-internal-release?project=sesori-ai>.

Private Cloud Run service `sesori-release-scheduler` accepts authenticated
`POST /dispatch`, authenticates to GitHub as App `4897384` installation
`160598508`, and dispatches `release-all-platforms.yml` on `main` with
`automatic=true`. GitHub's `2026-03-10` REST response identifies the created run.
`GET /health` performs no GitHub call.

Dispatch acceptance means GitHub created a workflow run. It does **not** mean
mobile uploads or bridge builds completed. Alert policy
`projects/sesori-ai/alertPolicies/2058247532448449377` sends severity `ERROR`
or higher logs for this Scheduler job and Cloud Run service in `europe-west1` to
`alex@vespr.xyz` through notification channel
`projects/sesori-ai/notificationChannels/13175960969888864777`. It does not
monitor GitHub Actions; GitHub owns build status and failed-action notifications.

## Security and ownership

- Scheduler calls private Cloud Run with an OIDC token whose audience is the
  service base URL. IAM performs request authentication; application code does
  not implement another caller credential.
- `sesori-release-scheduler@sesori-ai.iam.gserviceaccount.com` is caller identity.
  It has `roles/run.invoker` only on this Cloud Run service.
- `sesori-release-dispatcher@sesori-ai.iam.gserviceaccount.com` is runtime identity.
  It has `roles/secretmanager.secretAccessor` only on secret
  `sesori-release-scheduler-app-key`.
- `sesori-release-builder@sesori-ai.iam.gserviceaccount.com` is the separate
  build identity with project-level `roles/run.builder`. It has no access to the
  GitHub App secret. Cloud Build requires a user-managed identity when one is
  explicitly selected; do not select its legacy service account.
- GitHub App installation is limited to `sesori-ai/sesori_apps_monorepo` with
  Actions write and Metadata read. Installation tokens request this repository
  and Actions write again.
- App PEM is mounted at `/secrets/github-app-key.pem`. It never belongs in source,
  an image, command arguments, environment variables, or logs.
- Repository, workflow, ref, installation, and automatic input are fixed in code.
  Caller body and query parameters cannot select another target.
- Dispatcher has 10-second upstream timeouts and no retry loop. Cloud Scheduler
  owns bounded delivery retries. Workflow concurrency plus release gate prevents
  a retried automatic dispatch from uploading an attempted commit again.

## One-time bootstrap

The identities and alert resources above are provisioned in `sesori-ai`. Secret
`sesori-release-scheduler-app-key` version 1 uses user-managed `europe-west1`
replication and grants its secret-only accessor binding to the runtime identity.
The dispatcher mounts an explicit secret version; adding a version does not
silently change the running service's key.

Run from repository root. Commands mutate Google Cloud and belong to the resource
owner, not CI. Source must remain the dispatcher directory. Job creation is a
one-time operation; for existing resources use the update and operations sections.

```bash
PROJECT=sesori-ai
REGION=europe-west1
SERVICE=sesori-release-scheduler
JOB=sesori-internal-release
RUNTIME_SA=sesori-release-dispatcher
CALLER_SA=sesori-release-scheduler
SECRET=sesori-release-scheduler-app-key
BUILD_SA="projects/${PROJECT}/serviceAccounts/sesori-release-builder@${PROJECT}.iam.gserviceaccount.com"
SECRET_VERSION=1 # Current deployed version; update when rotating the key.

gcloud run deploy "$SERVICE" --project="$PROJECT" --region="$REGION" \
  --source=tool/release_scheduler --build-service-account="$BUILD_SA" \
  --service-account="${RUNTIME_SA}@${PROJECT}.iam.gserviceaccount.com" \
  --no-allow-unauthenticated --min=0 --max=1 --cpu=1 --memory=256Mi \
  --concurrency=10 --timeout=30s \
  --set-secrets="/secrets/github-app-key.pem=${SECRET}:${SECRET_VERSION}"

gcloud run services add-iam-policy-binding "$SERVICE" \
  --project="$PROJECT" --region="$REGION" \
  --member="serviceAccount:${CALLER_SA}@${PROJECT}.iam.gserviceaccount.com" \
  --role=roles/run.invoker

SERVICE_URL="$(gcloud run services describe "$SERVICE" \
  --project="$PROJECT" --region="$REGION" --format='value(status.url)')"

# Creation cannot be paused atomically. Start on side-effect-free health route.
gcloud scheduler jobs create http "$JOB" \
  --project="$PROJECT" --location="$REGION" --schedule='45 * * * *' \
  --time-zone=Etc/UTC --uri="${SERVICE_URL}/health" --http-method=GET \
  --oidc-service-account-email="${CALLER_SA}@${PROJECT}.iam.gserviceaccount.com" \
  --oidc-token-audience="$SERVICE_URL" --attempt-deadline=30s \
  --max-retry-attempts=5 --max-retry-duration=2700s \
  --min-backoff=30s --max-backoff=600s --max-doublings=5

gcloud scheduler jobs pause "$JOB" --project="$PROJECT" --location="$REGION"
gcloud scheduler jobs describe "$JOB" --project="$PROJECT" --location="$REGION" \
  --format='value(state,httpTarget.uri,httpTarget.httpMethod)'

# Only after PAUSED is confirmed, arm dispatch target without resuming job.
gcloud scheduler jobs update http "$JOB" \
  --project="$PROJECT" --location="$REGION" \
  --uri="${SERVICE_URL}/dispatch" --http-method=POST \
  --oidc-service-account-email="${CALLER_SA}@${PROJECT}.iam.gserviceaccount.com" \
  --oidc-token-audience="$SERVICE_URL"
gcloud scheduler jobs describe "$JOB" --project="$PROJECT" --location="$REGION" \
  --format='value(state,httpTarget.uri,httpTarget.httpMethod)'
```

Both descriptions must show `PAUSED`; final target must be `/dispatch` with
`POST`. Keep job paused until release PR merges and owner validates live auth and
resource IAM. Operator needs `iam.serviceAccounts.actAs` on caller identity.
Cloud Scheduler service agent retains standard `roles/cloudscheduler.serviceAgent`;
neither application identity needs a project-wide role.

## Verify and update

Offline verification:

```bash
npm ci --prefix tool/release_scheduler
npm run typecheck --prefix tool/release_scheduler
npm test --prefix tool/release_scheduler
```

Deploy updates from repository root. Source argument must stay exactly
`tool/release_scheduler`; never deploy `.` or a PEM-containing folder.

```bash
SECRET_VERSION=1 # Current deployed version; update when rotating the key.
gcloud run deploy sesori-release-scheduler \
  --project=sesori-ai --region=europe-west1 --source=tool/release_scheduler \
  --build-service-account=projects/sesori-ai/serviceAccounts/sesori-release-builder@sesori-ai.iam.gserviceaccount.com \
  --service-account=sesori-release-dispatcher@sesori-ai.iam.gserviceaccount.com \
  --no-allow-unauthenticated --min=0 --max=1 --cpu=1 --memory=256Mi \
  --concurrency=10 --timeout=30s \
  --set-secrets="/secrets/github-app-key.pem=sesori-release-scheduler-app-key:${SECRET_VERSION}"
```

Check health without dispatching a release:

```bash
SERVICE_URL="$(gcloud run services describe sesori-release-scheduler \
  --project=sesori-ai --region=europe-west1 --format='value(status.url)')"
curl --fail --show-error \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "$SERVICE_URL/health"
```

This command uses an authenticated operator account with Cloud Run invocation
permission. Scheduler instead uses its service account's OIDC token with the
service URL as audience. Validate GitHub auth and the created-run response before
enabling scheduled traffic; `POST /dispatch` is a real automatic release
opportunity, not a harmless probe.

IAM review:

```bash
RUNTIME_EMAIL=sesori-release-dispatcher@sesori-ai.iam.gserviceaccount.com
CALLER_EMAIL=sesori-release-scheduler@sesori-ai.iam.gserviceaccount.com
gcloud run services get-iam-policy sesori-release-scheduler \
  --project=sesori-ai --region=europe-west1
gcloud secrets get-iam-policy sesori-release-scheduler-app-key --project=sesori-ai
gcloud projects get-iam-policy sesori-ai \
  --flatten='bindings[].members' \
  --filter="bindings.members:(${RUNTIME_EMAIL} OR ${CALLER_EMAIL})" \
  --format='table(bindings.role,bindings.members)'
```

## Operations

Cloud Run console:
<https://console.cloud.google.com/run/detail/europe-west1/sesori-release-scheduler/metrics?project=sesori-ai>.
Logs:
<https://console.cloud.google.com/logs/query?project=sesori-ai>.
Logs contain successful workflow run ID/API URL/web URL, or failure
operation/status/GitHub request ID plus diagnostic error/cause names, codes,
messages, and stack traces. The key-signing and HTTP boundaries redact their
actual credentials. JSON parser diagnostics omit message/stack text because it
may quote upstream response bodies. JWTs, installation tokens, PEMs, and upstream
response bodies remain excluded.

```bash
# Pause or resume hourly automatic opportunities.
gcloud scheduler jobs pause sesori-internal-release --project=sesori-ai --location=europe-west1
gcloud scheduler jobs resume sesori-internal-release --project=sesori-ai --location=europe-west1

# Inspect recent dispatcher logs.
gcloud run services logs read sesori-release-scheduler \
  --project=sesori-ai --region=europe-west1 --limit=50
```

Do not use `gcloud scheduler jobs run` to retry a failed/cancelled build: it is an
automatic dispatch and gate will skip the attempted SHA. Retry build failures
from GitHub Actions **Run workflow**, leaving `automatic` false. This preserves
manual retry and branch checkpoint behavior. A Scheduler delivery failure may be
retried by Scheduler within its 45-minute window; operators can inspect logs and
run job only when no GitHub run was created.

## GitHub App key rotation

1. Create second private key in GitHub App settings; keep old key active.
2. Add PEM as new secret version with `gcloud secrets versions add ... --data-file=...`.
3. Set `SECRET_VERSION` to the new numeric version and redeploy Cloud Run; verify
   `/health`, IAM, and the next intended dispatch's created run. Record the deployed
   version in this runbook.
4. Delete old GitHub App key only after new-key dispatch acceptance is confirmed.
5. Destroy local PEM copies according to operator key-handling policy.

Rotation validation through `/dispatch` creates a real workflow run. Use next
intended automatic opportunity or coordinate a controlled run; never treat it as
an authentication-only test.
