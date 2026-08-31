#!/usr/bin/env bash
set -Eeuo pipefail

# One-command Azure convergence. The production root is always initialized
# against the owner-provided Azure Blob backend; Terraform data, plans, logs,
# and provider files live only in the disposable directory created below.
#
# This wrapper intentionally does not bootstrap the backend. Terraform cannot
# use a backend while creating it, and silently falling back to local state
# would violate the remote-state contract. Run bootstrap-state once, then use
# this command for every subsequent convergence.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
PROD_SOURCE="${REPO_ROOT}/infrastructure/azure/environments/prod"
DEFAULT_VAR_FILE="${PROD_SOURCE}/terraform.tfvars"
DEFAULT_BACKEND_FILE="${REPO_ROOT}/infrastructure/azure/bootstrap-state/backend.hcl"

MODE="core"
DRY_RUN="false"
VAR_FILE="${DEFAULT_VAR_FILE}"
BACKEND_FILE=""
RUN_DIR=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/azure/apply-once.sh [--mode core|private] [--var-file PATH]
                              [--backend-config PATH] [--dry-run]

Modes:
  core     Private AKS plus Kyverno, Falco, Argo CD, and the Argo Application.
           ACR and optional alerting services stay authenticated but publicly
           reachable for hosted GitHub release jobs.
  private  Core plus Private Endpoints and a final, probed public-service
           closure. Requires PRIVATE_GITHUB_RUNNER_READY=true.

Inputs:
  --var-file PATH       Owner-supplied non-secret production tfvars. Defaults
                        to infrastructure/azure/environments/prod/terraform.tfvars.
  --backend-config PATH Owner-supplied azurerm backend config. If omitted, the
                        script uses TFSTATE_* variables (and .codex/azure-values.env
                        when present) without creating a backend file.
  --dry-run             Print the selected phases without contacting Azure or
                        requiring configuration files.

The remote backend must already exist. No local Terraform state, kubeconfig,
static Azure credential, public AKS fallback, or fake image release is created.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf 'INFO: %s\n' "$*"
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --mode)
        (($# >= 2)) || die "--mode requires core or private"
        MODE="$2"
        shift 2
        ;;
      --mode=*)
        MODE="${1#*=}"
        shift
        ;;
      --var-file)
        (($# >= 2)) || die "--var-file requires a path"
        VAR_FILE="$2"
        shift 2
        ;;
      --var-file=*)
        VAR_FILE="${1#*=}"
        shift
        ;;
      --backend-config)
        (($# >= 2)) || die "--backend-config requires a path"
        BACKEND_FILE="$2"
        shift 2
        ;;
      --backend-config=*)
        BACKEND_FILE="${1#*=}"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  case "$MODE" in
    core|private) ;;
    *) die "--mode must be core or private" ;;
  esac
}

cleanup() {
  if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]]; then
    rm -rf -- "$RUN_DIR"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is missing: $1"
}

