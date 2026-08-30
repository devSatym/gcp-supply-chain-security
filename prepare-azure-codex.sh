#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Azure configuration generator for:
# devSatym/gcp-supply-chain-security
#
# PURPOSE
# -------
# 1. Read REAL Azure subscription/tenant information from az CLI.
# 2. Reuse the previously proven AKS deployment profile:
#
#       Region       : eastus
#       VM SKU       : Standard_D2s_v7
#       Nodes        : 2
#       Networking   : Azure CNI Overlay
#
# 3. Generate deterministic Azure resource names.
# 4. Generate Codex context files:
#
#       .codex/azure-values.env
#       .codex/azure-context.md
#
# 5. Optionally start Codex with the generated context.
#
# IMPORTANT
# ---------
# - This script DOES NOT provision Azure resources.
# - This script DOES NOT create GitHub secrets.
# - This script DOES NOT invent Azure IDs.
# - This script DOES NOT run slow az vm list-skus checks.
# ============================================================


# ============================================================
# USER / PROJECT CONFIGURATION
# ============================================================

PROJECT_NAME="${PROJECT_NAME:-supply-chain-security}"
RESOURCE_PREFIX="${RESOURCE_PREFIX:-scs}"
AZURE_ENVIRONMENT="${AZURE_ENVIRONMENT:-dev}"

CANONICAL_GITHUB_REPOSITORY="devSatym/gcp-supply-chain-security"
TRUSTED_GITHUB_REF="refs/heads/main"


# ============================================================
# AZURE REGION
#
# Reuse previously successful Azure AKS deployment region.
# ============================================================

AZURE_LOCATION="${AZURE_LOCATION:-eastus}"
SHORT_LOCATION="eus"


# ============================================================
# AKS CONFIGURATION
#
# Previously validated combination:
#
#   eastus
#   2 x Standard_D2s_v7
#   Azure CNI Overlay
#
# Do NOT dynamically query every Azure VM SKU here.
# Terraform/Azure can report any current quota/SKU issue during
# actual deployment.
# ============================================================

AKS_SKU_TIER="${AKS_SKU_TIER:-Free}"

AKS_PRIVATE_CLUSTER="${AKS_PRIVATE_CLUSTER:-true}"

AKS_NODE_VM_SIZE="${AKS_NODE_VM_SIZE:-Standard_D2s_v7}"

AKS_NODE_COUNT="${AKS_NODE_COUNT:-2}"

# Keep fixed at 2 by default because the previous subscription
# profile had enough quota for 4 Dsv7 vCPUs:
#
# 2 nodes x 2 vCPU = 4 vCPU
#
# Codex may only change this if Azure gives evidence that the
# current subscription has different quota/capacity.
AKS_MIN_NODE_COUNT="${AKS_MIN_NODE_COUNT:-2}"
AKS_MAX_NODE_COUNT="${AKS_MAX_NODE_COUNT:-2}"

AKS_NODE_MAX_PODS="${AKS_NODE_MAX_PODS:-250}"


# ============================================================
# AKS NETWORKING
# ============================================================

AKS_NETWORK_PLUGIN="${AKS_NETWORK_PLUGIN:-azure}"
AKS_NETWORK_PLUGIN_MODE="${AKS_NETWORK_PLUGIN_MODE:-overlay}"

VNET_CIDR="${VNET_CIDR:-10.20.0.0/16}"
AKS_SUBNET_CIDR="${AKS_SUBNET_CIDR:-10.20.0.0/20}"

POD_CIDR="${POD_CIDR:-10.244.0.0/16}"

SERVICE_CIDR="${SERVICE_CIDR:-10.30.0.0/16}"
DNS_SERVICE_IP="${DNS_SERVICE_IP:-10.30.0.10}"


# ============================================================
# AZURE CONTAINER REGISTRY
# ============================================================

# Premium is intentional for this security-oriented project.
# It supports capabilities such as private networking that are
# relevant to the target Azure architecture.
ACR_SKU="${ACR_SKU:-Premium}"

IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-supply-chain-demo}"

ATTESTATION_REPOSITORY="${ATTESTATION_REPOSITORY:-supply-chain-security-attestations/supply-chain-demo}"


# ============================================================
# TERRAFORM REMOTE STATE
# ============================================================

TFSTATE_CONTAINER_NAME="${TFSTATE_CONTAINER_NAME:-tfstate}"

TFSTATE_KEY="${TFSTATE_KEY:-${PROJECT_NAME}/${AZURE_ENVIRONMENT}/terraform.tfstate}"

TFSTATE_REPLICATION="${TFSTATE_REPLICATION:-LRS}"


