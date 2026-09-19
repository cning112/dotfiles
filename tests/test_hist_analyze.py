#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
from __future__ import annotations

import sqlite3
import subprocess
import tempfile
import time
import unittest
from contextlib import closing
from os import environ
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANALYZER = ROOT / "scripts" / "hist_analyze.py"
DAY_NS = 86_400 * 1_000_000_000


def create_history_db(
    path: Path, commands: list[tuple[int, int, int, str, str]]
) -> None:
    with closing(sqlite3.connect(path)) as connection:
        connection.execute(
            """
            CREATE TABLE history (
                id TEXT PRIMARY KEY,
                timestamp INTEGER NOT NULL,
                duration INTEGER NOT NULL,
                exit INTEGER NOT NULL,
                command TEXT NOT NULL,
                cwd TEXT NOT NULL,
                session TEXT NOT NULL,
                hostname TEXT NOT NULL,
                deleted_at INTEGER
            )
            """
        )
        connection.executemany(
            """
            INSERT INTO history
                (id, timestamp, duration, exit, command, cwd, session, hostname)
            VALUES (?, ?, ?, ?, ?, ?, 'test-session', 'test-host')
            """,
            [
                (str(index), timestamp, duration, exit_code, command, cwd)
                for index, (timestamp, duration, exit_code, command, cwd) in enumerate(
                    commands
                )
            ],
        )
        connection.commit()


