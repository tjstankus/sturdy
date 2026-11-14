"""Unit tests for protect_specs.py. Run: python3 -m unittest discover .claude/hooks"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "protect_specs.py")
SPEC = "test/acceptance/specs/planning_spec_test.exs"


class ProtectSpecsTest(unittest.TestCase):
    def setUp(self):
        self.project = tempfile.mkdtemp()
        os.makedirs(os.path.join(self.project, "test", "acceptance", "specs"))

    def decide(self, tool, tool_input):
        result = subprocess.run(
            [sys.executable, HOOK],
            input=json.dumps({"tool_name": tool, "tool_input": tool_input}),
            capture_output=True,
            text=True,
            env={**os.environ, "CLAUDE_PROJECT_DIR": self.project},
            check=True,
        )
        if not result.stdout:
            return "allow"
        return json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"]

    def bash(self, command):
        return self.decide("Bash", {"command": command})

    def test_file_tools_are_refused_inside_specs(self):
        for tool in ("Edit", "Write", "MultiEdit"):
            self.assertEqual(self.decide(tool, {"file_path": SPEC}), "deny", tool)
        absolute = os.path.join(self.project, SPEC)
        self.assertEqual(self.decide("Write", {"file_path": absolute}), "deny")
        sneaky = os.path.join(self.project, "test/support/../acceptance/specs/new_spec_test.exs")
        self.assertEqual(self.decide("Write", {"file_path": sneaky}), "deny")
        notebook = {"notebook_path": "test/acceptance/specs/x.ipynb"}
        self.assertEqual(self.decide("NotebookEdit", notebook), "deny")

    def test_file_tools_are_allowed_elsewhere(self):
        for path in ("test/support/acceptance/dsl.ex", "test/acceptance/README.md", "lib/sturdy.ex"):
            self.assertEqual(self.decide("Edit", {"file_path": path}), "allow", path)

    def test_shell_writes_to_specs_are_refused(self):
        for command in (
            f"sed -i '' 's/12/10/' {SPEC}",
            f"sed --in-place 's/a/b/' {SPEC}",
            f"echo x > {SPEC}",
            f"echo x >> {SPEC}",
            f"cat /dev/null | tee {SPEC}",
            f"rm {SPEC}",
            f"mv {SPEC} /tmp/x",
            f"cp /tmp/x {SPEC}",
            f"python3 -c 'open(\"{SPEC}\", \"w\")'",
            f"perl -pi -e 's/a/b/' {SPEC}",
            f"git checkout -- {SPEC}",
            f"git restore {SPEC}",
            "cd test/acceptance && sed -i '' 's/a/b/' specs/planning_spec_test.exs",
            f"find test/acceptance/specs -name '*.exs' -delete",
            f"mix format {SPEC}",
            f"cat {SPEC} && touch {SPEC}",
        ):
            self.assertEqual(self.bash(command), "deny", command)

    def test_shell_reads_of_specs_are_allowed(self):
        for command in (
            f"cat {SPEC}",
            f"grep -n plan {SPEC} | head -5",
            "ls test/acceptance/specs",
            f"git diff -- {SPEC}",
            f"git log --oneline -- {SPEC}",
            f"mix test {SPEC} 2>&1 | tail -3",
            f"STURDY_DRIVER=live_view mix acceptance {SPEC}",
            f"mix format --check-formatted {SPEC}",
            f"sed -n 1,20p {SPEC}",
            "find test/acceptance/specs -name '*.exs'",
        ):
            self.assertEqual(self.bash(command), "allow", command)

    def test_shell_commands_not_about_specs_are_untouched(self):
        for command in ("mix precommit", "rm -rf _build/test", "echo hi > /tmp/x"):
            self.assertEqual(self.bash(command), "allow", command)


if __name__ == "__main__":
    unittest.main()