# ============================================================
# GITHUB OIDC
# ============================================================

GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com"

GITHUB_OIDC_AUDIENCE="api://AzureADTokenExchange"


# ============================================================
# HELPERS
# ============================================================

die() {
    echo
    echo "[ERROR] $*" >&2
    echo
    exit 1
}

info() {
    echo "[INFO] $*"
}

success() {
    echo "[OK] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || \
        die "Required command '$1' is not installed."
}


# ============================================================
# REQUIRED COMMANDS
# ============================================================

require_command az
require_command git
require_command sha256sum


# ============================================================
# VERIFY WE ARE INSIDE A GIT REPOSITORY
# ============================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "Run this script from inside the project Git repository."
fi


# ============================================================
# AZURE AUTHENTICATION
# ============================================================

info "Checking Azure CLI authentication..."

if ! az account show >/dev/null 2>&1; then

    echo
    echo "Azure CLI is not authenticated."
    echo
    echo "Run:"
    echo
    echo "    az login"
    echo
    echo "Then choose the correct subscription if necessary:"
    echo
    echo "    az account list -o table"
    echo
    echo "    az account set --subscription '<subscription-id-or-name>'"
    echo

    exit 1
fi


# ============================================================
# READ REAL AZURE ACCOUNT VALUES
# ============================================================

AZURE_SUBSCRIPTION_ID="$(
    az account show \
        --query id \
        -o tsv
)"

AZURE_SUBSCRIPTION_NAME="$(
    az account show \
        --query name \
        -o tsv
)"

AZURE_TENANT_ID="$(
    az account show \
        --query tenantId \
        -o tsv
)"

AZURE_ACCOUNT_NAME="$(
    az account show \
        --query user.name \
        -o tsv
)"

AZURE_ACCOUNT_TYPE="$(
    az account show \
        --query user.type \
        -o tsv
)"


[[ -n "$AZURE_SUBSCRIPTION_ID" ]] || \
    die "Could not determine Azure subscription ID."

[[ -n "$AZURE_TENANT_ID" ]] || \
    die "Could not determine Azure tenant ID."


success "Azure authentication found."

echo
echo "Azure account:"
echo "  Subscription : ${AZURE_SUBSCRIPTION_NAME}"
echo "  Account      : ${AZURE_ACCOUNT_NAME}"
echo "  Account type : ${AZURE_ACCOUNT_TYPE}"
echo "  Region       : ${AZURE_LOCATION}"
echo


# ============================================================
# DETERMINE CURRENT AZURE BOOTSTRAP PRINCIPAL
# ============================================================

BOOTSTRAP_PRINCIPAL_OBJECT_ID=""

BOOTSTRAP_PRINCIPAL_TYPE="$AZURE_ACCOUNT_TYPE"


if [[ "$AZURE_ACCOUNT_TYPE" == "user" ]]; then

    BOOTSTRAP_PRINCIPAL_OBJECT_ID="$(
        az ad signed-in-user show \
            --query id \
            -o tsv \
            2>/dev/null || true
    )"

elif [[ "$AZURE_ACCOUNT_TYPE" == "servicePrincipal" ]]; then

    BOOTSTRAP_PRINCIPAL_OBJECT_ID="$(
        az ad sp show \
            --id "$AZURE_ACCOUNT_NAME" \
            --query id \
            -o tsv \
            2>/dev/null || true
    )"

fi


if [[ -z "$BOOTSTRAP_PRINCIPAL_OBJECT_ID" ]]; then
    BOOTSTRAP_PRINCIPAL_OBJECT_ID="UNRESOLVED"
fi


# ============================================================
# DETECT CURRENT GITHUB REPOSITORY
# ============================================================

GIT_REMOTE="$(
    git config --get remote.origin.url \
        2>/dev/null || true
)"

DETECTED_REPOSITORY=""


