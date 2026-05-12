# CLAUDE.md — second-laptop install brief

This is a personal fork of [HKUDS/DeepTutor](https://github.com/HKUDS/DeepTutor).
Two changes vs. upstream `ac8f00b` (v1.3.10):

1. Strip a trailing `/v1` from the Anthropic `base_url` in both `deeptutor/services/llm/provider_core/anthropic_provider.py` and `deeptutor/tutorbot/providers/anthropic_provider.py`. Without this, the official `anthropic` SDK appends its own `/v1/messages` to a `base_url` that already ends in `/v1`, producing 404 `not_found_error` on every chat turn.
2. This file.

## Cross-laptop sync model

The user runs DeepTutor on two macOS laptops and shares all state (chat history, memory/profile, settings, attachments, knowledge bases) by keeping `data/` inside a cloud-synced workspace folder and symlinking it back into the repo.

- **Laptop 1** (already set up): `data` in the repo root is a symlink into the synced workspace.
- **Laptop 2** (this one): the install must recreate that same symlink **before first launch** so the app reads the already-synced settings (with API keys) and existing memory/chats instead of running the Setup Tour from scratch.

**Hard rule (tell the user if relevant):** never run DeepTutor on both laptops at once. The chat history is SQLite — the sync provider can't merge a binary file, and concurrent writes corrupt it. Wait until the cloud sync indicator shows fully synced before switching laptops.

## Environment on this laptop (per the user)

- macOS.
- `~/Documents/local_ws` already exists.
- `conda`, `python` (3.11+ expected), and `node.js` (20.9+ expected) are installed.
- The synced workspace folder is reachable via the shell alias `ws` defined in `~/.zshrc`. Read that file to discover the absolute path (look for `alias ws=...`). The cloud sync client must already be fully synced and in a mode that keeps files on local disk (e.g. Google Drive "Mirror files", not "Stream").

## Install procedure

When the user asks to install DeepTutor on this laptop, do these steps in order. Confirm with the user between steps if anything looks off — don't blindly proceed if a check fails.

### Step 0 — resolve the synced workspace path and locate the data folder

```bash
grep "^alias ws=" ~/.zshrc
```

Extract the absolute path inside the quotes. Call it `$WS` going forward (don't `eval` the alias — Claude Code sessions don't load `.zshrc`).

The DeepTutor data folder lives inside `$WS`. Find it by content, not by name:

```bash
ls "$WS"
# Then identify the directory that contains memory/, user/, tutorbot/, and
# knowledge_bases/ subdirectories — that's the data folder.
```

If you can't find it (folder missing, or no subdir matches the expected layout), **stop**. The sync hasn't finished, or the user hasn't set up laptop 1's data sync yet. Ask the user.

Call the resolved absolute path `$DATA_DIR` going forward.

### Step 1 — clone the fork

```bash
cd ~/Documents/local_ws
git clone https://github.com/saleml/DeepTutor.git
cd DeepTutor
```

### Step 2 — create the data symlink BEFORE anything else

```bash
ln -s "$DATA_DIR" ./data
```

Verify:

```bash
/bin/ls -ld ./data   # expect "l..." prefix and the target shown after "->"
ls ./data/user/settings/model_catalog.json  # must exist; this is what skips the Setup Tour
```

If `./data` already exists as a real directory (e.g. some script auto-created it), `rm -rf ./data` first **only after** confirming it's empty or freshly auto-created. If it has any subdirectories with content, stop and ask — that would be state the user wants to preserve.

### Step 3 — Python environment

```bash
conda create -n deeptutor python=3.11 -y
conda activate deeptutor
python -m pip install --upgrade pip
```

### Step 4 — install dependencies

```bash
python -m pip install -e ".[server]"
cd web && npm install && cd ..
```

The user does not need TutorBot, Matrix, or Math Animator unless they say so — don't install those add-ons proactively.

### Step 5 — launch

**Do not run `python scripts/start_tour.py`.** The Setup Tour would prompt for API keys again and may overwrite the synced `model_catalog.json`. Settings already exist in `data/user/settings/` via the symlink.

```bash
python scripts/start_web.py
```

The frontend URL is printed in the terminal. The first chat turn should work immediately — same model, same API key, same chat history and memory as on laptop 1.

## Troubleshooting

- **`not_found_error` on first chat:** means you're somehow running upstream code, not this fork — check `grep -n 'endswith("/v1")' deeptutor/services/llm/provider_core/anthropic_provider.py`. If empty, you cloned the wrong remote.
- **Setup Tour ran anyway:** the symlink wasn't in place before launch, or `data/user/settings/model_catalog.json` isn't readable through the symlink. Stop the server, check the symlink target, restart.
- **Chat history is empty / profile is blank:** the cloud client hasn't finished syncing the `workspace/chat/` subtree on this laptop. Quit DeepTutor, wait for sync to finish, restart.
- **Settings work but data feels stale after switching laptops:** sync direction wasn't complete when you switched. Always wait for the fully-synced indicator before launching on the other laptop.

## Keeping this fork up to date with upstream

When the user wants to pull upstream changes:

```bash
git remote add upstream https://github.com/HKUDS/DeepTutor.git   # one-time
git fetch upstream
git merge upstream/main
# Resolve any conflicts in the two anthropic_provider.py files (keep the
# /v1-stripping logic — upstream may or may not have fixed it themselves).
git push origin main
```

If upstream fixes the `/v1` duplication themselves, the local edits can be dropped and this fork becomes a plain mirror.
