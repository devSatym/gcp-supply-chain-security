"""Falco Event Hub alert -> Discord notifier for Azure Functions Python v2.

The Function receives the Falcosidekick JSON payload from Event Hubs, filters
by Falco priority, retrieves the Discord webhook at runtime from Key Vault with
its managed identity, and posts an equivalent Discord embed. No connection
string or Discord secret is stored in source, Terraform state, or an app
setting.
"""

import json
import logging
import os

import azure.functions as func
import requests
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

app = func.FunctionApp()

PRIORITY_ORDER = [
    "emergency", "alert", "critical", "error",
    "warning", "notice", "informational", "debug",
]

_webhook_url_cache: str | None = None


def _get_discord_webhook_url() -> str:
    """Resolve and cache the webhook using the Function system identity."""
    global _webhook_url_cache
    if _webhook_url_cache:
        return _webhook_url_cache

    vault_uri = os.environ["KEY_VAULT_URI"]
    secret_name = os.environ["DISCORD_WEBHOOK_SECRET_NAME"]
    client = SecretClient(vault_url=vault_uri, credential=DefaultAzureCredential())
    _webhook_url_cache = client.get_secret(secret_name).value.strip()
    return _webhook_url_cache


def _meets_min_priority(alert_priority: str) -> bool:
    min_priority = os.environ.get("MIN_PRIORITY", "warning").lower()
    try:
        return PRIORITY_ORDER.index(alert_priority.lower()) <= PRIORITY_ORDER.index(min_priority)
    except ValueError:
        # Unknown priorities are forwarded rather than silently discarded.
        return True


def _format_discord_message(alert: dict) -> dict:
    rule = alert.get("rule", "unknown rule")
    priority = alert.get("priority", "unknown")
    output = alert.get("output", "")
    output_fields = alert.get("output_fields", {})

    pod_name = output_fields.get("k8s.pod.name", "n/a")
    namespace = output_fields.get("k8s.ns.name", "n/a")
    container = output_fields.get("container.name", "n/a")

    color_by_priority = {
        "emergency": 9109643,
        "alert": 11674146,
        "critical": 14423100,
        "error": 16729344,
        "warning": 16753920,
    }

    return {
        "embeds": [
            {
                "title": f"🚨 Falco alert: {rule}",
                "description": output,
                "color": color_by_priority.get(priority.lower(), 8421504),
                "fields": [
                    {"name": "Priority", "value": priority, "inline": True},
                    {"name": "Namespace", "value": namespace, "inline": True},
                    {"name": "Pod", "value": pod_name, "inline": True},
                    {"name": "Container", "value": container, "inline": True},
                ],
            }
        ]
    }


@app.function_name(name="notify_discord")
@app.event_hub_message_trigger(
    arg_name="event",
    event_hub_name="%EVENT_HUB_NAME%",
    connection="EventHubConnection",
    cardinality="one",
)
def notify_discord(event: func.EventHubEvent) -> None:
    """Forward one Falcosidekick Event Hubs message to Discord."""
    try:
        alert = json.loads(event.get_body().decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        logging.warning("Ignoring malformed Falco Event Hubs payload: %s", exc)
        return

    priority = alert.get("priority", "warning")
    if not _meets_min_priority(priority):
        logging.info("Dropping Falco alert below configured priority: %s", priority)
        return

    response = requests.post(
        _get_discord_webhook_url(),
        json=_format_discord_message(alert),
        timeout=10,
    )
    response.raise_for_status()
    logging.info("Posted Falco alert to Discord: %s", alert.get("rule", "unknown"))
