# Dummy GitOps Repo — Design

## Purpose

Scaffold a self-contained, realistic-looking GitOps repository (ArgoCD conventions) with a
mix of Kustomize and Helm-managed apps. This repo has no real production purpose — it exists
as a sandbox for building and testing a future AI coding agent that assists with GitOps
repo changes (patching manifests, editing Helm values, adding overlays, etc.).

## Scope decisions

- **GitOps tool convention:** ArgoCD, using the app-of-apps pattern.
- **Environments:** Single environment (`prod`). Kustomize apps still use a `base/` +
  `overlays/prod/` split, since that's the idiomatic structure an agent will encounter in
  real repos, even though only one overlay exists today.
- **Apps:** Three realistic-but-placeholder apps — two via Kustomize, one via a local Helm
  chart — to give the agent variety in editing surface (raw manifests + patches vs. chart
  templates + values).
- **Helm chart:** Authored locally in-repo (not a reference to an external chart), so the
  agent has a full editable surface (templates, helpers, values).
- **No real external dependencies:** no databases, queues, or secrets management — every
  app is runnable standalone if ever applied to a scratch cluster, but that's not required
  for this repo's purpose.

## Directory layout

```
Kubernaut-Gitops/
├── README.md
├── argocd/
│   ├── root-app.yaml              # app-of-apps: points at argocd/apps/
│   └── apps/
│       ├── frontend.yaml          # Application → apps/frontend/overlays/prod (Kustomize)
│       ├── api.yaml               # Application → apps/api/overlays/prod (Kustomize)
│       └── worker.yaml            # Application → charts/worker (Helm)
├── apps/
│   ├── frontend/
│   │   ├── base/                  # deployment.yaml, service.yaml, configmap.yaml, kustomization.yaml
│   │   └── overlays/prod/         # patch: replicas + resources, kustomization.yaml
│   └── api/
│       ├── base/                  # deployment.yaml, service.yaml, kustomization.yaml
│       └── overlays/prod/         # patch: replicas + echo message, kustomization.yaml
└── charts/
    └── worker/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── _helpers.tpl
            └── NOTES.txt
```

All three ArgoCD Applications target namespace `demo` in-cluster
(`https://kubernetes.default.svc`), with automated sync enabled (prune + selfHeal) since
this is a demo repo, not a real production gate.

## App details

### 1. frontend (Kustomize)

- Image: `nginx:1.27-alpine`
- Serves a static placeholder HTML page mounted from a ConfigMap
- ClusterIP Service on port 80
- Prod overlay patches: replicas → 2, adds resource requests/limits

### 2. api (Kustomize)

- Image: `hashicorp/http-echo`
- Returns a canned JSON-ish text message on port 5678
- ClusterIP Service on port 5678
- Prod overlay patches: replicas → 2, overrides the echo `-text` argument (simulates an
  env-specific config change)

### 3. worker (Helm chart)

- Image: `busybox`
- Runs a shell loop that logs `"processing job..."` every N seconds (simulates a background
  worker with no real queue dependency)
- No Service (not network-facing)
- Chart values expose: `replicaCount`, `image.repository`/`image.tag`, `intervalSeconds`

## Root README

Explains the repo's purpose (AI-agent sandbox), directory conventions, and how the three
apps are wired into ArgoCD via the app-of-apps root Application.

## Out of scope

- Actual deployment to a live cluster
- CI validation/linting pipelines
- Secrets management
- Multi-environment promotion workflows
