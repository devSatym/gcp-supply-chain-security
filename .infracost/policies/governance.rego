package infracost.policies.governance

# -----------------------------------------------------------------------------
# Cost limits (monthly, USD) — GCP equivalents of the AWS blueprint's limits
# -----------------------------------------------------------------------------
cost_limits := {
	"google_compute_instance": 500,
	"google_sql_database_instance": 2000,
	"google_container_cluster": 200,
	"google_container_node_pool": 1000,
}

deny[msg] if {
	project := input.projects[_]
	resource := project.breakdown.resources[_]
	limit := cost_limits[resource.resourceType]
	monthly_cost := to_number(resource.monthlyCost)
	monthly_cost > limit
	msg := sprintf(
		"💰 Resource '%s' (%s) has a projected monthly cost of $%v, exceeding the $%v limit.",
		[resource.name, resource.resourceType, monthly_cost, limit],
	)
}

# -----------------------------------------------------------------------------
# Security policies
# -----------------------------------------------------------------------------

# Persistent disks / node pool disks must be encrypted with either
# Google-managed or customer-managed keys (GCP encrypts by default, but
# CMEK is required for regulated workloads — flag when explicitly disabled).
deny[msg] if {
	resource := input.resource_changes[_]
	resource.type == "google_compute_disk"
	resource.change.after.disk_encryption_key == null
	resource.change.after.require_csek_key_to_disk_encrypt == false
	msg := sprintf("🔒 Disk '%s' does not enforce customer-managed encryption keys.", [resource.address])
}

# Cloud SQL instances must not be publicly reachable.
deny[msg] if {
	resource := input.resource_changes[_]
	resource.type == "google_sql_database_instance"
	settings := resource.change.after.settings[_]
	ip_config := settings.ip_configuration[_]
	ip_config.ipv4_enabled == true
	not ip_config.require_ssl
	msg := sprintf("🔒 Cloud SQL instance '%s' is publicly reachable without enforced SSL.", [resource.address])
}

# GKE clusters must not expose the Kubernetes dashboard add-on.
deny[msg] if {
	resource := input.resource_changes[_]
	resource.type == "google_container_cluster"
	addons := resource.change.after.addons_config[_]
	addons.kubernetes_dashboard[_].disabled == false
	msg := sprintf("🔒 Cluster '%s' has the deprecated Kubernetes Dashboard add-on enabled.", [resource.address])
}

# GKE clusters should be VPC-native (alias IPs) not routes-based.
deny[msg] if {
	resource := input.resource_changes[_]
	resource.type == "google_container_cluster"
	not resource.change.after.ip_allocation_policy
	msg := sprintf("🔒 Cluster '%s' is not configured as VPC-native (missing ip_allocation_policy).", [resource.address])
}

# Large / oversized machine types trigger a warning-level cost review.
warn_instance_types := {
	"n2-standard-32",
	"n2-standard-64",
	"c2-standard-60",
}

deny[msg] if {
	resource := input.resource_changes[_]
	resource.type in {"google_compute_instance", "google_container_node_pool"}
	machine_type := object.get(resource.change.after, "machine_type", object.get(resource.change.after.node_config, "machine_type", ""))
	warn_instance_types[machine_type]
	msg := sprintf("⚠️ Resource '%s' uses large machine type '%s' — confirm this is intentional.", [resource.address, machine_type])
}

# Firewall rules must not allow unrestricted ingress on sensitive ports.
sensitive_ports := {"22", "3389", "5432", "3306", "6379"}

deny[msg] if {
	resource := input.resource_changes[_]
	resource.type == "google_compute_firewall"
	resource.change.after.direction == "INGRESS"
	"0.0.0.0/0" in resource.change.after.source_ranges
	allow := resource.change.after.allow[_]
	port := allow.ports[_]
	sensitive_ports[port]
	msg := sprintf("🔒 Firewall rule '%s' opens sensitive port %s to 0.0.0.0/0.", [resource.address, port])
}
