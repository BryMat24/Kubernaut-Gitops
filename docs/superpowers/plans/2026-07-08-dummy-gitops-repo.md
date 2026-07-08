# Dummy GitOps Sandbox Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold a dummy ArgoCD-style GitOps repo with two Kustomize apps and one Helm app, so it can later serve as a sandbox for an AI coding agent.

**Architecture:** Single-environment (`prod`) repo using the ArgoCD app-of-apps pattern. `apps/frontend` and `apps/api` are Kustomize apps (`base/` + `overlays/prod/`); `charts/worker` is a locally-authored Helm chart. `argocd/root-app.yaml` bootstraps three child Applications under `argocd/apps/`.

**Tech Stack:** Kustomize v5, Helm v3, ArgoCD `Application` CRD manifests (no live cluster required — everything is validated offline via `kustomize build` / `helm template`/`helm lint`).

## Global Constraints

- Single environment only: overlay/values name is `prod`; no dev/staging.
- All apps deploy to namespace `demo`.
- No external dependencies (no DBs, queues, secrets) — every app must be runnable standalone.
- Git remote for ArgoCD `repoURL` fields: `https://github.com/BryMat24/Kubernaut-Gitops.git`, `targetRevision: main`.
- Helm chart is authored locally (not a reference to an external chart repo).
- Every manifest must validate offline: `kustomize build` for Kustomize apps, `helm lint` + `helm template` for the chart, `python3 -c "import yaml; yaml.safe_load(...)"` for ArgoCD Application YAML.

---

### Task 1: Root README

**Files:**
- Create: `README.md`

**Interfaces:**
- Produces: the documented directory conventions (`argocd/`, `apps/<name>/base|overlays/prod`, `charts/<name>/`) that all later tasks must match exactly.

- [ ] **Step 1: Write `README.md`**

```markdown
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

\`\`\`bash
# Kustomize apps
kustomize build apps/frontend/overlays/prod
kustomize build apps/api/overlays/prod

# Helm chart
helm lint charts/worker
helm template charts/worker
\`\`\`

## Design & planning docs

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design spec and
implementation plan behind this scaffold.
```

- [ ] **Step 2: Verify it was written correctly**

Run: `test -f README.md && grep -c "^## " README.md`
Expected: `4` (four `##` sections: Layout, Apps, Validating changes locally, Design & planning docs)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add root README for GitOps sandbox repo"
```

---

### Task 2: frontend Kustomize app

**Files:**
- Create: `apps/frontend/base/deployment.yaml`
- Create: `apps/frontend/base/service.yaml`
- Create: `apps/frontend/base/configmap.yaml`
- Create: `apps/frontend/base/kustomization.yaml`
- Create: `apps/frontend/overlays/prod/kustomization.yaml`
- Create: `apps/frontend/overlays/prod/patch-replicas.yaml`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a buildable overlay at path `apps/frontend/overlays/prod` — this exact path is referenced by `argocd/apps/frontend.yaml` in Task 5.

- [ ] **Step 1: Write `apps/frontend/base/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
      volumes:
        - name: html
          configMap:
            name: frontend-html
```

- [ ] **Step 2: Write `apps/frontend/base/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
```

- [ ] **Step 3: Write `apps/frontend/base/configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
data:
  index.html: |
    <!DOCTYPE html>
    <html>
      <head><title>Kubernaut Dummy Frontend</title></head>
      <body>
        <h1>Kubernaut GitOps Sandbox</h1>
        <p>This is a placeholder frontend used for GitOps agent testing.</p>
      </body>
    </html>
```

- [ ] **Step 4: Write `apps/frontend/base/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
commonLabels:
  app.kubernetes.io/part-of: kubernaut-gitops
  app.kubernetes.io/component: frontend
```

- [ ] **Step 5: Write `apps/frontend/overlays/prod/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: demo
resources:
  - ../../base
patches:
  - path: patch-replicas.yaml
    target:
      kind: Deployment
      name: frontend
```

- [ ] **Step 6: Write `apps/frontend/overlays/prod/patch-replicas.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: frontend
          resources:
            requests:
              cpu: 20m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

- [ ] **Step 7: Validate the base builds**

Run: `kustomize build apps/frontend/base | grep -c "kind: "`
Expected: `3` (Deployment, Service, ConfigMap)

