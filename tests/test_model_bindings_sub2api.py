import contextlib
import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/model-bindings-sub2api.py"
CONFIG = Path(__file__).resolve().parents[1] / "config/model-bindings.json"
spec = importlib.util.spec_from_file_location("model_bindings_sub2api", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ModelBindingsSub2APITest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.key_file = Path(self.temp_dir.name) / "admin-key"
        self.key_file.write_text("test-key")
        self.key_file.chmod(0o600)
        config = json.loads(CONFIG.read_text())
        self.aliases = config["aliases"]
        self.legacy = config["legacy_aliases"]
        self.group = {
            "platform": "openai",
            "allow_messages_dispatch": True,
            "messages_dispatch_model_config": {
                "opus_mapped_model": self.aliases["claude-opus-5-5"],
                "sonnet_mapped_model": self.aliases["claude-sonnet-5"],
                "exact_model_mappings": {
                    **self.aliases,
                    **self.legacy,
                    "other-model": "other-upstream",
                },
            },
        }
        self.puts = []

    def request(self, _url, _key, method="GET", payload=None):
        if method == "PUT":
            self.puts.append(copy.deepcopy(payload))
            self.group["messages_dispatch_model_config"] = copy.deepcopy(
                payload["messages_dispatch_model_config"]
            )
        return copy.deepcopy(self.group)

    def run_helper(self, apply=False):
        arguments = [
            str(SCRIPT), "--config", str(CONFIG),
            "--key-file", str(self.key_file),
        ]
        if apply:
            arguments.append("--apply")
        output = io.StringIO()
        with patch.object(sys, "argv", arguments), patch.object(
            module, "app_url", return_value="http://127.0.0.1:8080"
        ), patch.object(module, "group_request", side_effect=self.request):
            with contextlib.redirect_stdout(output):
                module.main()
        return output.getvalue()

    def test_removes_redundant_and_legacy_mappings_only(self):
        plan = self.run_helper()
        self.assertIn("coding-fast", plan)
        self.assertEqual(self.puts, [])

        self.run_helper(apply=True)
        exact = self.group["messages_dispatch_model_config"]["exact_model_mappings"]
        self.assertEqual(
            exact,
            {
                **{key: value for key, value in self.aliases.items()
                   if key.startswith("claude-")},
                "other-model": "other-upstream",
            },
        )
        self.assertEqual(len(self.puts), 1)
        self.assertIn("already match", self.run_helper(apply=True))
        self.assertEqual(len(self.puts), 1)

    def test_refuses_to_remove_changed_mapping(self):
        self.group["messages_dispatch_model_config"]["exact_model_mappings"][
            "coding-fast"
        ] = "different-upstream"
        with self.assertRaisesRegex(RuntimeError, "coding-fast"):
            self.run_helper(apply=True)
        self.assertEqual(self.puts, [])


if __name__ == "__main__":
    unittest.main()
