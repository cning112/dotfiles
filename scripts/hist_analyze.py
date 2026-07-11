#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Analyze local shell history and suggest evidence-backed workflow improvements."""

from __future__ import annotations

import argparse
import re
import shlex
import sqlite3
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


DAY_NS = 86_400 * 1_000_000_000
DEFAULT_DB = Path.home() / ".local" / "share" / "atuin" / "history.db"
DEFAULT_ALIASES = Path.home() / ".aliases"
PREFIX_COMMANDS = {"command", "env", "sudo"}
SUDO_OPTIONS_WITH_VALUES = {
    "-C",
    "-D",
    "-R",
    "-T",
    "-g",
    "-h",
    "-p",
    "-u",
    "--chdir",
    "--chroot",
    "--close-from",
    "--command-timeout",
    "--group",
    "--host",
    "--other-user",
    "--prompt",
    "--role",
    "--type",
    "--user",
}
ENV_OPTIONS_WITH_VALUES = {
    "-C",
    "-S",
    "-a",
    "-u",
    "--argv0",
    "--chdir",
    "--split-string",
    "--unset",
}
KNOWN_SUBCOMMANDS = {
    "atuin": {"config", "doctor", "history", "import", "search", "stats", "sync"},
    "brew": {
        "autoremove",
        "bundle",
        "cleanup",
        "doctor",
        "info",
        "install",
        "list",
        "search",
        "services",
        "tap",
        "uninstall",
        "untap",
        "update",
        "upgrade",
    },
    "cargo": {
        "add",
        "bench",
        "build",
        "check",
        "clean",
        "clippy",
        "doc",
        "fmt",
        "init",
        "install",
        "new",
        "publish",
        "remove",
        "run",
        "test",
        "tree",
        "uninstall",
        "update",
    },
    "docker": {"build", "compose", "exec", "images", "logs", "ps", "pull", "run"},
    "gh": {"api", "auth", "issue", "pr", "release", "repo", "run", "workflow"},
    "git": {
        "add",
        "branch",
        "checkout",
        "cherry-pick",
        "clean",
        "clone",
        "commit",
        "diff",
        "fetch",
        "grep",
        "init",
        "log",
        "merge",
        "mv",
        "pull",
        "push",
        "rebase",
        "reset",
        "restore",
        "revert",
        "rm",
        "show",
        "stash",
        "status",
        "switch",
        "tag",
        "worktree",
    },
    "helm": {
        "dependency",
        "get",
        "history",
        "install",
        "list",
        "repo",
        "test",
        "uninstall",
        "upgrade",
    },
    "kubectl": {
        "apply",
        "config",
        "create",
        "delete",
        "describe",
        "exec",
        "get",
        "logs",
        "rollout",
    },
    "npm": {
        "ci",
        "exec",
        "init",
        "install",
        "publish",
        "run",
        "test",
        "uninstall",
        "update",
    },
    "pnpm": {"add", "exec", "install", "publish", "remove", "run", "test", "update"},
    "uv": {
        "add",
        "build",
        "cache",
        "export",
        "init",
        "lock",
        "publish",
        "remove",
        "run",
        "sync",
        "tool",
        "tree",
        "venv",
    },
    "yarn": {"add", "dlx", "install", "remove", "run", "test", "upgrade"},
}
ALTERNATIVES = {
    "curl": "xh",
    "dig": "doggo",
    "find": "fd",
    "grep": "rg",
    "sed": "sd",
}
SENSITIVE_MARKERS = (
    "auth",
    "cookie",
    "credential",
    "header",
    "key",
    "password",
    "secret",
    "token",
)


@dataclass(frozen=True)
class HistoryEntry:
    command: str
    duration_ns: int
    exit_code: int