- [ ] **Step 8: Validate the prod overlay builds with patched replicas**

Run: `kustomize build apps/frontend/overlays/prod | grep -A1 "replicas:"`
Expected output includes `replicas: 2`

- [ ] **Step 9: Validate the namespace was applied**

Run: `kustomize build apps/frontend/overlays/prod | grep "namespace: demo" | wc -l`
Expected: a number `>= 1` (at least the Deployment carries `namespace: demo`)

- [ ] **Step 10: Commit**

```bash
git add apps/frontend
git commit -m "feat: add frontend Kustomize app (base + prod overlay)"
```

---

### Task 3: api Kustomize app

**Files:**
- Create: `apps/api/base/deployment.yaml`
- Create: `apps/api/base/service.yaml`
- Create: `apps/api/base/kustomization.yaml`
- Create: `apps/api/overlays/prod/kustomization.yaml`
- Create: `apps/api/overlays/prod/patch-replicas.yaml`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a buildable overlay at path `apps/api/overlays/prod` — referenced by `argocd/apps/api.yaml` in Task 5.

- [ ] **Step 1: Write `apps/api/base/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo:1.0
          args:
            - -text=hello from kubernaut api (base)
            - -listen=:5678
          ports:
            - containerPort: 5678
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 100m
              memory: 32Mi
```

- [ ] **Step 2: Write `apps/api/base/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
  labels:
    app: api
spec:
  selector:
    app: api
  ports:
    - port: 5678
      targetPort: 5678
```

- [ ] **Step 3: Write `apps/api/base/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
commonLabels:
  app.kubernetes.io/part-of: kubernaut-gitops
  app.kubernetes.io/component: api
```

- [ ] **Step 4: Write `apps/api/overlays/prod/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: demo
resources:
  - ../../base
patches:
  - path: patch-replicas.yaml
    target:
      kind: Deployment
      name: api
```

- [ ] **Step 5: Write `apps/api/overlays/prod/patch-replicas.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: api
          args:
            - -text=hello from kubernaut api (prod)
            - -listen=:5678
```

- [ ] **Step 6: Validate the base builds**

Run: `kustomize build apps/api/base | grep -c "kind: "`
Expected: `2` (Deployment, Service)

- [ ] **Step 7: Validate the prod overlay builds with patched replicas and text**

Run: `kustomize build apps/api/overlays/prod | grep -E "replicas:|hello from kubernaut api"`
Expected output includes `replicas: 2` and `- -text=hello from kubernaut api (prod)`

- [ ] **Step 8: Commit**

```bash
git add apps/api
git commit -m "feat: add api Kustomize app (base + prod overlay)"
```

---

### Task 4: worker Helm chart

**Files:**
- Create: `charts/worker/Chart.yaml`
- Create: `charts/worker/values.yaml`
- Create: `charts/worker/templates/_helpers.tpl`
- Create: `charts/worker/templates/deployment.yaml`
- Create: `charts/worker/templates/NOTES.txt`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a lintable/templatable chart at path `charts/worker` — referenced by `argocd/apps/worker.yaml` in Task 5. Exposes values `replicaCount`, `image.repository`, `image.tag`, `image.pullPolicy`, `intervalSeconds`, `resources`.

- [ ] **Step 1: Write `charts/worker/Chart.yaml`**

```yaml
apiVersion: v2
name: worker
description: Dummy background worker chart for GitOps agent sandbox testing
type: application
version: 0.1.0
appVersion: "1.0"
```

- [ ] **Step 2: Write `charts/worker/values.yaml`**

```yaml
replicaCount: 1

image:
  repository: busybox
  tag: "1.36"
  pullPolicy: IfNotPresent

intervalSeconds: 5

resources:
  requests:
    cpu: 10m
    memory: 16Mi
  limits:
    cpu: 50m
    memory: 32Mi
```

- [ ] **Step 3: Write `charts/worker/templates/_helpers.tpl`**

```
{{- define "worker.fullname" -}}
{{- .Release.Name }}-{{ .Chart.Name }}
{{- end -}}

{{- define "worker.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: kubernaut-gitops
app.kubernetes.io/component: worker
{{- end -}}
```

