package infracost.policies.tagging

# GCP calls them "labels", not "tags" — same governance intent as the AWS
# blueprint's tagging.rego, adapted to GCP label keys/values (lowercase,
# no spaces).

required_labels := {
	"environment",
	"owner",
	"project",
	"cost_center",
}

labelable_resource_types := {
	"google_compute_instance",
	"google_compute_network",
	"google_compute_subnetwork",
	"google_container_cluster",
	"google_container_node_pool",
	"google_sql_database_instance",
	"google_storage_bucket",
}

resource_requires_labels(resource) if {
	labelable_resource_types[resource.type]
}

has_required_labels(resource) if {
	provided := {k | resource.change.after.labels[k]}
	missing := required_labels - provided
	count(missing) == 0
}

deny[msg] if {
	resource := input.resource_changes[_]
	resource_requires_labels(resource)
	not has_required_labels(resource)
	provided := {k | resource.change.after.labels[k]}
	missing := required_labels - provided
	msg := sprintf(
		"🏷️ Resource '%s' (%s) is missing required labels: %s",
		[resource.address, resource.type, concat(", ", missing)],
	)
}
