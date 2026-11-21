# observability-infra

Terraform and other processes needed to administer SMART Home Infrastructure.

Provisions a small GKE Standard cluster in Google Cloud and installs Prometheus + Grafana
(via the `kube-prometheus-stack` Helm chart). GitHub Actions runs `plan` on pull requests and
`apply` on merges to `main`, authenticating to Google Cloud with Workload Identity Federation
(no service account keys).

Setup steps and outstanding work are tracked in [docs/TODO.md](docs/TODO.md).

```
.github/workflows/terraform.yml   CI: plan on PR, apply on main
docs/TODO.md                      setup checklist and outstanding work
scripts/bootstrap-gcp.sh          one-time gcloud setup (APIs, state bucket, CI identity)
terraform/infra/                  VPC, subnet, GKE cluster, node pool
terraform/platform/               Helm release: kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
terraform/platform/values/        Helm values
```

There are two stacks because the Helm provider needs the cluster to exist before it can plan.
State lives in `gs://<PROJECT_ID>-tfstate` under the `infra` and `platform` prefixes.

## CI workflow

The `infra` job runs first; the `platform` job runs only after it succeeds. On a pull request
opened before the cluster exists, the platform plan is skipped with a warning instead of failing.
The workflow reads three repository secrets: `GCP_PROJECT_ID`, `GCP_SA_EMAIL` and
`GCP_WIF_PROVIDER` (printed by `scripts/bootstrap-gcp.sh`).

## Running Terraform locally

```bash
gcloud auth application-default login
export TF_VAR_project_id=<PROJECT_ID>
cd terraform/infra   # or terraform/platform
terraform init -backend-config="bucket=${TF_VAR_project_id}-tfstate"
terraform plan
```

When upgrading providers, regenerate the lock files for every platform that runs Terraform:

```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64
```

## Notes

- **Destroying the cluster:** set `deletion_protection = false` and apply first.
- **Managed Prometheus** (Google's built-in collection) is disabled since we run our own.
