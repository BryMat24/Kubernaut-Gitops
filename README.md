# Kubernaut GitOps Sandbox

This repository is a **dummy GitOps environment** used to build and test an AI coding
agent that assists with GitOps repo changes (patching manifests, editing Helm values,
adding overlays, etc.). It has no real production purpose.

## Layout

- `argocd/` — ArgoCD Application manifests, wired using the app-of-apps pattern.
  - `root-app.yaml` bootstraps everything by pointing at `argocd/apps/`.
  - `argocd/apps/*.yaml` — one Application per app below.
- `apps/` — Kustomize-managed apps, each with a `base/` and an `overlays/prod/`.
  - `apps/frontend/` — placeholder nginx web frontend.
  - `apps/api/` — placeholder HTTP echo API.
- `charts/` — Helm-managed apps.
  - `charts/worker/` — placeholder background worker chart.

## Apps

| App      | Managed by | Image                  | Purpose                            |
|----------|-----------|-------------------------|-------------------------------------|
| frontend | Kustomize | `nginx:1.27-alpine`     | Static placeholder web page         |
| api      | Kustomize | `hashicorp/http-echo`   | Canned JSON-ish HTTP responder      |
| worker   | Helm      | `busybox`               | Looping placeholder background job  |

All apps deploy to the `demo` namespace and have no real external dependencies
(no databases, queues, or secrets), so they can be applied to a scratch cluster
standalone if desired.

## Validating changes locally

```bash
# Kustomize apps
kustomize build apps/frontend/overlays/prod
kustomize build apps/api/overlays/prod

# Helm chart
helm lint charts/worker
helm template charts/worker
```

## Design & planning docs

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design spec and
implementation plan behind this scaffold.
