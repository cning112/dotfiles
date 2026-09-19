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
import sys
import time
from collections import Counter, defaultdict
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path


DAY_NS = 86_400 * 1_000_000_000
# 100 years: keeps days * DAY_NS inside SQLite's signed 64-bit integer range.
MAX_DAYS = 36_500
DEFAULT_DAYS = 30
# A single foreground command cannot plausibly run longer than this. Atuin
# records multi-day durations when a session spans a suspend, which would
# otherwise produce nonsense such as "npx — 248051.2s average".
MAX_DURATION_NS = 24 * 60 * 60 * 1_000_000_000
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
# Flags whose *name* carries no marker but that are known to take a secret value
# (e.g. `-p hunter2`). The value following one of these is always redacted.
SENSITIVE_FLAGS = frozenset(
    {"-p", "-P", "--pass", "--auth", "--apikey", "--api-key", "--bearer"}
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
        # Only the first non-option argument can be the subcommand. Scanning every
        # argument would attribute e.g. `npm ls run` to the `npm run` workflow.
        # Options are skipped (and anything after the first real positional stops
        # the search) so `git -c k=v status` still resolves to `git status`.
        for word in words[1:]:
            if word in KNOWN_SUBCOMMANDS[executable]:
                subcommand = word
                break
            if word.startswith("-") or "=" in word:
                continue
            break
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
        if name in SENSITIVE_FLAGS:
            if separator:
                redacted.append(f"{name}=[REDACTED]")
            else:
                redacted.append(word)
                redact_next = True
            continue
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


def connect_readonly(database: Path) -> sqlite3.Connection:
    # as_uri() percent-encodes the path; interpolating it raw would let a "?" or
    # "#" in the path be parsed as URI syntax.
    connection = sqlite3.connect(
        f"{database.resolve().as_uri()}?mode=ro", uri=True, timeout=5.0
    )
    # Shell history holds arbitrary bytes; never let decoding raise.
    connection.text_factory = lambda raw: raw.decode("utf-8", "replace")
    return connection


def load_entries(database: Path, days: int) -> tuple[list[HistoryEntry], int]:
    cutoff = time.time_ns() - days * DAY_NS
    with closing(connect_readonly(database)) as connection:
        total = connection.execute(
            "SELECT COUNT(*) FROM history WHERE deleted_at IS NULL"
        ).fetchone()[0]
        rows = connection.execute(
            """
            SELECT command, duration, exit
            FROM history
            WHERE deleted_at IS NULL AND timestamp >= ?
            ORDER BY timestamp, id
            """,
            (cutoff,),
        ).fetchall()
    return [HistoryEntry(*row) for row in rows], total


def positive_days(value: str) -> int:
    try:
        days = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid day count: {value!r}") from None
    if not 1 <= days <= MAX_DAYS:
        raise argparse.ArgumentTypeError(f"days must be between 1 and {MAX_DAYS}")
    return days


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "days",
        nargs="?",
        default=None,
        type=positive_days,
        help=f"analysis window in days (1-{MAX_DAYS}), as a positional",
    )
    parser.add_argument(
        "-n",
        "--days",
        dest="days_option",
        type=positive_days,
        default=None,
        help="analysis window in days (same as the positional form)",
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB, help=argparse.SUPPRESS)
    parser.add_argument(
        "--aliases", type=Path, default=DEFAULT_ALIASES, help=argparse.SUPPRESS
    )
    args = parser.parse_args()
    if args.days_option is not None:
        args.days = args.days_option
    if args.days is None:
        args.days = DEFAULT_DAYS
    return args


def main() -> int:
    args = parse_args()
    if not args.db.is_file():
        print(f"No Atuin history database found at {args.db}")
        print("Install Atuin and import existing history with: atuin import zsh")
        return 1

    try:
        entries, total = load_entries(args.db, args.days)
    except sqlite3.Error as error:
        print(f"Could not read {args.db}: {error}", file=sys.stderr)
        print(
            "The file may not be an Atuin database, may use an older schema, or "
            "may be locked by a running Atuin daemon.",
            file=sys.stderr,
        )
        return 2

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
        # Skip durations Atuin could not measure (-1) and implausible ones from
        # sessions that spanned a suspend: both distort the average and can hide
        # genuinely slow workflows behind a filtered-out outlier.
        if 0 < entry.duration_ns <= MAX_DURATION_NS:
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
