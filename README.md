# Kubernaut GitOps Sandbox

Three FastAPI services wired as a real HTTP call chain, for `k8s_agent` integration test
scenarios that need application-level failures (crash, OOM, slow start, degrade-after-N,
readiness failure) to propagate across a real service boundary instead of being faked.

```
frontend  →  backend  →  cache
(edge)       (logic)     (terminal)
```

This is a manifests-only GitOps repo (Kustomize) — there's no application source code here,
just the Kubernetes wiring for pre-built images.

## Layout

```
app/<service>/base/            Deployment, Service, and (frontend/backend) a ConfigMap
                                holding DOWNSTREAM_URL, the next hop in the call chain
app/<service>/overlays/dev/    namespace: dev overlay (only env that exists so far)
clusters/dev/                  aggregator root — pulls in all three app overlays plus
                                the monitoring stack for the dev environment
infrastructure/prometheus-stack/dev/
                                kube-prometheus-stack, inflated from the upstream Helm
                                chart via Kustomize's helmCharts generator, namespace
                                dev-monitoring
```

Each service listens on container port 8000, exposed via a ClusterIP Service on port 80.
The frontend overlay also adds an nginx `Ingress` (`test-app.local` → `frontend-service`).

## Deploying to dev

`clusters/dev` can't be applied with a plain `kubectl apply -k` — the Helm chart inflation
needs `--enable-helm` (not exposed by `apply -k`), and the Prometheus Operator's CRDs are too
large for client-side apply. Build and apply explicitly:

```bash
kustomize build --enable-helm clusters/dev > /tmp/dev.yaml
kubectl apply --server-side --force-conflicts -f /tmp/dev.yaml
```

On a cluster that has never seen this tree before, the Prometheus/Alertmanager custom
resources will fail on the first apply (`no matches for kind ... ensure CRDs are installed
first`) because the Operator starts before its own CRDs are registered. Restart the Operator
once the CRDs exist, then re-apply:

```bash
kubectl rollout restart deployment/prometheus-kube-prometheus-operator -n dev-monitoring
kubectl apply --server-side --force-conflicts -f /tmp/dev.yaml
```

See `.claude/skills/apply-cluster-dev/SKILL.md` for the full procedure, verification steps,
and troubleshooting.
