---
name: apply-cluster-dev
description: Applies the infra/clusters/dev Kustomize tree (app services + prometheus-stack monitoring) to a live Kubernetes cluster via the command line, handling the Helm-chart-inflation and Prometheus-Operator-CRD quirks this specific tree requires. Use this whenever the user asks to apply, deploy, provision, sync, or "get infra running" for clusters/dev, dev-monitoring, or the dev environment in this repo — including requests phrased as just "deploy the app to dev" or "spin up monitoring" without mentioning kustomize by name. Also use it to diagnose failures like "no matches for kind X", "resource mapping not found", "annotations too long", or Prometheus/Alertmanager pods that never appear after applying — these are the exact failure modes this skill exists to handle.
---

# Apply infra/clusters/dev

`infra/clusters/dev` is an app-of-apps Kustomize root: it aggregates the `backend`/`cache`/`frontend`
app overlays (namespace `dev`) and the `prometheus-stack` monitoring overlay (namespace
`dev-monitoring`, via a remote Helm chart). Applying it is **not** a single `kubectl apply -k`
command — that will fail. Three real, previously-diagnosed issues make this a multi-step
procedure. Understanding *why* each step exists means you can also diagnose future variations of
these failures instead of just replaying a fixed script.

## Why this isn't a one-liner

1. **`kubectl apply -k` cannot inflate the Helm chart.** The `prometheus-stack` overlay uses
   Kustomize's `helmCharts` generator to pull `kube-prometheus-stack` from its upstream repo.
   That generator only runs when the caller passes `--enable-helm` — a flag that exists on
   standalone `kustomize build` / `kubectl kustomize`, but is **not exposed** by `kubectl apply -k`
   or `kubectl apply -f`. There is no way to make `kubectl apply -k` work here; you must build
   first, then apply the rendered YAML.

2. **Client-side apply breaks on the Prometheus Operator's CRDs.** Plain `kubectl apply` stores
   the whole object in a `kubectl.kubernetes.io/last-applied-configuration` annotation. The
   Operator's CRDs (`prometheuses.monitoring.coreos.com`, `alertmanagers...`, etc.) have such large
   OpenAPI validation schemas that this annotation exceeds Kubernetes' 262144-byte limit, and the
   apply is rejected outright. Server-side apply (`--server-side`) doesn't use that annotation, so
   it doesn't hit the limit.

3. **The Operator only discovers installed CRDs once, at its own startup.** On a fresh cluster,
   the `prometheus-kube-prometheus-operator` Deployment and its CRDs land in the *same* apply
   batch. If the Operator's container starts running before the API server has finished
   registering those CRDs, it logs `resource "prometheuses" ... not installed in the cluster"` and
   permanently stops watching that resource type for the lifetime of that pod — it does not
   retry. The fix is a one-time restart of the Operator deployment once the CRDs actually exist,
   followed by a re-apply.

There's also a smaller, generic race: a custom resource (like the `Prometheus` or `Alertmanager`
object) can be submitted a moment before its own CRD is fully established by the API server, and
fail once with `no matches for kind X`. Re-running the apply resolves this — it's transient, not a
sign anything is actually wrong.

## Procedure

Run everything from the repo root. Confirm the kubectl context first — this tree is meant for a
local/dev cluster (in this repo's history, a `minikube` profile), not a shared/prod context:

```bash
kubectl config current-context
```

If that's not the cluster you mean to touch, stop and ask the user which context to use — don't
guess on something this mutating.

### 1. Build

```bash
kustomize build --enable-helm infra/clusters/dev > /tmp/dev.yaml
```

If this fails, it's almost always a Kustomize wiring problem (a stale path, a missing
`kustomization.yaml`, a resource ID collision from two overlays creating the same object) — not
something the apply step will fix. Read the error message; `kustomize build` errors are usually
precise about which file and which resource.

### 2. Apply (server-side)

```bash
kubectl apply --server-side --force-conflicts -f /tmp/dev.yaml
```

Always use `--server-side --force-conflicts` for this tree, never plain `kubectl apply` — see
point 2 above. `--force-conflicts` is safe here because this tree has a single owner; it just
means a re-apply won't get blocked arguing with itself over field ownership.

Expect to see some resources fail on the very first apply to a cluster that has never seen this
tree before — specifically `Prometheus`/`Alertmanager` custom resources with
`no matches for kind ... ensure CRDs are installed first`. That's expected on a cold start; keep
going to step 3 rather than treating it as a failure to report.

### 3. Restart the Operator (first apply to a cluster only)

Check whether the Operator missed the CRDs at its own startup:

```bash
kubectl logs -n dev-monitoring deployment/prometheus-kube-prometheus-operator --tail=30 | grep "not installed"
```

If that prints anything, the Operator started blind and needs a restart:

```bash
kubectl rollout restart deployment/prometheus-kube-prometheus-operator -n dev-monitoring
kubectl rollout status deployment/prometheus-kube-prometheus-operator -n dev-monitoring --timeout=90s
```

Skip this step entirely on a cluster where the tree has already been applied before and the
Operator has been running fine — restarting a healthy Operator is harmless but unnecessary.

### 4. Re-apply

```bash
kubectl apply --server-side --force-conflicts -f /tmp/dev.yaml
```

This picks up anything that failed in step 2 while the Operator was blind, and anything that lost
the CRD-establishment race. It should complete with no errors this time. If it doesn't, don't just
run it a third time hoping it clears — read the specific error, since a repeating failure past this
point is a real problem, not a race condition.

## Verify the end state

Don't declare success just because `kubectl apply` printed no errors — confirm things actually came
up:

```bash
# app services, namespace dev — expect 3/3 on each
kubectl rollout status deployment/backend-deployment -n dev --timeout=90s
kubectl rollout status deployment/cache-deployment -n dev --timeout=90s
kubectl rollout status deployment/frontend-deployment -n dev --timeout=90s

# monitoring stack, namespace dev-monitoring — expect Running/Ready
kubectl get pods -n dev-monitoring
kubectl get prometheus,alertmanager -n dev-monitoring
```

A healthy end state looks like:
- `backend-deployment`, `cache-deployment`, `frontend-deployment` all successfully rolled out in `dev`
- `prometheus-grafana`, `prometheus-kube-prometheus-operator`, `prometheus-kube-state-metrics`,
  `prometheus-prometheus-node-exporter` pods `Running` in `dev-monitoring`
- The Operator-managed StatefulSet pods
  `prometheus-prometheus-kube-prometheus-prometheus-0` and
  `alertmanager-prometheus-kube-prometheus-alertmanager-0` both `Running`/`Ready` (these only
  appear a short while *after* the `Prometheus`/`Alertmanager` custom resources are successfully
  reconciled — give it 30-60s after step 4 before concluding something's wrong if they're not there
  yet)

If a StatefulSet pod never appears after a minute or so, check the CR's status directly —
`kubectl describe prometheus <name> -n dev-monitoring` and the Operator's logs are the next place
to look, not another blind re-apply.

## Scope

This procedure currently only covers `infra/clusters/dev`. `infra/clusters/prod` and the
per-service `overlays/prod` directories are not fully built out yet as of this skill's writing —
don't assume the same aggregator pattern exists there without checking first.