if [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then

    GH_OWNER="${BASH_REMATCH[1]}"
    GH_REPO="${BASH_REMATCH[2]}"

    GH_REPO="${GH_REPO%.git}"

    DETECTED_REPOSITORY="${GH_OWNER}/${GH_REPO}"

fi


if [[ -z "$DETECTED_REPOSITORY" ]]; then

    warn "Could not detect a GitHub repository from origin remote."

    GITHUB_REPOSITORY="$CANONICAL_GITHUB_REPOSITORY"

else

    GITHUB_REPOSITORY="$DETECTED_REPOSITORY"

fi


GITHUB_OWNER="${GITHUB_REPOSITORY%%/*}"
GITHUB_REPO_NAME="${GITHUB_REPOSITORY##*/}"


# ============================================================
# WARN IF RUNNING AGAINST A DIFFERENT REPOSITORY
# ============================================================

if [[ "$GITHUB_REPOSITORY" != "$CANONICAL_GITHUB_REPOSITORY" ]]; then

    echo
    warn "Current repository differs from the expected canonical repository."
    echo
    echo "Detected:"
    echo "  ${GITHUB_REPOSITORY}"
    echo
    echo "Expected:"
    echo "  ${CANONICAL_GITHUB_REPOSITORY}"
    echo
    echo "The generated OIDC subject will use the DETECTED repository."
    echo

fi


# ============================================================
# GENERATE STABLE UNIQUE SUFFIX
#
# Same:
#   subscription + repo + environment
#
# produces the same value.
# ============================================================

UNIQUE_HASH="$(
    printf "%s" \
        "${AZURE_SUBSCRIPTION_ID}:${GITHUB_REPOSITORY}:${AZURE_ENVIRONMENT}" \
        | sha256sum \
        | cut -c1-8
)"


# ============================================================
# RESOURCE NAMES
# ============================================================

RESOURCE_GROUP_NAME="rg-${RESOURCE_PREFIX}-${AZURE_ENVIRONMENT}-${AZURE_LOCATION}"

AKS_CLUSTER_NAME="aks-${RESOURCE_PREFIX}-${AZURE_ENVIRONMENT}-${SHORT_LOCATION}"

VNET_NAME="vnet-${RESOURCE_PREFIX}-${AZURE_ENVIRONMENT}-${SHORT_LOCATION}"

AKS_SUBNET_NAME="snet-aks-${AZURE_ENVIRONMENT}"


# ------------------------------------------------------------
# ACR name requirements:
#
# - globally unique
# - lowercase
# - letters and numbers only
# ------------------------------------------------------------

ACR_NAME="${RESOURCE_PREFIX}${UNIQUE_HASH}"


# ------------------------------------------------------------
# Terraform backend resources
# ------------------------------------------------------------

TFSTATE_RESOURCE_GROUP_NAME="rg-${RESOURCE_PREFIX}-tfstate-${SHORT_LOCATION}"

TFSTATE_STORAGE_ACCOUNT_NAME="st${RESOURCE_PREFIX}${UNIQUE_HASH}"


# ------------------------------------------------------------
# GitHub -> Azure federated identity
# ------------------------------------------------------------

GITHUB_IDENTITY_NAME="id-${RESOURCE_PREFIX}-github-${AZURE_ENVIRONMENT}"

FEDERATED_CREDENTIAL_NAME="github-main"

GITHUB_OIDC_SUBJECT="repo:${GITHUB_REPOSITORY}:ref:${TRUSTED_GITHUB_REF}"


# ============================================================
# AZURE CLIENT ID
#
# Never invent one.
#
# If an Azure identity was already created:
#
#   export AZURE_CLIENT_ID="<real-client-id>"
#
# before running this script.
# ============================================================

AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-TO_BE_CREATED_BY_AZURE_BOOTSTRAP}"


if [[ "$AZURE_CLIENT_ID" == "TO_BE_CREATED_BY_AZURE_BOOTSTRAP" ]]; then

    GITHUB_OIDC_STATUS="NOT_CREATED"

else

    GITHUB_OIDC_STATUS="EXISTING_CLIENT_ID_PROVIDED"

fi


# ============================================================
# OPTIONAL DISCORD SECRET DETECTION
#
# Do not record the actual value.
# ============================================================

if [[ -n "${TF_VAR_discord_webhook_url:-}" ]]; then

    DISCORD_WEBHOOK_CONFIGURED="true"

else

    DISCORD_WEBHOOK_CONFIGURED="false"

fi


# ============================================================
# DISPLAY PROVEN AKS PROFILE
# ============================================================

info "Using previously validated AKS profile."

echo
echo "AKS:"
echo "  Region        : ${AZURE_LOCATION}"
echo "  VM SKU        : ${AKS_NODE_VM_SIZE}"
echo "  Nodes         : ${AKS_NODE_COUNT}"
echo "  Min nodes     : ${AKS_MIN_NODE_COUNT}"
echo "  Max nodes     : ${AKS_MAX_NODE_COUNT}"
echo "  Max pods/node : ${AKS_NODE_MAX_PODS}"
echo "  Networking    : Azure CNI Overlay"
echo


# ============================================================
# CREATE LOCAL CODEX DIRECTORY
# ============================================================

mkdir -p .codex


# ============================================================
# GENERATE ENV VALUES
# ============================================================

cat > .codex/azure-values.env <<EOF
# ==========================================================
# AUTO-GENERATED AZURE CONFIGURATION
#
# Generated for:
# ${GITHUB_REPOSITORY}
#
# DO NOT COMMIT THIS FILE.
# ==========================================================


