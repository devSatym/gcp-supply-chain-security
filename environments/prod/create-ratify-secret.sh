#!/usr/bin/env bash
# create-ratify-secret.sh
#
# Creates the kubernetes.io/dockerconfigjson Secret that Ratify's k8Secrets
# authProvider reads for GAR authentication.
#
# Run this ONCE after `terraform apply`, and again after each key rotation.
# DO NOT commit this script's output or the key JSON to git.
#
# Prerequisites:
#   - kubectl context set to gke_stoked-citizen-455416-g4_europe-west1_prod-cluster
#   - terraform output available in environments/prod/
#   - gcloud impersonation active (terraform-ci SA) OR owner credentials
#
# Usage:
#   From environments/prod/:  ./create-ratify-secret.sh
#   From repo root:           TF_DIR=environments/prod ./create-ratify-secret.sh

set -euo pipefail

NAMESPACE="gatekeeper-system"
SECRET_NAME="ratify-gar-regcred"
REGISTRY="europe-west1-docker.pkg.dev"
TF_DIR="${TF_DIR:-.}"   # default to current dir; override via env if running from repo root

echo "==> Pulling key from Terraform state (sensitive output)..."
cd "${TF_DIR}"

KEY_JSON=$(terraform output -raw ratify_gar_reader_key_b64 | base64 --decode)

echo "==> Verifying key is valid JSON..."
echo "${KEY_JSON}" | python3 -m json.tool > /dev/null
echo "    OK"

echo "==> Creating/updating Secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
kubectl create secret docker-registry "${SECRET_NAME}" \
  --namespace="${NAMESPACE}" \
  --docker-server="${REGISTRY}" \
  --docker-username="_json_key" \
  --docker-password="${KEY_JSON}" \
  --docker-email="ratify-gar-reader@stoked-citizen-455416-g4.iam.gserviceaccount.com" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Verifying Secret exists..."
kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.metadata.name}: type={.type}, keys={.data}'
echo ""

echo "==> Clearing key from shell history..."
unset KEY_JSON

echo ""
echo "Done. Next steps:"
echo "  1. Deploy Ratify with --set oras.authProviders.k8secretsEnabled=true"
echo "  2. Reference secret in Store CRD (see policy/gatekeeper/store-oras.yaml)"
echo "  3. Set a 90-day rotation reminder for this key"
echo ""
echo "Key rotation command (when due):"
echo "  cd ${TF_DIR} && terraform apply -replace=google_service_account_key.ratify_gar_reader"
echo "  Then re-run this script."