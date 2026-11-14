#!/usr/bin/env python3
"""PreToolUse guard: coding agents must not change the executable specifications.

The specs in test/acceptance/specs/ are owned by people (see
test/acceptance/README.md). This hook refuses:

  * file tools (Edit, Write, MultiEdit, NotebookEdit) aimed inside that directory;
  * shell commands that mention it, unless every part of the command is known
    to be read-only (cat, grep, git diff, mix acceptance, ...).

The shell check is an allowlist on purpose: anything it doesn't recognise as
read-only is refused. It's a guardrail against an agent "fixing" a spec, not
a security boundary; a determined process can always write files.
"""

import json
import os
import re
import shlex
import sys

SPECS = os.path.join("test", "acceptance", "specs")

# Mentions of the specs directory in a shell command.
MENTIONS = re.compile(r"acceptance\W+specs|_spec_test\.exs|acceptance.*\bspecs\b", re.S)

# Commands that only read, by name; some are read-only only without certain flags.
READ_ONLY = {
    "cat", "head", "tail", "less", "more", "grep", "rg", "ls", "wc", "diff",
    "file", "stat", "tree", "echo", "printf", "true", "cd", "pwd", "sort", "uniq",
    "cut", "awk", "nl", "column", "jq", "test", "[",
}
WRITING_FLAGS = {
    "sed": re.compile(r"^-(i|-in-place)"),
    "find": re.compile(r"^-(delete|exec|execdir|ok|okdir|fprint|fprintf|fls)$"),
    "awk": re.compile(r"^-i"),
}
READ_ONLY_GIT = {"diff", "log", "show", "status", "blame", "grep", "ls-files"}
READ_ONLY_MIX = {"test", "acceptance", "format"}

# Output redirection to a file (not 2>&1-style descriptor duplication).
REDIRECT = re.compile(r"(?<![0-9&])>>?(?!&)|[0-9]>>?(?!&)|&>")


def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def inside_specs(path, project):
    specs = os.path.realpath(os.path.join(project, SPECS))
    target = os.path.realpath(os.path.join(project, os.path.expanduser(path)))
    return target == specs or target.startswith(specs + os.sep)


def read_only_segment(words):
    if not words:
        return True
    command, args = os.path.basename(words[0]), words[1:]
    if command == "git":
        return bool(args) and args[0] in READ_ONLY_GIT
    if command == "mix":
        # `mix format` rewrites files; only its --check-formatted form only reads.
        if args[:1] == ["format"]:
            return "--check-formatted" in args
        return bool(args) and args[0] in READ_ONLY_MIX
    if command in WRITING_FLAGS:
        if any(WRITING_FLAGS[command].match(arg) for arg in args):
            return False
        return True
    return command in READ_ONLY


def shell_reason(command):
    if not MENTIONS.search(command):
        return None
    if REDIRECT.search(command) or re.search(r"\btee\b", command):
        return "writes to a file in a command that touches the specs"
    for segment in re.split(r"&&|\|\||[;|\n]", command):
        try:
            words = shlex.split(segment)
        except ValueError:
            return "could not parse the command"
        # Leading VAR=value assignments don't change what runs.
        while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            words = words[1:]
        if not read_only_segment(words):
            return f"`{segment.strip()}` is not known to be read-only"
    return None


def main():
    event = json.load(sys.stdin)
    tool = event.get("tool_name", "")
    tool_input = event.get("tool_input", {})
    project = os.environ.get("CLAUDE_PROJECT_DIR") or event.get("cwd") or os.getcwd()
    rule = (
        "test/acceptance/specs/ holds the human-owned executable specifications; "
        "agents may change the DSL, drivers, and production code, never the specs. "
        "If a spec looks wrong, stop and ask its owner."
    )

    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
        if path and inside_specs(path, project):
            deny(f"Refused: {rule}")
    elif tool == "Bash":
        reason = shell_reason(tool_input.get("command", ""))
        if reason:
            deny(f"Refused ({reason}): {rule}")


if __name__ == "__main__":
    main()
