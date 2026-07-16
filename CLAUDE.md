# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A GitOps manifest repository (Kustomize, no ArgoCD wiring currently present) for a sandbox
three-service HTTP call chain, built for `k8s_agent` integration test scenarios that need
application-level failures (crash, OOM, slow start, degrade-after-N, readiness failure) to
propagate across a real service boundary instead of being faked:

```
frontend  →  backend  →  cache
(edge)       (logic)     (terminal)
```

There is no application source code here — only Kubernetes manifests. The three services
(`brymat24/test-app-{frontend,backend,cache}:v1`) are pre-built images pulled from Docker Hub;
this repo only controls how they're deployed and wired together.

## Repository layout

- `app/<service>/base/` — raw Kustomize base per service (Deployment, Service, and for
  frontend/backend a ConfigMap holding `DOWNSTREAM_URL`, which is how each service's
  hardcoded HTTP client target is set). All three services listen on container port 8000,
  exposed via a ClusterIP Service on port 80.
- `app/<service>/overlays/dev/` — sets `namespace: dev` via the Kustomize `namespace:`
  transformer. Only `dev` overlays exist right now; there is no `prod` overlay for any
  service or cluster yet — don't assume one exists without checking first.
- `clusters/dev/` — the environment aggregator (app-of-apps style root). Its
  `kustomization.yaml` pulls in the namespace, all three `app/*/overlays/dev` trees, and
  `infrastructure/prometheus-stack/dev`. This is the single entry point for building/applying
  the whole `dev` environment.
- `infrastructure/prometheus-stack/dev/` — kube-prometheus-stack, deployed into namespace
  `dev-monitoring` via Kustomize's `helmCharts` generator (pulls the chart directly from the
  prometheus-community repo at apply time; `values.yaml` here is the stock upstream defaults
  file, not yet customized).

## Request wiring

`frontend-config`/`backend-config` ConfigMaps set `DOWNSTREAM_URL` to the next hop's Service
DNS name (`http://backend-service`, `http://cache-service`). Note the base ConfigMaps declare
`namespace: default`, but this is overridden at apply time by the overlay's `namespace: dev`
transformer — the base manifests are never applied standalone.

The frontend overlay additionally adds an nginx `Ingress` (`test-app.local` →
`frontend-service:80`) not present in the base.

## Applying the dev environment

`kubectl apply -k` cannot be used directly on `clusters/dev` — the Helm chart inflation for
`prometheus-stack` requires `--enable-helm`, which `apply -k` doesn't expose, and the
Prometheus Operator's CRDs are too large for client-side apply. There is a documented,
previously-diagnosed multi-step procedure (build with `kustomize build --enable-helm`,
server-side apply, restart the Operator once on a cold cluster, re-apply) captured in the
`apply-cluster-dev` skill at `.claude/skills/apply-cluster-dev/SKILL.md` — use that skill
rather than reconstructing the procedure from scratch, and read it before troubleshooting
errors like `no matches for kind X` or Prometheus/Alertmanager pods that never appear.

That skill currently only covers `clusters/dev`; there's no equivalent for a `prod` cluster
tree yet.