load_local_owner_context() {
  # This ignored file is an owner-maintained convenience source for the
  # non-secret backend names. It is never printed and never written by this
  # script. Explicit shell environment values take precedence.
  if [[ -z "${TFSTATE_RESOURCE_GROUP_NAME:-}" && -f "${REPO_ROOT}/.codex/azure-values.env" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/.codex/azure-values.env"
  fi
}

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    realpath -m "${REPO_ROOT}/${path}"
  fi
}

build_backend_args() {
  local required
  if [[ -n "$BACKEND_FILE" ]]; then
    BACKEND_FILE="$(resolve_path "$BACKEND_FILE")"
    [[ -f "$BACKEND_FILE" ]] || die "backend config does not exist: $BACKEND_FILE"
    BACKEND_ARGS=("-backend-config=${BACKEND_FILE}")
    return
  fi

  if [[ -f "$DEFAULT_BACKEND_FILE" ]]; then
    BACKEND_FILE="$DEFAULT_BACKEND_FILE"
    BACKEND_ARGS=("-backend-config=${BACKEND_FILE}")
    return
  fi

  for required in TFSTATE_RESOURCE_GROUP_NAME TFSTATE_STORAGE_ACCOUNT_NAME TFSTATE_CONTAINER_NAME TFSTATE_KEY; do
    [[ -n "${!required:-}" ]] || die "remote backend is not configured; set ${required} or pass --backend-config"
  done

  BACKEND_ARGS=(
    "-backend-config=resource_group_name=${TFSTATE_RESOURCE_GROUP_NAME}"
    "-backend-config=storage_account_name=${TFSTATE_STORAGE_ACCOUNT_NAME}"
    "-backend-config=container_name=${TFSTATE_CONTAINER_NAME}"
    "-backend-config=key=${TFSTATE_KEY}"
    "-backend-config=use_azuread_auth=true"
  )
}

tfvar_bool() {
  local name="$1"
  local file="$2"
  awk -v name="$name" '
    $0 ~ "^[[:space:]]*" name "[[:space:]]*=" {
      value = $0
      sub("^[[:space:]]*" name "[[:space:]]*=[[:space:]]*", "", value)
      sub("[[:space:]#].*$", "", value)
      print tolower(value)
      exit
    }
  ' "$file"
}

assert_plan_safe() {
  local plan_json="$1"
  python3 - "$plan_json" <<'PY'
import json
import sys

plan = json.load(open(sys.argv[1], encoding="utf-8"))
replacements = []
deletes = []
for change in plan.get("resource_changes", []):
    actions = change.get("change", {}).get("actions", [])
    address = change.get("address", "unknown")
    if "delete" in actions:
        deletes.append((address, actions))
    if set(actions) == {"create", "delete"}:
        replacements.append((address, actions))

if deletes or replacements:
    print("plan contains a delete or replacement; refusing automatic apply", file=sys.stderr)
    for address, actions in (deletes + replacements)[:20]:
        print(f"  {address}: {actions}", file=sys.stderr)
    raise SystemExit(1)
PY
}

run_plan_and_apply() {
  local name="$1"
  shift
  local plan_file="${RUN_DIR}/${name}.tfplan"
  local plan_json="${RUN_DIR}/${name}.plan.json"
  local plan_log="${RUN_DIR}/${name}.plan.log"
  local apply_log="${RUN_DIR}/${name}.apply.log"

  info "planning ${name}"
  if ! terraform -chdir="$TF_ROOT" plan \
    -input=false \
    -no-color \
    -var-file="$VAR_FILE" \
    -out="$plan_file" \
    "$@" >"$plan_log" 2>&1; then
    die "Terraform plan failed for ${name}; no apply was attempted"
  fi
  terraform -chdir="$TF_ROOT" show -json "$plan_file" >"$plan_json"
  assert_plan_safe "$plan_json" || die "unsafe ${name} plan; no apply was attempted"

  info "applying saved ${name} plan"
  if ! terraform -chdir="$TF_ROOT" apply -input=false "$plan_file" >"$apply_log" 2>&1; then
    die "Terraform apply failed for ${name}; inspect Azure and remote state before rerunning"
  fi
}

read_output() {
  terraform -chdir="$TF_ROOT" output -raw "$1" 2>/dev/null || true
}

probe_host() {
  local label="$1"
  local endpoint="$2"
  local host="${endpoint#https://}"
  host="${host%%/*}"
  [[ -n "$host" && "$host" =~ ^[A-Za-z0-9.-]+$ ]] || die "${label} endpoint is not a valid hostname"

  if ! getent ahostsv4 "$host" >/dev/null 2>&1; then
    die "${label} private DNS lookup failed for ${host}"
  fi

  if command -v nc >/dev/null 2>&1; then
    nc -z -w 10 "$host" 443 >/dev/null 2>&1 || die "${label} port 443 is unreachable for ${host}"
  else
    timeout 10 bash -c ": </dev/tcp/${host}/443" >/dev/null 2>&1 || die "${label} port 443 is unreachable for ${host}"
  fi
}

probe_private_api() {
  local private_fqdn
  private_fqdn="$(read_output private_fqdn)"
  [[ -n "$private_fqdn" ]] || die "Terraform did not return the private AKS FQDN"
  [[ "$private_fqdn" == *privatelink* ]] || die "AKS output is not a private FQDN; refusing public fallback"
  probe_host "private AKS API" "$private_fqdn"
}

probe_private_service_endpoints() {
  local endpoint acr_name acr_data_endpoint

  endpoint="$(read_output acr_login_server)"
  [[ -n "$endpoint" ]] || die "Terraform did not return the ACR login server"
  probe_host "ACR registry" "$endpoint"

  acr_name="$(read_output acr_name)"
  [[ -n "$acr_name" ]] || die "Terraform did not return the ACR name"
  acr_data_endpoint="$(az acr show --name "$acr_name" --query 'dataEndpointHostNames[0]' -o tsv 2>/dev/null || true)"
  [[ -n "$acr_data_endpoint" ]] || die "ACR data endpoint is not available for private probing"
  probe_host "ACR data" "$acr_data_endpoint"

  if [[ "$RUNTIME_ALERTING_ENABLED" == "true" ]]; then
    endpoint="$(read_output key_vault_uri)"
    [[ -n "$endpoint" ]] || die "Terraform did not return the alerting Key Vault URI"
    probe_host "alerting Key Vault" "$endpoint"

    endpoint="$(read_output eventhub_namespace_fqdn)"
    [[ -n "$endpoint" ]] || die "Terraform did not return the Event Hubs FQDN"
    probe_host "alerting Event Hubs" "$endpoint"

    for output in function_storage_blob_endpoint function_storage_queue_endpoint function_storage_table_endpoint; do
      endpoint="$(read_output "$output")"
      [[ -n "$endpoint" ]] || die "Terraform did not return ${output}"
      probe_host "${output}" "$endpoint"
    done
  fi
}

print_safe_outputs() {
  local output value
  for output in resource_group_name private_fqdn acr_login_server registry_public_access_enabled private_endpoint_creation_enabled public_network_access_closure_enabled argocd_application_name argocd_application_release_status; do
    value="$(read_output "$output")"
    [[ -n "$value" ]] && printf '%s=%s\n' "$output" "$value"
  done
}

main() {
  parse_args "$@"

  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'dry-run: mode=%s\n' "$MODE"
    printf '%s\n' \
      'phase=remote-backend-init' \
      'phase=foundation-plan-apply' \
      'phase=private-aks-dns-and-443-probe' \
      'phase=addons-argocd-falco-plan-apply'
    [[ "$MODE" == "private" ]] && printf '%s\n' 'phase=private-endpoint-plan-apply-probe-closure-plan-apply'
    exit 0
  fi

  require_command terraform
  require_command az
  require_command python3
  require_command getent
  require_command realpath
  require_command timeout
  require_command kubelogin

  [[ -f "$VAR_FILE" ]] || die "production var-file does not exist: $VAR_FILE"
  VAR_FILE="$(resolve_path "$VAR_FILE")"

  if find "$PROD_SOURCE" -maxdepth 1 \( -type d -name .terraform -o -type f -name 'terraform.tfstate*' -o -type f -name '*.tfplan' \) -print -quit | grep -q .; then
    die "repository production root contains local Terraform data; remove it only through the documented recovery procedure"
  fi

  load_local_owner_context
  build_backend_args

  local subscription_id
  subscription_id="$(az account show --query id -o tsv 2>/dev/null || true)"
  [[ -n "$subscription_id" ]] || die "Azure CLI is not authenticated"
  if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" && "$AZURE_SUBSCRIPTION_ID" != "$subscription_id" ]]; then
    die "Azure CLI subscription does not match the owner-supplied AZURE_SUBSCRIPTION_ID"
  fi
  export ARM_SUBSCRIPTION_ID="$subscription_id"
  export ARM_USE_AZUREAD=true
  export ARM_USE_CLI=true

  RUNTIME_ALERTING_ENABLED="$(tfvar_bool enable_runtime_alerting "$VAR_FILE")"
  RUNTIME_ALERTING_ENABLED="${TF_VAR_enable_runtime_alerting:-${RUNTIME_ALERTING_ENABLED:-false}}"
  case "$RUNTIME_ALERTING_ENABLED" in
    true|false) ;;
    *) die "enable_runtime_alerting must be true or false" ;;
  esac
  if [[ "$RUNTIME_ALERTING_ENABLED" == "true" && -z "${TF_VAR_discord_webhook_url:-}" ]]; then
    die "alerting is enabled but TF_VAR_discord_webhook_url is not supplied"
  fi

  if [[ "$MODE" == "private" && "${PRIVATE_GITHUB_RUNNER_READY:-false}" != "true" && "${PRIVATE_AKS_RUNNER_READY:-false}" != "true" ]]; then
    die "private mode requires explicit PRIVATE_GITHUB_RUNNER_READY=true (or PRIVATE_AKS_RUNNER_READY=true)"
  fi

  RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/azure-apply-once.XXXXXX")"
  trap cleanup EXIT
  mkdir -p "${RUN_DIR}/tfdata"
  # Preserve the repository layout because child modules resolve the reviewed
  # policy and Argo files through path.module-relative paths.
  mkdir -p "${RUN_DIR}/infrastructure"
  cp -a "${REPO_ROOT}/infrastructure/azure" "${RUN_DIR}/infrastructure/azure"
  cp -a "${REPO_ROOT}/policy" "${RUN_DIR}/policy"
  cp -a "${REPO_ROOT}/argocd" "${RUN_DIR}/argocd"
  TF_ROOT="${RUN_DIR}/infrastructure/azure/environments/prod"
  export TF_DATA_DIR="${RUN_DIR}/tfdata"

  info "initializing the existing remote Azure Blob backend"
  terraform -chdir="$TF_ROOT" init -input=false -reconfigure "${BACKEND_ARGS[@]}" >/dev/null

  local state_addresses
  state_addresses="$(terraform -chdir="$TF_ROOT" state list 2>/dev/null || true)"
  if ! grep -Fxq 'module.aks.azurerm_kubernetes_cluster.main' <<<"$state_addresses"; then
    run_plan_and_apply foundation \
      -target=module.network \
      -target=module.aks \
      -target=module.supply_chain \
      -var='enable_workload_addons=false' \
      -var='enable_runtime_alerting=false' \
      -var='enable_private_endpoints=false' \
      -var='disable_public_network_access=false'
  fi

  probe_private_api

  run_plan_and_apply addons \
    -var='enable_workload_addons=true' \
    -var="enable_runtime_alerting=${RUNTIME_ALERTING_ENABLED}" \
    -var='enable_private_endpoints=false' \
    -var='disable_public_network_access=false'

  if [[ "$MODE" == "private" ]]; then
    run_plan_and_apply private-endpoints \
      -var='enable_workload_addons=true' \
      -var="enable_runtime_alerting=${RUNTIME_ALERTING_ENABLED}" \
      -var='enable_private_endpoints=true' \
      -var='disable_public_network_access=false'
    probe_private_service_endpoints
    run_plan_and_apply private-closure \
      -var='enable_workload_addons=true' \
      -var="enable_runtime_alerting=${RUNTIME_ALERTING_ENABLED}" \
      -var='enable_private_endpoints=true' \
      -var='disable_public_network_access=true'
  fi

  printf '\nInfrastructure converged with remote Terraform state.\n'
  printf 'The trusted main-branch image release is the next step; no placeholder workload was deployed.\n'
  print_safe_outputs
}

main "$@"
