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

