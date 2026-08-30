#!/usr/bin/env python3
"""Unit tests for the Discord notifier Azure Function payload.

The Azure Functions SDK is not installed for static validation, so the
azure.functions / azure.identity / azure.keyvault.secrets / requests
modules are stubbed before importing function_app.py. The tests lock the
security-relevant behavior of the relay:

  * a valid Falco event posts one Discord embed to the Key Vault webhook;
  * the webhook value is never written to logs;
  * events below MIN_PRIORITY are dropped;
  * malformed payloads are dropped;
  * a missing Key Vault configuration fails loudly without leaking values.

Run directly: python3 test_function_app.py
"""

import importlib.util
import logging
import os
import sys
import types
import unittest

MODULE_DIR = os.path.dirname(os.path.abspath(__file__))

# --- Minimal SDK stubs (installed before function_app is imported) ---

azure = types.ModuleType("azure")
azure_functions = types.ModuleType("azure.functions")
azure_identity = types.ModuleType("azure.identity")
azure_keyvault = types.ModuleType("azure.keyvault")
azure_keyvault_secrets = types.ModuleType("azure.keyvault.secrets")


class _FunctionApp:
    """Records decorated functions instead of wiring a real host."""

    def __init__(self):
        self.functions = {}

    def function_name(self, **kwargs):
        name = kwargs.get("name", "unnamed")

        def decorator(func_):
            self.functions[name] = func_
            return func_

        return decorator

    def event_hub_message_trigger(self, **kwargs):
        def decorator(func_):
            func_._trigger_settings = kwargs
            return func_

        return decorator


class EventHubEvent:
    def __init__(self, body: bytes):
        self._body = body

    def get_body(self) -> bytes:
        return self._body


azure_functions.FunctionApp = _FunctionApp
azure_functions.EventHubEvent = EventHubEvent


class DefaultAzureCredential:  # noqa: D101 - stub
    pass


class _SecretBundle:
    def __init__(self, value: str):
        self.value = value


class SecretClient:
    """Stub that returns the configured test secret and records reads."""

    configured_value = "https://discord.com/api/webhooks/REPLACE_ME"
    reads = []

    def __init__(self, vault_url: str, credential):
        self.vault_url = vault_url
        SecretClient.reads.append(vault_url)

    def get_secret(self, name: str) -> _SecretBundle:
        return _SecretBundle(SecretClient.configured_value)


class _StubResponse:
    status_code = 204

    def raise_for_status(self):
        return None


class RequestsStub:
    calls = []

    @staticmethod
    def post(url, json=None, timeout=None):  # noqa: A002 - mirrors requests API
        RequestsStub.calls.append({"url": url, "json": json, "timeout": timeout})
        return _StubResponse()


azure_identity.DefaultAzureCredential = DefaultAzureCredential
azure_keyvault_secrets.SecretClient = SecretClient
azure.functions = azure_functions
azure.identity = azure_identity
azure.keyvault = azure_keyvault
azure_keyvault.secrets = azure_keyvault_secrets

sys.modules.setdefault("azure", azure)
sys.modules.setdefault("azure.functions", azure_functions)
sys.modules.setdefault("azure.identity", azure_identity)
sys.modules.setdefault("azure.keyvault", azure_keyvault)
sys.modules.setdefault("azure.keyvault.secrets", azure_keyvault_secrets)
sys.modules.setdefault("requests", RequestsStub)

_spec = importlib.util.spec_from_file_location(
    "function_app_under_test", os.path.join(MODULE_DIR, "function_app.py")
)
function_app = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(function_app)


class DiscordNotifierTests(unittest.TestCase):
    SECRET = "https://discord.com/api/webhooks/example-secret-value"

    def setUp(self):
        RequestsStub.calls = []
        SecretClient.reads = []
        SecretClient.configured_value = self.SECRET
        function_app._webhook_url_cache = None
        os.environ["KEY_VAULT_URI"] = "https://example-kv.vault.azure.net/"
        os.environ["DISCORD_WEBHOOK_SECRET_NAME"] = "falco-discord-webhook-url"
        os.environ["MIN_PRIORITY"] = "warning"

    def tearDown(self):
        os.environ.pop("KEY_VAULT_URI", None)
        os.environ.pop("DISCORD_WEBHOOK_SECRET_NAME", None)
        os.environ.pop("MIN_PRIORITY", None)

    @staticmethod
    def _event(payload: bytes) -> EventHubEvent:
        return EventHubEvent(payload)

    def test_valid_event_posts_one_embed(self):
        alert = (
            b'{"rule": "Terminal shell in container", "priority": "critical",'
            b' "output": "shell spawned",'
            b' "output_fields": {"k8s.pod.name": "demo-pod",'
            b' "k8s.ns.name": "default", "container.name": "demo"}}'
        )
        with self.assertLogs(level="INFO") as logs:
            function_app.notify_discord(self._event(alert))

        self.assertEqual(len(RequestsStub.calls), 1)
        call = RequestsStub.calls[0]
        self.assertEqual(call["url"], self.SECRET)
        self.assertEqual(call["timeout"], 10)
        embed = call["json"]["embeds"][0]
        self.assertIn("Terminal shell in container", embed["title"])
        self.assertEqual(embed["fields"][1]["value"], "default")
        self.assertEqual(embed["fields"][2]["value"], "demo-pod")
        self.assertEqual(embed["color"], 14423100)  # critical
        joined = "\n".join(logs.output)
        self.assertNotIn(self.SECRET, joined)
        self.assertNotIn("webhooks/", joined)

    def test_priority_filter_drops_low_priority(self):
        alert = b'{"rule": "Noisy debug", "priority": "debug", "output": "x"}'
        with self.assertLogs(level="INFO"):
            function_app.notify_discord(self._event(alert))
        self.assertEqual(RequestsStub.calls, [])

    def test_unknown_priority_is_forwarded(self):
        alert = b'{"rule": "Weird", "priority": "bananas", "output": "x"}'
        with self.assertLogs(level="INFO"):
            function_app.notify_discord(self._event(alert))
        self.assertEqual(len(RequestsStub.calls), 1)

    def test_malformed_payload_is_dropped(self):
        with self.assertLogs(level="WARNING"):
            function_app.notify_discord(self._event(b"not-json{"))
        self.assertEqual(RequestsStub.calls, [])

    def test_missing_key_vault_config_fails_without_posting(self):
        os.environ.pop("KEY_VAULT_URI", None)
        alert = b'{"rule": "Shell", "priority": "critical", "output": "x"}'
        with self.assertRaises(KeyError):
            function_app.notify_discord(self._event(alert))
        self.assertEqual(RequestsStub.calls, [])

    def test_webhook_is_read_from_key_vault_exactly_once(self):
        alert = b'{"rule": "Shell", "priority": "critical", "output": "x"}'
        with self.assertLogs(level="INFO"):
            function_app.notify_discord(self._event(alert))
            function_app.notify_discord(self._event(alert))
        self.assertEqual(len(SecretClient.reads), 1)  # cached after first read
        self.assertEqual(len(RequestsStub.calls), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
