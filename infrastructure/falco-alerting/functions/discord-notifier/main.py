"""
Falco alert -> Discord notifier.

Triggered by Pub/Sub messages published by Falcosidekick. Filters by
priority so warning-and-above only, formats a readable Discord embed
with the rule, priority, and offending pod/container, and posts it via
a Discord incoming webhook fetched from Secret Manager (never a plain
env var).
"""

import base64
import json
import os

import functions_framework
from google.cloud import secretmanager
import requests

PRIORITY_ORDER = [
    "emergency", "alert", "critical", "error",
    "warning", "notice", "informational", "debug",
]

_webhook_url_cache = None


def _get_discord_webhook_url() -> str:
    global _webhook_url_cache
    if _webhook_url_cache:
        return _webhook_url_cache

    project_id = os.environ["GCP_PROJECT"]
    secret_name = os.environ["DISCORD_WEBHOOK_SECRET_NAME"]

    client = secretmanager.SecretManagerServiceClient()
    resource_name = f"projects/{project_id}/secrets/{secret_name}/versions/latest"
    response = client.access_secret_version(request={"name": resource_name})

    _webhook_url_cache = response.payload.data.decode("UTF-8").strip()
    return _webhook_url_cache


def _meets_min_priority(alert_priority: str) -> bool:
    min_priority = os.environ.get("MIN_PRIORITY", "warning").lower()
    try:
        return PRIORITY_ORDER.index(alert_priority.lower()) <= PRIORITY_ORDER.index(min_priority)
    except ValueError:
        # Unknown priority string - fail open so we don't silently drop alerts.
        return True


def _format_discord_message(alert: dict) -> dict:
    rule = alert.get("rule", "unknown rule")
    priority = alert.get("priority", "unknown")
    output = alert.get("output", "")
    output_fields = alert.get("output_fields", {})

    pod_name = output_fields.get("k8s.pod.name", "n/a")
    namespace = output_fields.get("k8s.ns.name", "n/a")
    container = output_fields.get("container.name", "n/a")

    # Discord embed colors are decimal, not hex strings.
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
                "title": f"\U0001F6A8 Falco alert: {rule}",
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


@functions_framework.cloud_event
def notify_discord(cloud_event):
    envelope = cloud_event.data.get("message", {})
    raw_data = envelope.get("data", "")

    if not raw_data:
        print("No data in Pub/Sub message, skipping.")
        return

    payload = base64.b64decode(raw_data).decode("utf-8")
    alert = json.loads(payload)

    priority = alert.get("priority", "warning")
    if not _meets_min_priority(priority):
        print(f"Alert priority '{priority}' below MIN_PRIORITY threshold, dropping.")
        return

    webhook_url = _get_discord_webhook_url()
    discord_message = _format_discord_message(alert)

    response = requests.post(webhook_url, json=discord_message, timeout=10)
    response.raise_for_status()
    print(f"Posted Falco alert to Discord: {alert.get('rule')}")
