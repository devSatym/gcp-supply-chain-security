# Azure Falco module

This module installs the same Falco modern-eBPF runtime detector used by the
GCP implementation, but sends optional alerts through Azure Event Hubs.

When all three Event Hubs inputs are supplied, the Falcosidekick chart creates
an AKS Workload Identity-enabled ServiceAccount and pod. The corresponding
managed identity and `Azure Event Hubs Data Sender` assignment are created by
the Azure Falco-alerting module. No Event Hubs connection string is used.

The Kubernetes and Helm providers must run from a host that can resolve and
reach the private AKS API endpoint.
