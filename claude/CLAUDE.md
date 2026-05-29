@RTK.md


## Python Scripts

Use `uv run` to execute ad-hoc Python scripts without polluting any environment:

```bash
# Run a script with inline deps declared at the top of the file
uv run script.py

# Pass deps directly without editing the script
uv run --with requests --with pandas script.py

# Specify a Python version
uv run --python 3.12 script.py
```

For scripts that need packages, declare them inline at the top of the file using PEP 723:

```python
# /// script
# dependencies = ["requests", "rich"]
# ///
import requests
```

Never use `pip install` or `pip3 install`, and never modify any existing venv. Always prefer `uv run` for ad-hoc scripts.


## gstack
Use the /browse skill from gstack for all web browsing, never use mcp__claude-in-chrome__* tools, and lists the available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /setup-gbrain, /retro, /investigate, /document-release, /document-generate, /codex, /cso, /autoplan, /plan-devex-review, /devex-review, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn. Then ask the user if they also want to add gstack to the current project so teammates get it.