# ----------------------------------------------------------
# Project
# ----------------------------------------------------------

PROJECT_NAME=${PROJECT_NAME}
RESOURCE_PREFIX=${RESOURCE_PREFIX}
AZURE_ENVIRONMENT=${AZURE_ENVIRONMENT}


# ----------------------------------------------------------
# Azure account
# ----------------------------------------------------------

AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}

AZURE_LOCATION=${AZURE_LOCATION}

AZURE_BOOTSTRAP_PRINCIPAL_TYPE=${BOOTSTRAP_PRINCIPAL_TYPE}
AZURE_BOOTSTRAP_PRINCIPAL_OBJECT_ID=${BOOTSTRAP_PRINCIPAL_OBJECT_ID}


# ----------------------------------------------------------
# Resource group
# ----------------------------------------------------------

AZURE_RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME}


# ----------------------------------------------------------
# AKS
# ----------------------------------------------------------

AKS_CLUSTER_NAME=${AKS_CLUSTER_NAME}

AKS_SKU_TIER=${AKS_SKU_TIER}

AKS_PRIVATE_CLUSTER=${AKS_PRIVATE_CLUSTER}

AKS_NODE_VM_SIZE=${AKS_NODE_VM_SIZE}

AKS_NODE_COUNT=${AKS_NODE_COUNT}

AKS_MIN_NODE_COUNT=${AKS_MIN_NODE_COUNT}
AKS_MAX_NODE_COUNT=${AKS_MAX_NODE_COUNT}

AKS_NODE_MAX_PODS=${AKS_NODE_MAX_PODS}


# ----------------------------------------------------------
# AKS networking
# ----------------------------------------------------------

AKS_NETWORK_PLUGIN=${AKS_NETWORK_PLUGIN}
AKS_NETWORK_PLUGIN_MODE=${AKS_NETWORK_PLUGIN_MODE}

VNET_NAME=${VNET_NAME}
VNET_CIDR=${VNET_CIDR}

AKS_SUBNET_NAME=${AKS_SUBNET_NAME}
AKS_SUBNET_CIDR=${AKS_SUBNET_CIDR}

AKS_POD_CIDR=${POD_CIDR}

AKS_SERVICE_CIDR=${SERVICE_CIDR}

AKS_DNS_SERVICE_IP=${DNS_SERVICE_IP}


# ----------------------------------------------------------
# ACR
# ----------------------------------------------------------

ACR_NAME=${ACR_NAME}
ACR_SKU=${ACR_SKU}

IMAGE_REPOSITORY=${IMAGE_REPOSITORY}

ATTESTATION_REPOSITORY=${ATTESTATION_REPOSITORY}


# ----------------------------------------------------------
# Terraform state
# ----------------------------------------------------------

TFSTATE_RESOURCE_GROUP_NAME=${TFSTATE_RESOURCE_GROUP_NAME}

TFSTATE_STORAGE_ACCOUNT_NAME=${TFSTATE_STORAGE_ACCOUNT_NAME}

TFSTATE_CONTAINER_NAME=${TFSTATE_CONTAINER_NAME}

TFSTATE_KEY=${TFSTATE_KEY}

TFSTATE_REPLICATION=${TFSTATE_REPLICATION}


# ----------------------------------------------------------
# GitHub
# ----------------------------------------------------------

GITHUB_REPOSITORY=${GITHUB_REPOSITORY}

GITHUB_OWNER=${GITHUB_OWNER}

GITHUB_REPO_NAME=${GITHUB_REPO_NAME}

TRUSTED_GITHUB_REF=${TRUSTED_GITHUB_REF}


# ----------------------------------------------------------
# GitHub OIDC
# ----------------------------------------------------------

GITHUB_OIDC_ISSUER=${GITHUB_OIDC_ISSUER}

GITHUB_OIDC_AUDIENCE=${GITHUB_OIDC_AUDIENCE}

GITHUB_OIDC_SUBJECT=${GITHUB_OIDC_SUBJECT}

GITHUB_IDENTITY_NAME=${GITHUB_IDENTITY_NAME}

FEDERATED_CREDENTIAL_NAME=${FEDERATED_CREDENTIAL_NAME}

AZURE_CLIENT_ID=${AZURE_CLIENT_ID}

GITHUB_OIDC_STATUS=${GITHUB_OIDC_STATUS}


# ----------------------------------------------------------
# Private AKS
# ----------------------------------------------------------

PRIVATE_AKS_RUNNER_REQUIRED=true


