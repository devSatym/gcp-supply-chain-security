#!/usr/bin/env bash
set -Eeuo pipefail

# Register the no-public-IP Azure VM as the repository's long-lived trusted
# runner. GitHub's registration token exists only in this process and in the
# encrypted Azure Run Command request; it is never added to Terraform, files,
# logs, GitHub secrets, or the runner service configuration.

REPOSITORY="devSatym/gcp-supply-chain-security"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
RUNNER_NAME="${AZURE_PRIVATE_RUNNER_NAME:-}"
RUNNER_LABELS="self-hosted,linux,x64,azure-private,azure-trusted"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is missing: $1"
}

[[ -n "$RESOURCE_GROUP" ]] || die "set AZURE_RESOURCE_GROUP to the Azure workload resource group"
[[ -n "$RUNNER_NAME" ]] || die "set AZURE_PRIVATE_RUNNER_NAME to the Terraform output private_runner_name"

require_command az
require_command gh
require_command jq

test "$(gh repo view "$REPOSITORY" --json nameWithOwner --jq .nameWithOwner)" = "$REPOSITORY" || die "GitHub CLI is not authorized for ${REPOSITORY}"
test "$(az vm show --resource-group "$RESOURCE_GROUP" --name "$RUNNER_NAME" --query 'powerState' -d -o tsv)" = "VM running" || die "private runner VM is not running"

nic_id="$(az vm show --resource-group "$RESOURCE_GROUP" --name "$RUNNER_NAME" --query 'networkProfile.networkInterfaces[0].id' -o tsv)"
public_ip="$(az network nic show --ids "$nic_id" --query 'ipConfigurations[0].publicIPAddress.id' -o tsv 2>/dev/null || true)"
[[ -z "$public_ip" ]] || die "refusing to register a runner VM with a public IP"

existing_runner="$(gh api "repos/${REPOSITORY}/actions/runners" --paginate --jq ".runners[] | select(.name == \"${RUNNER_NAME}\") | .name" 2>/dev/null || true)"
[[ -z "$existing_runner" ]] || die "a GitHub runner named ${RUNNER_NAME} is already registered; remove it deliberately before re-registering"

registration_token="$(gh api --method POST "repos/${REPOSITORY}/actions/runners/registration-token" --jq .token)"
[[ -n "$registration_token" ]] || die "GitHub did not return a runner registration token"
registration_token_b64="$(printf '%s' "$registration_token" | base64 -w 0)"

# The values below are all public coordinates. RUNNER_TOKEN is intentionally
# kept in a shell variable and the remote script suppresses command echoing.
remote_script=$(cat <<'REMOTE_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export DEBIAN_FRONTEND=noninteractive
RUNNER_TOKEN="$(printf '%s' '__REGISTRATION_TOKEN_B64__' | base64 -d)"
RUNNER_URL="https://github.com/__REPOSITORY__"
RUNNER_NAME="__RUNNER_NAME__"
RUNNER_LABELS="__RUNNER_LABELS__"

# The runner subnet intentionally permits only HTTPS. Convert the Ubuntu
# bootstrap sources before package installation so every package transport is
# encrypted; repository metadata and package signatures remain verified too.
find /etc/apt -type f \( -name 'sources.list' -o -name '*.sources' -o -name '*.list' \) -exec sed -i 's|http://|https://|g' {} +
# Some Azure regional Ubuntu mirrors can be temporarily unavailable. Fail over
# to Canonical's HTTPS archive before updating package metadata; both paths
# retain signed APT metadata and package signature verification.
if ! timeout 15 curl -4 -fsSI https://azure.archive.ubuntu.com/ubuntu/dists/noble/InRelease >/dev/null; then
  find /etc/apt -type f \( -name 'sources.list' -o -name '*.sources' -o -name '*.list' \) -exec sed -i 's|https://azure\.archive\.ubuntu\.com/ubuntu|https://archive.ubuntu.com/ubuntu|g' {} +
fi
apt-get update -qq
apt-get install -y -qq ca-certificates curl git gnupg jq docker.io unzip
systemctl enable --now docker

if ! id gha >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash gha
fi
usermod -aG docker gha

if ! command -v az >/dev/null 2>&1; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  chmod a+r /etc/apt/keyrings/microsoft.gpg
  printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ noble main' > /etc/apt/sources.list.d/azure-cli.list
  apt-get update -qq
  apt-get install -y -qq azure-cli
fi

if ! command -v kubectl >/dev/null 2>&1 || ! command -v kubelogin >/dev/null 2>&1; then
  az aks install-cli --install-location /usr/local/bin/kubectl --kubelogin-install-location /usr/local/bin/kubelogin
fi

if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  printf '%s\n' 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com noble main' > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -qq
  apt-get install -y -qq terraform
fi

install -d -o gha -g gha -m 0755 /opt/actions-runner
cd /opt/actions-runner
release_json="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest)"
runner_version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$release_json")"
asset_name="actions-runner-linux-x64-${runner_version}.tar.gz"
asset_url="$(jq -er --arg asset "$asset_name" '.assets[] | select(.name == $asset) | .browser_download_url' <<<"$release_json")"
asset_digest="$(jq -er --arg asset "$asset_name" '.assets[] | select(.name == $asset) | .digest // empty' <<<"$release_json")"
[[ "$asset_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'GitHub runner release did not provide a SHA-256 digest' >&2; exit 1; }
curl -fsSL "$asset_url" -o runner.tgz
echo "${asset_digest#sha256:}  runner.tgz" | sha256sum -c -
tar xzf runner.tgz
rm -f runner.tgz
chown -R gha:gha /opt/actions-runner
./bin/installdependencies.sh

install -m 0600 /dev/null /run/github-runner-registration-token
printf '%s' "$RUNNER_TOKEN" > /run/github-runner-registration-token
unset RUNNER_TOKEN
runuser -u gha -- env RUNNER_TOKEN="$(cat /run/github-runner-registration-token)" bash -lc 'cd /opt/actions-runner && ./config.sh --unattended --replace --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$RUNNER_LABELS" --work _work'
rm -f /run/github-runner-registration-token
./svc.sh install gha
./svc.sh start
systemctl --type=service --state=active --no-legend | grep -q 'actions.runner'
REMOTE_SCRIPT
)
remote_script="${remote_script//__REGISTRATION_TOKEN_B64__/$registration_token_b64}"
remote_script="${remote_script//__REPOSITORY__/$REPOSITORY}"
remote_script="${remote_script//__RUNNER_NAME__/$RUNNER_NAME}"
remote_script="${remote_script//__RUNNER_LABELS__/$RUNNER_LABELS}"

az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "$RUNNER_NAME" \
  --command-id RunShellScript \
  --scripts "$remote_script" \
  --query 'value[0].message' \
  --output tsv \
  | sed -E 's/[A-Za-z0-9_]{30,}/[redacted]/g'

runner_online=false
for _ in $(seq 1 12); do
  runner_status="$(gh api "repos/${REPOSITORY}/actions/runners" --paginate --jq ".runners[] | select(.name == \"${RUNNER_NAME}\") | .status" 2>/dev/null || true)"
  if [[ "$runner_status" == "online" ]]; then
    runner_online=true
    break
  fi
  sleep 5
done
[[ "$runner_online" == "true" ]] || die "Azure Run Command completed but ${RUNNER_NAME} is not online in GitHub"

printf 'Private runner %s registered for %s with labels: %s\n' "$RUNNER_NAME" "$REPOSITORY" "$RUNNER_LABELS"