class HistAnalyzeCliTests(unittest.TestCase):
    def run_analyzer(
        self, database: Path, *arguments: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["uv", "run", "--script", str(ANALYZER), *arguments, "--db", str(database)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_requested_window_excludes_older_commands(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    *[
                        (now - DAY_NS, 100_000_000, 0, "git status -s", "/repo")
                        for _ in range(3)
                    ],
                    *[
                        (now - 40 * DAY_NS, 100_000_000, 0, "brew update", "/repo")
                        for _ in range(8)
                    ],
                ],
            )

            result = self.run_analyzer(database, "7")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("3 commands in the last 7 days", result.stdout)
        self.assertIn("3× git status", result.stdout)
        self.assertNotIn("brew update", result.stdout)

    def test_sparse_atuin_history_recommends_import_before_trusting_results(
        self,
    ) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [(now - DAY_NS, 100_000_000, 0, "git status", "/repo")],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("provisional", result.stdout.lower())
        self.assertIn("atuin import zsh", result.stdout)

    def test_sparse_selected_window_is_provisional_even_with_mature_history(
        self,
    ) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    *[
                        (now - 90 * DAY_NS, 100_000_000, 0, "git status", "/repo")
                        for _ in range(25)
                    ],
                    (now - DAY_NS, 100_000_000, 0, "git status", "/repo"),
                ],
            )

            result = self.run_analyzer(database, "7")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("provisional", result.stdout.lower())

    def test_commands_with_arguments_and_prefixes_share_one_workflow(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (now - DAY_NS, 100_000_000, 0, "grep alpha one.txt", "/repo"),
                    (now - DAY_NS, 100_000_000, 0, "grep beta two.txt", "/repo"),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "sudo -u root grep gamma three.txt",
                        "/repo",
                    ),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "env LC_ALL=C grep delta four.txt",
                        "/repo",
                    ),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "env -i LC_ALL=C grep epsilon five.txt",
                        "/repo",
                    ),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "env -u TOKEN grep zeta six.txt",
                        "/repo",
                    ),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "command -p grep eta seven.txt",
                        "/repo",
                    ),
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "sudo --user root grep theta eight.txt",
                        "/repo",
                    ),
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("8× grep", result.stdout)
        self.assertNotIn("grep alpha", result.stdout)

    def test_repeated_gradle_module_tests_propose_a_parameterized_function(
        self,
    ) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        2_000_000_000,
                        0,
                        f"./gradlew :modules:{module}:test",
                        "/repo",
                    )
                    for module in ("adapter", "integration", "query")
                    for _ in range(2)
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("6× ./gradlew :modules:<module>:test", result.stdout)
        self.assertIn("gwtest <module>", result.stdout)

    def test_repeated_legacy_tool_use_proposes_an_alternative_with_evidence(
        self,
    ) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        f"grep pattern-{index} file-{index}.txt",
                        "/repo",
                    )
                    for index in range(4)
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("grep → rg (observed 4×)", result.stdout)

    def test_function_candidates_redact_secret_arguments(self) -> None:
        now = time.time_ns()
        secret = "do-not-print-this-token"
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        2_000_000_000,
                        0,
                        f"./gradlew :modules:{module}:test --token {secret}",
                        "/repo",
                    )
                    for module in ("adapter", "integration", "query")
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(secret, result.stdout)
        self.assertIn("[REDACTED]", result.stdout)

    def test_function_candidates_redact_headers_credentials_and_urls(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        2_000_000_000,
                        0,
                        " ".join(
                            [
                                f"./gradlew :modules:{module}:test",
                                "--header 'Authorization: Bearer header-secret'",
                                "--credentials credential-secret",
                                "https://user:url-secret@example.com/resource",
                            ]
                        ),
                        "/repo",
                    )
                    for module in ("adapter", "integration", "query")
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("header-secret", result.stdout)
        self.assertNotIn("credential-secret", result.stdout)
        self.assertNotIn("url-secret", result.stdout)
        self.assertIn("[REDACTED]", result.stdout)

    def test_repeated_failures_are_grouped_by_normalized_workflow(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (now - DAY_NS, 100_000_000, 1, "git status -s", "/repo"),
                    (now - DAY_NS, 100_000_000, 2, "git status --short", "/repo"),
                    (now - DAY_NS, 100_000_000, 1, "sudo git status", "/repo"),
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Repeated failures:", result.stdout)
        self.assertIn("3× git status", result.stdout)

    def test_repeated_slow_commands_are_grouped_by_normalized_workflow(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        duration * 1_000_000_000,
                        0,
                        f"./gradlew test --tests suite{duration}",
                        "/repo",
                    )
                    for duration in (6, 8, 10)
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Repeated slow workflows:", result.stdout)
        self.assertIn("gradlew — 8.0s average across 3 runs", result.stdout)

    def test_existing_aliases_are_counted_as_the_underlying_workflow(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database = root / "history.db"
            aliases = root / ".aliases"
            aliases.write_text('alias ll="ls -alh"\n')
            create_history_db(
                database,
                [
                    (now - DAY_NS, 100_000_000, 0, "ll", "/repo"),
                    (now - DAY_NS, 100_000_000, 0, "ls -la", "/repo"),
                ],
            )

            result = self.run_analyzer(database, "--aliases", str(aliases))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("2× ls", result.stdout)
        self.assertNotIn("× ll", result.stdout)

    def test_shell_function_runs_the_uv_analyzer_from_the_dotfiles_symlink(
        self,
    ) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            database = home / ".local" / "share" / "atuin" / "history.db"
            database.parent.mkdir(parents=True)
            create_history_db(
                database,
                [(now - DAY_NS, 100_000_000, 0, "git status", "/repo")],
            )
            (home / ".functions").symlink_to(ROOT / ".functions")

            result = subprocess.run(
                [
                    "zsh",
                    "-c",
                    f"source {ROOT / '.functions'}; hist-analyze 7",
                ],
                cwd=ROOT,
                env={**environ, "HOME": str(home)},
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1 commands in the last 7 days", result.stdout)

    def test_workflow_names_do_not_expose_git_configuration_secrets(self) -> None:
        now = time.time_ns()
        secret = "bearer-do-not-print"
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        f"git -c http.extraHeader=Authorization:{secret} status -s",
                        "/repo",
                    )
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(secret, result.stdout)
        self.assertIn("1× git status", result.stdout)

    def test_subcommand_is_matched_only_in_the_subcommand_position(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    # "run" is an argument to `ls`, not the npm subcommand
                    (now - DAY_NS, 100_000_000, 0, "npm ls run", "/repo"),
                    (now - DAY_NS, 100_000_000, 0, "npm ls run", "/repo"),
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("2× npm", result.stdout)
        self.assertNotIn("npm run", result.stdout)

    def test_options_before_the_subcommand_still_resolve_it(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        100_000_000,
                        0,
                        "git -c http.extraHeader=Authorization:secret status -s",
                        "/repo",
                    )
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1× git status", result.stdout)

    def test_function_candidates_redact_short_flag_secrets(self) -> None:
        now = time.time_ns()
        secret = "hunter2-do-not-print"
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (
                        now - DAY_NS,
                        2_000_000_000,
                        0,
                        f"./gradlew :modules:{module}:test -p {secret}",
                        "/repo",
                    )
                    for module in ("adapter", "integration", "query")
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(secret, result.stdout)
        self.assertIn("-p [REDACTED]", result.stdout)

    def test_unmeasurable_and_implausible_durations_are_ignored(self) -> None:
        now = time.time_ns()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(
                database,
                [
                    (now - DAY_NS, 60_000_000_000, 0, "./gradlew test", "/repo"),
                    (now - DAY_NS, 80_000_000_000, 0, "./gradlew test", "/repo"),
                    (now - DAY_NS, 100_000_000_000, 0, "./gradlew test", "/repo"),
                    # Atuin's "duration unknown" marker; must not dilute the average
                    (now - DAY_NS, -1, 0, "./gradlew test", "/repo"),
                    # A session that spanned a suspend; must not invent a slow workflow
                    (now - DAY_NS, 1_630_841_000_000_000, 0, "./gradlew test", "/repo"),
                ],
            )

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("gradlew — 80.0s average across 3 runs", result.stdout)

    def test_absurd_day_counts_are_rejected_without_a_traceback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "history.db"
            create_history_db(database, [])

            result = self.run_analyzer(database, "999999999")

        self.assertEqual(result.returncode, 2)
        self.assertNotIn("Traceback", result.stderr)
        self.assertIn("between 1 and", result.stderr)

    def test_an_incompatible_database_reports_cleanly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "other.db"
            with closing(sqlite3.connect(database)) as connection:
                connection.execute("CREATE TABLE other (x INTEGER)")
                connection.commit()

            result = self.run_analyzer(database)

        self.assertEqual(result.returncode, 2)
        self.assertNotIn("Traceback", result.stderr)
        self.assertIn("Could not read", result.stderr)


if __name__ == "__main__":
    unittest.main()