def load_aliases(path: Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {}
    aliases: dict[str, list[str]] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = re.match(r"^\s*alias\s+([^=\s]+)=(.+)$", line)
        if not match or any(operator in match.group(2) for operator in (";", "|")):
            continue
        try:
            quoted_value = shlex.split(match.group(2))
            expansion = shlex.split(quoted_value[0]) if quoted_value else []
        except ValueError:
            continue
        if expansion:
            aliases[match.group(1)] = expansion
    return aliases


def command_family(command: str, aliases: dict[str, list[str]]) -> str | None:
    try:
        words = shlex.split(command, comments=True)
    except ValueError:
        words = command.split()

    while words and (
        words[0] in PREFIX_COMMANDS or re.match(r"^[A-Za-z_]\w*=", words[0])
    ):
        prefix = words.pop(0)
        if prefix == "sudo":
            while words and words[0].startswith("-"):
                option = words.pop(0)
                if option in SUDO_OPTIONS_WITH_VALUES and words:
                    words.pop(0)
        elif prefix == "env":
            while words and words[0].startswith("-"):
                option = words.pop(0)
                if option == "--":
                    break
                if (
                    option.split("=", 1)[0] in ENV_OPTIONS_WITH_VALUES
                    and "=" not in option
                    and words
                ):
                    words.pop(0)
        elif prefix == "command":
            while words and words[0].startswith("-"):
                if words.pop(0) == "--":
                    break
    if not words:
        return None

    if words[0] in aliases:
        words = [*aliases[words[0]], *words[1:]]

    executable = Path(words[0]).name
    subcommand = None
    if executable in KNOWN_SUBCOMMANDS:
        subcommand = next(
            (word for word in words[1:] if word in KNOWN_SUBCOMMANDS[executable]),
            None,
        )
    return f"{executable} {subcommand}" if subcommand else executable


def command_template(command: str) -> str | None:
    try:
        words = shlex.split(command, comments=True)
    except ValueError:
        return None
    if not words or Path(words[0]).name != "gradlew":
        return None

    normalized = [
        re.sub(r"^:modules:[^:]+:test$", ":modules:<module>:test", word)
        for word in words
    ]
    redacted: list[str] = []
    redact_next = False
    for word in normalized:
        if redact_next:
            redacted.append("[REDACTED]")
            redact_next = False
            continue
        name, separator, _value = word.partition("=")
        if any(marker in name.lower() for marker in SENSITIVE_MARKERS):
            if separator:
                redacted.append(f"{name}=[REDACTED]")
            elif word.startswith("-"):
                redacted.append(word)
                redact_next = True
            else:
                redacted.append("[REDACTED]")
            continue
        redacted.append(re.sub(r"(?<=://)[^/@\s]+@", "[REDACTED]@", word))
    template = " ".join(redacted)
    return template if "<module>" in template else None


def load_entries(database: Path, days: int) -> tuple[list[HistoryEntry], int]:
    cutoff = time.time_ns() - days * DAY_NS
    with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as connection:
        total = connection.execute(
            "SELECT COUNT(*) FROM history WHERE deleted_at IS NULL"
        ).fetchone()[0]
        rows = connection.execute(
            """
            SELECT command, duration, exit
            FROM history
            WHERE deleted_at IS NULL AND timestamp >= ?
            ORDER BY timestamp
            """,
            (cutoff,),
        ).fetchall()
    return [HistoryEntry(*row) for row in rows], total


def positive_days(value: str) -> int:
    days = int(value)
    if days < 1:
        raise argparse.ArgumentTypeError("days must be a positive integer")
    return days


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("days", nargs="?", default=30, type=positive_days)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB, help=argparse.SUPPRESS)
    parser.add_argument(
        "--aliases", type=Path, default=DEFAULT_ALIASES, help=argparse.SUPPRESS
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.db.is_file():
        print(f"No Atuin history database found at {args.db}")
        print("Install Atuin and import existing history with: atuin import zsh")
        return 1

    entries, total = load_entries(args.db, args.days)
    aliases = load_aliases(args.aliases)
    normalized_entries = [
        (entry, family)
        for entry in entries
        if (family := command_family(entry.command, aliases))
    ]
    print(f"History analysis: {len(entries)} commands in the last {args.days} days")
    if len(entries) < 20:
        print(
            "Warning: results are provisional because the selected window has fewer than 20 commands."
        )
        if total < 20:
            print("Import existing history once with: atuin import zsh")

    families = Counter(family for _entry, family in normalized_entries)
    if families:
        print("\nMost-used workflows:")
        for family, count in families.most_common(10):
            print(f"  {count}× {family}")

    executables = Counter(
        family.split()[0] for family, count in families.items() for _ in range(count)
    )
    alternatives = [
        (executable, ALTERNATIVES[executable], count)
        for executable, count in executables.items()
        if executable in ALTERNATIVES and count >= 4
    ]
    if alternatives:
        print("\nEvidence-backed alternatives:")
        for executable, alternative, count in sorted(
            alternatives, key=lambda item: (-item[2], item[0])
        ):
            print(f"  {executable} → {alternative} (observed {count}×)")

    failures = Counter(
        family for entry, family in normalized_entries if entry.exit_code != 0
    )
    repeated_failures = [
        (family, count) for family, count in failures.items() if count >= 2
    ]
    if repeated_failures:
        print("\nRepeated failures:")
        for family, count in sorted(
            repeated_failures, key=lambda item: (-item[1], item[0])
        ):
            print(f"  {count}× {family}")

    durations: dict[str, list[int]] = defaultdict(list)
    for entry, family in normalized_entries:
        durations[family].append(entry.duration_ns)
    slow_workflows = [
        (family, sum(values) / len(values) / 1_000_000_000, len(values))
        for family, values in durations.items()
        if len(values) >= 3 and sum(values) / len(values) > 5_000_000_000
    ]
    if slow_workflows:
        print("\nRepeated slow workflows:")
        for family, average_seconds, count in sorted(
            slow_workflows, key=lambda item: (-item[1], item[0])
        ):
            print(f"  {family} — {average_seconds:.1f}s average across {count} runs")

    templates = Counter(
        template for entry in entries if (template := command_template(entry.command))
    )
    candidates = [
        (template, count) for template, count in templates.items() if count >= 3
    ]
    if candidates:
        print("\nFunction candidates:")
        for template, count in sorted(candidates, key=lambda item: (-item[1], item[0])):
            print(f"  {count}× {template}")
            if template == "./gradlew :modules:<module>:test":
                print("    gwtest <module>  → run the selected module test task")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