# ----------------------------------------------------------
# Optional integrations
# ----------------------------------------------------------

DISCORD_WEBHOOK_CONFIGURED=${DISCORD_WEBHOOK_CONFIGURED}
EOF


# ============================================================
# GENERATE CODEX IMPLEMENTATION CONTEXT
# ============================================================

cat > .codex/azure-context.md <<EOF
# Azure Supply-Chain Security Implementation Context

Repository:

\`${GITHUB_REPOSITORY}\`

This file contains authoritative user-supplied configuration for the Azure implementation.

---

# CRITICAL IMPLEMENTATION RULE

There is ALREADY Azure implementation work in this repository.

Do NOT restart the project from scratch.

Do NOT require a particular starting commit.

Do NOT reset or discard existing Azure work merely because another implementation would be cleaner.

Before modifying anything:

1. inspect the entire repository;
2. inspect all current Azure-specific files;
3. inspect Terraform;
4. inspect GitHub Actions;
5. inspect Kubernetes manifests;
6. inspect Kyverno / Gatekeeper / Ratify configuration;
7. inspect Falco / Falcosidekick integration;
8. inspect documentation and implementation notes;
9. determine what has already been completed;
10. continue from the strongest current implementation.

Prefer:

- reuse
- repair
- complete
- simplify
- validate

over rewriting everything.

---

# Azure Account

Subscription ID:

\`${AZURE_SUBSCRIPTION_ID}\`

Tenant ID:

\`${AZURE_TENANT_ID}\`

Environment:

\`${AZURE_ENVIRONMENT}\`

Region:

\`${AZURE_LOCATION}\`

Bootstrap principal type:

\`${BOOTSTRAP_PRINCIPAL_TYPE}\`

Bootstrap principal object ID:

\`${BOOTSTRAP_PRINCIPAL_OBJECT_ID}\`

These are real Azure values discovered from the user's authenticated Azure CLI session.

Do NOT invent another subscription or tenant.

---

# Previously Validated AKS Profile

Reuse this profile as the default unless Azure produces concrete evidence that the current subscription requires a change.

Region:

\`${AZURE_LOCATION}\`

VM SKU:

\`${AKS_NODE_VM_SIZE}\`

Node count:

\`${AKS_NODE_COUNT}\`

Minimum node count:

\`${AKS_MIN_NODE_COUNT}\`

Maximum node count:

\`${AKS_MAX_NODE_COUNT}\`

Max pods per node:

\`${AKS_NODE_MAX_PODS}\`

This deliberately reuses the previous successful Azure AKS combination:

\`eastus + 2 x Standard_D2s_v7\`

Do NOT perform expensive generic Azure SKU discovery unless actual deployment fails because of SKU/quota availability.

If Azure rejects this SKU or quota:

1. capture the actual Azure error;
2. inspect the current subscription quota;
3. choose the smallest reasonable compatible replacement;
4. document why it changed.

Do not guess preemptively.

---

# AKS

Cluster:

\`${AKS_CLUSTER_NAME}\`

SKU tier:

\`${AKS_SKU_TIER}\`

Private cluster:

\`${AKS_PRIVATE_CLUSTER}\`

Enable where compatible with the existing implementation:

- AKS managed identity
- Microsoft Entra integration
- Azure RBAC for Kubernetes
- AKS OIDC issuer
- Azure Workload Identity
- private API server

Do NOT introduce long-lived Azure credentials.

---

# AKS Networking

Use:

\`Azure CNI Overlay\`

network_plugin:

\`${AKS_NETWORK_PLUGIN}\`

network_plugin_mode:

\`${AKS_NETWORK_PLUGIN_MODE}\`

VNet:

\`${VNET_NAME}\`

VNet CIDR:

\`${VNET_CIDR}\`

AKS subnet:

\`${AKS_SUBNET_NAME}\`

AKS subnet CIDR:

\`${AKS_SUBNET_CIDR}\`

Pod CIDR:

\`${POD_CIDR}\`

Service CIDR:

\`${SERVICE_CIDR}\`

DNS service IP:

\`${DNS_SERVICE_IP}\`

Max pods per node:

\`${AKS_NODE_MAX_PODS}\`

These networks are deliberately non-overlapping.

Do not casually change them.

---

# Azure Resource Naming

Primary resource group:

\`${RESOURCE_GROUP_NAME}\`

Project:

\`${PROJECT_NAME}\`

Prefix:

\`${RESOURCE_PREFIX}\`

---

# Azure Container Registry

ACR:

\`${ACR_NAME}\`

Registry:

\`${ACR_NAME}.azurecr.io\`

SKU:

\`${ACR_SKU}\`

Application image repository:

\`${IMAGE_REPOSITORY}\`

Attestation repository:

\`${ATTESTATION_REPOSITORY}\`

Deployment must remain digest-based.

Expected form:

\`${ACR_NAME}.azurecr.io/${IMAGE_REPOSITORY}@sha256:...\`

Do NOT use mutable \`:latest\` deployment references.

---

# GitHub Repository

Repository:

\`${GITHUB_REPOSITORY}\`

Trusted release ref:

\`${TRUSTED_GITHUB_REF}\`

---

# GitHub -> Azure OIDC

OIDC issuer:

\`${GITHUB_OIDC_ISSUER}\`

OIDC audience:

\`${GITHUB_OIDC_AUDIENCE}\`

Federated subject:

\`${GITHUB_OIDC_SUBJECT}\`

Azure identity resource name:

\`${GITHUB_IDENTITY_NAME}\`

Federated credential name:

\`${FEDERATED_CREDENTIAL_NAME}\`

Azure client ID:

\`${AZURE_CLIENT_ID}\`

OIDC bootstrap status:

\`${GITHUB_OIDC_STATUS}\`

If AZURE_CLIENT_ID equals:

\`TO_BE_CREATED_BY_AZURE_BOOTSTRAP\`

then DO NOT invent a client ID.

Instead implement or reuse the project's Azure identity bootstrap process.

The final GitHub Actions authentication contract should use:

- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID

with:

\`azure/login\`

using GitHub OIDC.

Never introduce:

- Azure client secrets
- service-principal passwords
- long-lived credentials

unless the user explicitly changes the architecture.

---

# Terraform State

Terraform backend resource group:

\`${TFSTATE_RESOURCE_GROUP_NAME}\`

Storage account:

\`${TFSTATE_STORAGE_ACCOUNT_NAME}\`

Blob container:

\`${TFSTATE_CONTAINER_NAME}\`

State key:

\`${TFSTATE_KEY}\`

Replication:

\`${TFSTATE_REPLICATION}\`

Prefer Azure Blob backend authentication through Microsoft Entra.

Do not commit:

- terraform.tfstate
- terraform.tfstate.backup
- secret tfvars

---

# Cloud Translation

The existing GCP architecture should NOT be copied resource-for-resource.

Translate responsibilities appropriately.

## Compute / Kubernetes

GKE
->
AKS

## Container registry

Google Artifact Registry
->
Azure Container Registry

## CI federation

GCP Workload Identity Federation
->
GitHub Actions OIDC + Microsoft Entra federated credential

## Runtime identities

GCP service accounts
->
Azure managed identities / workload identities

## Permissions

GCP IAM
->
Azure RBAC

## Terraform backend

GCS
->
Azure Storage Blob

Preserve cloud-independent supply-chain components.

---

# Supply-Chain Security Pipeline

Preserve the project's security model.

Expected CI flow:

1. checkout
2. source/security validation
3. build image
4. push image to ACR
5. resolve immutable image digest
6. Trivy image scan
7. generate SPDX SBOM
8. Cosign keyless signature
9. attach SBOM attestation
10. generate SLSA provenance
11. attach provenance attestation
12. verify signature
13. verify attestations
14. update deployment using immutable digest
15. admission policy validates artifact
16. runtime security remains active

Do not weaken the existing supply-chain architecture just because the underlying cloud changed.

---

# Sigstore / Cosign

Keep keyless signing.

Do NOT replace keyless signing with manually managed private signing keys unless technically unavoidable and explicitly justified.

The trusted identity should continue being tied to the authorized GitHub workflow / branch identity.

---

# SBOM

Preserve SPDX SBOM generation.

The SBOM should correspond to the immutable image digest.

The admission layer should be able to require/verify the expected attestation where currently designed.

---

# SLSA Provenance

Preserve provenance generation and verification.

Do not claim provenance validation unless it is actually tested against the produced image.

---

# Kyverno

Preserve existing Kyverno supply-chain admission enforcement where already implemented.

Expected security checks may include:

- immutable digest required
- valid Cosign signature
- correct signing identity
- trusted GitHub workflow/ref
- SBOM attestation
- provenance attestation

Validate real negative cases.

Examples:

- unsigned image
- wrong digest
- wrong signing identity
- missing SBOM
- missing provenance
- unsigned init container
- mixed trusted/untrusted containers

Do not fabricate successful policy tests.

---

# Gatekeeper + Ratify

Preserve the existing Gatekeeper + Ratify implementation where currently present.

Translate registry references from GCP Artifact Registry to ACR.

Ratify should verify supply-chain artifacts corresponding to Azure Container Registry images.

Do not remove Gatekeeper/Ratify simply because Kyverno also exists unless the repository architecture explicitly decides one implementation is redundant.

If both exist intentionally as alternative/evaluation paths, keep that distinction clear.

---

# Falco Runtime Security

Keep Falco and Falcosidekick.

Admission security and runtime security solve different problems.

The architecture should remain conceptually:

Build
->
Sign / attest
->
Registry
->
Admission verification
->
AKS runtime
->
Falco detection

Keep a controlled runtime validation scenario, such as shell execution, where appropriate.

Do not fabricate Falco alerts.

---

# Private AKS

The AKS API server is intended to be private.

Therefore:

GitHub-hosted runners should NOT be assumed to have direct:

- kubectl
- helm
- Kubernetes API

access to the private AKS endpoint.

Cluster-side CI/CD operations need a runner or deployment mechanism with:

- VNet connectivity
- DNS resolution
- AKS API connectivity

Do NOT make AKS public merely because it makes GitHub Actions easier unless no reasonable private path exists and the user explicitly approves the architectural change.

PRIVATE_AKS_RUNNER_REQUIRED:

\`true\`

---

# ACR Authentication

Prefer Azure-native identity.

Use:

- managed identity
- workload identity
- Azure RBAC

where appropriate.

Avoid:

- ACR admin credentials
- username/password authentication
- static Docker registry passwords

unless required temporarily for explicit debugging.

---

# Discord / Alerting

Discord secret configured in current environment:

\`${DISCORD_WEBHOOK_CONFIGURED}\`

The webhook value is intentionally NOT written into this context.

If the repository uses:

\`TF_VAR_discord_webhook_url\`

or another secret path, preserve secret handling.

Never:

- print the webhook
- commit it
- write it into normal tfvars
- expose it in Terraform outputs
- expose it in workflow logs
- put a real value into README examples

---

# Secrets

Never commit:

- Azure credentials
- client secrets
- GitHub PATs
- Discord webhooks
- Terraform state
- kubeconfigs
- ACR credentials
- cloud access keys

Use existing secret mechanisms and GitHub Actions secrets where needed.

---

# Existing Azure Implementation

Before writing new files, search particularly for:

- infrastructure/azure/
- terraform/azure/
- environments/
- policy/azure/
- k8s/azure/
- kubernetes/azure/
- ratify/
- gatekeeper/
- kyverno/
- falco/
- .github/workflows/

The exact paths may differ.

Do not assume missing functionality simply because it is not in one expected folder.

Search the full repository first.

---

# Implementation Strategy

Proceed in this order.

## Phase 1 — Audit

Understand:

- current repository
- existing Azure work
- existing GCP implementation
- reusable cloud-independent pieces
- incomplete Azure pieces
- CI assumptions
- secrets/authentication contracts

## Phase 2 — Reconcile

Determine:

- what already works
- what should be reused
- what is broken
- what is missing
- what should be simplified

## Phase 3 — Terraform

Complete Azure infrastructure:

- Terraform backend
- resource groups
- networking
- AKS
- ACR
- managed identities
- Azure RBAC
- GitHub OIDC federation
- required private networking

## Phase 4 — Supply Chain

Complete:

- ACR workflow
- immutable digests
- Trivy
- SBOM
- Cosign
- attestations
- provenance

## Phase 5 — Admission

Complete and validate:

- Kyverno
- Gatekeeper
- Ratify

where required by the repository architecture.

## Phase 6 — Runtime

Complete:

- Falco
- Falcosidekick
- controlled runtime validation

## Phase 7 — GitHub Actions

Complete:

- PR security workflow
- trusted main workflow
- Azure OIDC login
- ACR build/push
- signing
- attestations
- deployment flow

## Phase 8 — Validation

Run real validation wherever credentials/infrastructure permit.

---

# Required Validation

At minimum validate locally or against Azure as appropriate:

- terraform fmt
- terraform validate
- terraform plan
- Helm rendering if Helm is used
- Kubernetes manifest validation
- GitHub workflow syntax/contracts
- policy configuration
- secret scanning

When Azure resources are available, validate:

- AKS provisioning
- node readiness
- ACR provisioning
- GitHub OIDC authentication
- ACR authentication
- image push
- digest resolution
- Trivy image scan
- Cosign signing
- SBOM generation
- SBOM attestation
- SLSA provenance
- provenance attestation
- Cosign verification
- admission allowed case
- admission rejected cases
- Falco runtime event

Do not claim tests were successful unless they actually ran successfully.

---

# Azure Capacity Rule

Start with:

Region:

\`eastus\`

Nodes:

\`2\`

SKU:

\`Standard_D2s_v7\`

Total worker VM vCPU:

\`4 vCPU\`

Do NOT automatically change back to:

\`centralindia + Standard_D2s_v5\`

The East US + D2s_v7 profile is intentional because it was previously used to work around Azure regional/SKU/quota constraints.

If this current subscription rejects D2s_v7, diagnose the actual current subscription quota instead of performing a huge generic SKU scan.

---

# Final Instruction

Treat this document as authoritative configuration supplied by the user.

Continue the existing Azure implementation.

Do NOT restart from scratch.

Do NOT require a specific Git commit.

Do NOT invent IDs, credentials, secrets, cloud resources, test results, or screenshots.

Inspect first.

Then implement.

Then validate as much as the actual environment allows.

For anything blocked by Azure quota, permissions, credentials, or private networking:

- capture the exact blocker;
- explain it clearly;
- continue implementing everything else that can be completed safely.
EOF


# ============================================================
# KEEP GENERATED FILES OUT OF GIT
# ============================================================

if [[ -d .git ]]; then

    touch .git/info/exclude

    grep -qxF ".codex/azure-values.env" .git/info/exclude \
        2>/dev/null || \
        echo ".codex/azure-values.env" >> .git/info/exclude

    grep -qxF ".codex/azure-context.md" .git/info/exclude \
        2>/dev/null || \
        echo ".codex/azure-context.md" >> .git/info/exclude

fi


# ============================================================
# FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo " AZURE CODEX CONFIGURATION GENERATED"
echo "============================================================"
echo

echo "Project"
echo "  Repository   : ${GITHUB_REPOSITORY}"
echo "  Environment  : ${AZURE_ENVIRONMENT}"
echo

echo "Azure"
echo "  Subscription : ${AZURE_SUBSCRIPTION_NAME}"
echo "  Region       : ${AZURE_LOCATION}"
echo

echo "AKS"
echo "  Cluster      : ${AKS_CLUSTER_NAME}"
echo "  VM SKU       : ${AKS_NODE_VM_SIZE}"
echo "  Nodes        : ${AKS_NODE_COUNT}"
echo "  Network      : Azure CNI Overlay"
echo

echo "ACR"
echo "  Registry     : ${ACR_NAME}.azurecr.io"
echo "  SKU          : ${ACR_SKU}"
echo

echo "Terraform state"
echo "  RG           : ${TFSTATE_RESOURCE_GROUP_NAME}"
echo "  Storage      : ${TFSTATE_STORAGE_ACCOUNT_NAME}"
echo "  Container    : ${TFSTATE_CONTAINER_NAME}"
echo "  Key          : ${TFSTATE_KEY}"
echo

echo "GitHub OIDC"
echo "  Repository   : ${GITHUB_REPOSITORY}"
echo "  Ref          : ${TRUSTED_GITHUB_REF}"
echo "  Subject      : ${GITHUB_OIDC_SUBJECT}"
echo "  Client ID    : ${AZURE_CLIENT_ID}"
echo

echo "Generated files:"
echo
echo "  .codex/azure-values.env"
echo "  .codex/azure-context.md"
echo

echo "No Azure resources were created."
echo "No secrets were generated."
echo "No VM SKU discovery query was executed."
echo


# ============================================================
# OPTIONAL: START CODEX
#
# Usage:
#
#   ./prepare-azure-codex.sh --codex
# ============================================================

if [[ "${1:-}" == "--codex" ]]; then

    require_command codex

    echo
    info "Starting Codex with generated Azure context..."
    echo

    codex "
Read .codex/azure-context.md completely before making any changes.

Treat .codex/azure-context.md as authoritative user-supplied Azure configuration.

IMPORTANT:

There is already Azure implementation work in this repository.

Do NOT restart from scratch.
Do NOT require a particular starting commit.
Do NOT discard existing implementation.

First inspect the ENTIRE repository and determine:

- what Azure implementation already exists,
- what is complete,
- what is partially implemented,
- what is broken,
- what is missing,
- what cloud-independent GCP supply-chain components can be reused.

Then immediately continue implementing the Azure version end-to-end.

Use the supplied Azure profile:

- region: eastus
- AKS VM: Standard_D2s_v7
- AKS nodes: 2
- Azure CNI Overlay

Do not perform huge generic VM SKU queries.

If the real Azure deployment rejects the VM SKU because of current quota,
capture the actual Azure error and diagnose that specific issue.

Do not invent:

- subscription IDs,
- tenant IDs,
- client IDs,
- secrets,
- Azure resources,
- GitHub secrets,
- deployment success,
- security test results,
- screenshots.

Reuse, repair, complete and validate the strongest existing implementation.
"

fi
