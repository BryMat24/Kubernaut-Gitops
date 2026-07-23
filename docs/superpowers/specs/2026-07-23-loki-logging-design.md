# Loki logging for the `dev` environment

## Context

The `dev` environment (`clusters/dev/`) runs the three sandbox services (`frontend`,
`backend`, `cache`) plus a `kube-prometheus-stack` monitoring install
(`monitoring/dev/`, namespace `dev-monitoring`) for metrics. There is currently no
centralized log aggregation: application logs only exist as pod stdout, visible via
`kubectl logs` on a per-pod basis.

Each of the three services already writes its logs to stdout/stderr (standard
container logging practice) — this is app-level behavior configured outside this
repo. This repo only needs to add the infrastructure to collect, store, and make
those logs queryable.

## Goal

Add Loki-based log aggregation to the `dev` environment, following the same
Kustomize + Helm-chart-generator pattern already established for
`kube-prometheus-stack`, and surface the logs in the Grafana instance that already
exists for metrics.

## Approach

Use the `loki-stack` Helm chart (`https://grafana.github.io/helm-charts`), which
bundles:
- **Loki** — single-binary mode, filesystem storage backend. No object storage
  (S3/GCS) dependency; appropriate for this sandbox/test-scenario environment where
  log durability across cluster rebuilds is not a requirement.
- **Promtail** — deployed as a DaemonSet, one pod per node. Uses the chart's default
  Kubernetes service-discovery scrape config, which tails container log files for
  all pods cluster-wide and attaches `namespace`/`pod`/`container` labels
  automatically. No per-app configuration is required since the apps already log to
  stdout.

This was chosen over standing up `loki` + `grafana-agent`/`alloy` as separate charts
(Grafana's newer recommended path) because Alloy requires writing an Alloy-syntax
config block for log discovery — meaningfully more setup for a sandbox environment
where Promtail's zero-config default already does the job. Promtail is in
maintenance mode upstream but fully functional; if this environment later needs
Alloy-specific features, that's a separate follow-up.

Grafana already exists via the `kube-prometheus-stack` release in `dev-monitoring`,
with its sidecar configured (`monitoring/dev/values.yaml`,
`grafana.sidecar.datasources.enabled: true`, `label: grafana_datasource`) to
auto-load any ConfigMap labeled `grafana_datasource: "1"` as a datasource. Loki is
wired into Grafana via a plain ConfigMap carrying that label — no changes to the
`kube-prometheus-stack` release itself.

## Directory layout

New directory `logging/dev/`, mirroring the existing `monitoring/dev/` structure:

```
logging/dev/
  kustomization.yaml       # helmCharts entry for loki-stack + the datasource ConfigMap resource
  values.yaml               # loki-stack overrides: persistence disabled, otherwise chart defaults
  grafana-datasource.yaml   # ConfigMap, labeled grafana_datasource: "1", namespace dev-monitoring
```

`logging/dev/kustomization.yaml`:
- `helmCharts:` — one entry, `name: loki-stack`, `repo: https://grafana.github.io/helm-charts`,
  `releaseName: loki`, `namespace: dev-monitoring`, `valuesFile: values.yaml`,
  `includeCRDs: true`. Chart version pinned to a specific release (exact version
  resolved at implementation time, following the same pinning convention as
  `monitoring/dev/kustomization.yaml`'s `kube-prometheus-stack` entry).
- `resources:` — `grafana-datasource.yaml`.

No `namespace.yaml` in this directory — `dev-monitoring` is already created by
`monitoring/dev/namespace.yaml`. `logging/dev`'s chart resources simply target that
existing namespace.

`grafana-datasource.yaml` — a ConfigMap in `dev-monitoring`, labeled
`grafana_datasource: "1"`, containing a Grafana provisioning-format datasource
definition for Loki (type `loki`, URL pointing at the in-cluster Loki Service's
ClusterIP DNS name on port 3100). The exact Service name is determined by the
`loki-stack` chart's naming convention for the `loki` release — confirmed by
inspecting `kustomize build --enable-helm`'s rendered output during implementation
rather than assumed here.

## Wiring into the root

Add one line to `clusters/dev/kustomization.yaml`'s `resources:` list:
`../../logging/dev`, ordered **after** `../../monitoring/dev` so the
`dev-monitoring` namespace exists before Loki's resources are applied into it
(matches the existing ordering rationale already used for `dev` namespace vs. the
app overlays in that same file).

## Data flow

1. `frontend`/`backend`/`cache` pods write logs to stdout (already configured,
   outside this repo).
2. kubelet persists stdout to node-local container log files.
3. Promtail (DaemonSet, one pod/node) tails those files, labels each line with
   pod/namespace/container metadata via k8s SD, ships to the in-cluster Loki
   service on port 3100.
4. Loki stores log streams (filesystem backend, ephemeral — no PVC).
5. Grafana (existing `kube-prometheus-stack` install) queries Loki through the new
   datasource; logs are viewable/queryable via Grafana Explore, filterable by
   `namespace="dev"`, `pod`, `container`, etc.

## Error handling / edge cases

- **Persistence**: `loki-stack`'s Loki subchart may default to requesting a PVC.
  This design explicitly disables persistence in `values.yaml` to avoid a dependency
  on a default `StorageClass` existing in the target cluster (e.g. minikube) and
  because log durability across restarts isn't a requirement for this sandbox.
- **Chart version drift**: pin an explicit `loki-stack` version in
  `logging/dev/kustomization.yaml` rather than floating latest, for reproducibility
  — same convention as the existing `kube-prometheus-stack` entry.
- **Apply ordering**: covered above (namespace-before-chart-resources).

## Verification

After applying:
- `kubectl get pods -n dev-monitoring` shows Loki and Promtail (one Promtail pod per
  node) `Running`.
- Grafana's datasource list (Configuration → Data sources) shows "Loki" as a healthy
  datasource.
- A live request through `frontend` → `backend` → `cache` produces log lines
  queryable in Grafana Explore filtered on `namespace="dev"`.

## Out of scope

- `.claude/skills/apply-cluster-dev/SKILL.md` currently only documents
  verification steps for the prometheus-stack half of `clusters/dev`. It should
  eventually be extended to also verify Loki/Promtail health, but that update is a
  separate, smaller follow-up and not part of this spec.
- No `prod` equivalent — consistent with the rest of this repo, only `dev` is
  built out.
- Log-based alerting, retention policies beyond chart defaults, and any
  Alloy-based collection are not part of this scope.
