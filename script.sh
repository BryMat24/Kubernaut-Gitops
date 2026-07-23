#!/usr/bin/env bash

set -euo pipefail

KUSTOMIZE_DIR="./clusters/dev"

echo "========================================"
echo "Deploying Kustomize manifests..."
echo "Directory: ${KUSTOMIZE_DIR}"
echo "========================================"

kustomize build --enable-helm "${KUSTOMIZE_DIR}" | kubectl apply -f -

echo
echo "========================================"
echo "Deployment completed successfully!"
echo "========================================"