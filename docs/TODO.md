# To-dos

Remaining setup and follow-up work, not counting commits, pushes and pull requests.

## Before the first deploy

- [X] Create a Google Cloud project, or choose an existing one, and confirm billing is linked to it.
- [X] Set up a billing budget and alert for the project. The GKE node pool is the main cost.
- [X] Install the `gcloud` CLI on your workstation and log in with an account that has Owner on the project (`gcloud auth login`).
- [X] Choose between spot and on-demand nodes. Set `spot` in [terraform/infra/variables.tf](../terraform/infra/variables.tf). Spot is much cheaper, but Google can reclaim those nodes. (Kept "spot" disabled, can revisit if cost is a concern)
- [X] Check the zone (`us-east1-b`), the machine type (`e2-standard-4`) and the node count (1–3). If you change the zone or cluster name, update both stacks' `variables.tf` and the cluster check in the workflow.
- [ ] Run the bootstrap script:
      `scripts/bootstrap-gcp.sh <PROJECT_ID> DataIntelResearch/observability-infra`
- [ ] Add the three GitHub repository secrets the script prints: `GCP_PROJECT_ID`, `GCP_SA_EMAIL` and `GCP_WIF_PROVIDER`.
- [ ] Optional: set up a `production` environment with required reviewers in GitHub, then uncomment `environment: production` in the workflow so every apply needs approval.

## After the first deploy

- [ ] Make sure the `infra` and `platform` jobs both finished applying.
- [ ] Get cluster credentials and confirm every pod in `monitoring` is running:
      `gcloud container clusters get-credentials obs --zone us-east1-b --project <PROJECT_ID>`
      `kubectl -n monitoring get pods`
- [ ] Get the Grafana admin password (`terraform output -raw grafana_admin_password` from `terraform/platform`) and store it in a password manager.
- [ ] Port-forward to Grafana and Prometheus and check that the built-in Kubernetes dashboards show data.
- [ ] Check the cluster's GKE version (`gcloud container clusters describe obs --zone us-east1-b --format='value(currentMasterVersion)'`). On 1.36.4 or newer, replace `remove_default_node_pool` with `initial_node_count = 0` to clear the provider deprecation warning.
- [ ] Look at actual node usage after a few days and resize the node pool if it's too large or too small.

## Access and security

- [ ] Expose Grafana without port-forwarding: add an Ingress or Gateway with Identity-Aware Proxy, a DNS name and a managed TLS certificate, all in Terraform.
- [ ] Decide who gets Grafana access and set up users or SSO in place of the shared admin login.
- [ ] Put authentication in front of any Prometheus endpoint before exposing it. Prometheus has no login of its own.

## Mac Mini / OpenTelemetry

- [ ] Fix the earlier problems with the OpenTelemetry Collector on the Mac Mini, then get it running in the foreground with the `debug` exporter.
- [ ] Install the Collector as a launchd daemon running as root.
- [ ] Confirm `curl localhost:8889/metrics` shows both `system_*` and `process_*` metrics.
- [ ] Add a process filter if the per-process metrics create too many series.
- [ ] Instrument one Python program (`opentelemetry-distro`, `opentelemetry-instrument`) and capture its stdout/stderr into `/usr/local/var/log/pyapps/`.
- [ ] Add log rotation for `/usr/local/var/log/pyapps/` with newsyslog (`/etc/newsyslog.d/pyapps.conf`).
- [ ] Connect the Mac Mini to the cluster: enable `enableRemoteWriteReceiver` in [kube-prometheus-stack.yaml](../terraform/platform/values/kube-prometheus-stack.yaml) and add a `prometheusremotewrite` exporter (with auth) to the Collector config.

## Logs, traces and alerting

- [ ] Add Grafana Loki as a Helm release in the platform stack, then point the Collector's logs pipeline at it instead of the file exporter.
- [ ] Optional: add Grafana Tempo for traces.
- [ ] Set up Alertmanager receivers (email, Slack, etc.) and a few basic alert rules: Mac Mini down, high CPU or memory, disk filling up.
- [ ] Build or import Grafana dashboards for the Mac Mini host and process metrics, and keep them in the repo as code.

## Ongoing maintenance

- [ ] Check for new `kube-prometheus-stack` chart versions periodically and bump `kube_prometheus_stack_version`.
- [ ] Upgrade the Terraform providers and refresh the lock files for all platforms when you do.
- [ ] Decide on a backup plan for the Prometheus and Grafana persistent disks, such as scheduled snapshots.
- [ ] Revisit retention (`15d` / `40GB`) once real data volumes are known.
