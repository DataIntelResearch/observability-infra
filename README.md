# observability-infra

Terraform and other processes needed to administer SMART Home Infrastructure.

Provisions a small GKE Standard cluster in Google Cloud and installs Prometheus + Grafana
(via the `kube-prometheus-stack` Helm chart). GitHub Actions runs `plan` on pull requests and
`apply` on merges to `main`, authenticating to Google Cloud with Workload Identity Federation
(no service account keys).

```
.github/workflows/terraform.yml   CI: plan on PR, apply on main
scripts/bootstrap-gcp.sh          one-time gcloud setup (APIs, state bucket, CI identity)
terraform/infra/                  VPC, subnet, GKE cluster, node pool
terraform/platform/               Helm release: kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
terraform/platform/values/        Helm values
```

There are two stacks because the Helm provider needs the cluster to exist before it can plan.
State lives in `gs://<PROJECT_ID>-tfstate` under the `infra` and `platform` prefixes.

## 1. One-time setup

Requires `gcloud` logged in as a project owner.

```bash
scripts/bootstrap-gcp.sh <PROJECT_ID> DataIntelResearch/observability-infra
```

The script prints three values. Add them as **repository variables** (not secrets) under
Settings → Secrets and variables → Actions → Variables:

| Variable           | Example                                                                              |
| ------------------ | ------------------------------------------------------------------------------------ |
| `GCP_PROJECT_ID`   | `my-project`                                                                         |
| `GCP_SA_EMAIL`     | `terraform-ci@my-project.iam.gserviceaccount.com`                                    |
| `GCP_WIF_PROVIDER` | `projects/123456789/locations/global/workloadIdentityPools/github/providers/github-repo` |

## 2. Deploy

Push to `main` (or run the workflow manually from the Actions tab). The `infra` job creates the
cluster, then the `platform` job installs the chart. On a pull request opened before the
cluster exists, the platform plan is skipped with a warning instead of failing.

Optional approval gate: uncomment `environment: production` in the workflow and add required
reviewers to that environment in GitHub.

## 3. Verify

```bash
gcloud container clusters get-credentials obs --zone us-east1-b --project <PROJECT_ID>
kubectl -n monitoring get pods

# Grafana admin password
cd terraform/platform
terraform init -backend-config="bucket=<PROJECT_ID>-tfstate"
terraform output -raw grafana_admin_password

kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80       # http://localhost:3000, user "admin"
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090  # http://localhost:9090
```

Grafana ships with the Prometheus data source and Kubernetes dashboards preconfigured.

## Running Terraform locally

```bash
gcloud auth application-default login
export TF_VAR_project_id=<PROJECT_ID>
cd terraform/infra   # or terraform/platform
terraform init -backend-config="bucket=${TF_VAR_project_id}-tfstate"
terraform plan
```

Commit `.terraform.lock.hcl` changes when upgrading providers
(`terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64`).

## Notes

- **Cost:** the node pool (`e2-standard-4`, 1–3 nodes) is the main expense. Set `spot = true`
  in `terraform/infra/variables.tf` to cut it substantially, at the risk of node reclamation.
- **Destroying the cluster:** set `deletion_protection = false` and apply first.
- **Managed Prometheus** (Google's built-in collection) is disabled since we run our own.
- **Zone/cluster name** are defaults in both stacks' `variables.tf` and hardcoded in the
  workflow's cluster-exists check; change all three together.
- **Chart upgrades:** bump `kube_prometheus_stack_version` in `terraform/platform/variables.tf`.

## Next steps

- Expose Grafana without port-forwarding: Ingress/Gateway + Identity-Aware Proxy.
- Connect the Mac Mini OpenTelemetry Collector: enable `enableRemoteWriteReceiver` in the values
  file and use the Collector's `prometheusremotewrite` exporter, behind authentication.
- Add Loki as another Helm release in the platform stack for Python program logs.