- [ ] **Step 4: Write `charts/worker/templates/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "worker.fullname" . }}
  labels:
    {{- include "worker.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Chart.Name }}
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: worker
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command:
            - sh
            - -c
            - |
              while true; do
                echo "processing job...";
                sleep {{ .Values.intervalSeconds }};
              done
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

- [ ] **Step 5: Write `charts/worker/templates/NOTES.txt`**

```
The worker chart has been deployed.

It runs a placeholder loop that logs "processing job..." every
{{ .Values.intervalSeconds }} seconds. This is a dummy background
worker with no real queue dependency, intended for GitOps sandbox
testing only.
```

- [ ] **Step 6: Lint the chart**

Run: `helm lint charts/worker`
Expected: `0 chart(s) failed` in the output

- [ ] **Step 7: Render the chart and verify content**

Run: `helm template test-worker charts/worker --namespace demo | grep -E "kind: Deployment|processing job|replicas:"`
Expected output includes `kind: Deployment`, `replicas: 1`, and the `echo "processing job...";` line

- [ ] **Step 8: Commit**

```bash
git add charts/worker
git commit -m "feat: add worker Helm chart"
```

---

### Task 5: ArgoCD app-of-apps manifests

**Files:**
- Create: `argocd/root-app.yaml`
- Create: `argocd/apps/frontend.yaml`
- Create: `argocd/apps/api.yaml`
- Create: `argocd/apps/worker.yaml`

**Interfaces:**
- Consumes: `apps/frontend/overlays/prod` (Task 2), `apps/api/overlays/prod` (Task 3), `charts/worker` (Task 4) as exact `spec.source.path` values.
- Produces: `argocd/apps/` as the directory `root-app.yaml` points its `spec.source.path` at.

- [ ] **Step 1: Write `argocd/root-app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/BryMat24/Kubernaut-Gitops.git
    targetRevision: main
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 2: Write `argocd/apps/frontend.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/BryMat24/Kubernaut-Gitops.git
    targetRevision: main
    path: apps/frontend/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 3: Write `argocd/apps/api.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/BryMat24/Kubernaut-Gitops.git
    targetRevision: main
    path: apps/api/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 4: Write `argocd/apps/worker.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: worker
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/BryMat24/Kubernaut-Gitops.git
    targetRevision: main
    path: charts/worker
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 5: Validate all four manifests parse as YAML and have the required fields**

Run:
```bash
python3 -c "
import yaml, sys
files = ['argocd/root-app.yaml', 'argocd/apps/frontend.yaml', 'argocd/apps/api.yaml', 'argocd/apps/worker.yaml']
for f in files:
    doc = yaml.safe_load(open(f))
    assert doc['kind'] == 'Application', f
    assert doc['spec']['source']['repoURL'] == 'https://github.com/BryMat24/Kubernaut-Gitops.git', f
    assert 'path' in doc['spec']['source'], f
    print(f, 'OK')
"
```
Expected: prints `OK` for all four files, no assertion errors

- [ ] **Step 6: Cross-check each child Application's path matches an existing directory**

Run:
```bash
python3 -c "
import yaml, os
paths = {
    'argocd/apps/frontend.yaml': 'apps/frontend/overlays/prod',
    'argocd/apps/api.yaml': 'apps/api/overlays/prod',
    'argocd/apps/worker.yaml': 'charts/worker',
}
for f, expected in paths.items():
    doc = yaml.safe_load(open(f))
    actual = doc['spec']['source']['path']
    assert actual == expected, f'{f}: expected {expected}, got {actual}'
    assert os.path.isdir(actual), f'{actual} does not exist'
    print(f, '->', actual, 'OK')
"
```
Expected: prints `OK` for all three mappings, no assertion errors

- [ ] **Step 7: Commit**

```bash
git add argocd
git commit -m "feat: add ArgoCD app-of-apps manifests"
```

---

## Self-Review Notes

- **Spec coverage:** README (spec's "Root README" section) → Task 1. frontend Kustomize app → Task 2. api Kustomize app → Task 3. worker Helm chart → Task 4. ArgoCD wiring/app-of-apps → Task 5. All spec sections have a corresponding task.
- **Placeholder scan:** no TBD/TODO; all file contents are complete and copy-pasteable.
- **Type/name consistency:** `apps/frontend/overlays/prod`, `apps/api/overlays/prod`, and `charts/worker` paths are identical between the tasks that create them (2, 3, 4) and the ArgoCD manifests that reference them (5), and Step 6 of Task 5 asserts this programmatically.
