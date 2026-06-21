# dotfiles

Bootstrap script and auth-transfer helpers for spinning up a new remote dev
pod (or any fresh Linux box) with the same tools, config, and logins as this
machine.

## Setup

```bash
git clone https://github.com/dsingal0/dotfiles ~/dotfiles
cd ~/dotfiles
./setup.sh
```

`setup.sh` is idempotent, so you can re-run it to update tools on an existing
machine.

### What it installs

- **btop** (system monitor; best-effort, skipped if `apt-get` is unavailable)
- **nvm** + Node.js 26
- **opencode** (`opencode-ai` via npm)
- **croc** (used by the auth helpers below to transfer files between machines)
- **gh** (GitHub CLI)
- **uv** (Python package manager)
- **Factory CLI** (`droid`)
- **paseo** (`@getpaseo/cli`)
- git identity (name + email) configured globally

## Transferring auth + config to a new machine

Two helpers use `croc` to copy your logins and config from this machine onto a
fresh one. Both are installed into `~/.local/bin` by `setup.sh`.

### Factory Droid

Transfers Factory CLI auth + settings so a new machine is logged in and
configured without re-auth or reconfiguration.

**On this machine (the one you're already logged in on):**

```bash
factory-auth send
```

This prints a one-time croc code.

**On the new machine (after running `setup.sh`):**

```bash
factory-auth receive <code>
```

Files transferred into `~/.factory/`:

| File               | Contents                                                            |
|--------------------|--------------------------------------------------------------------|
| `auth.v2.key`      | Encryption key for the auth token                                  |
| `auth.v2.file`     | Encrypted auth token (your login)                                  |
| `settings.json`    | Default model, reasoning effort, autonomy mode, custom models (+API keys), favorites, mission worker settings |
| `mcp.json`         | MCP server config                                                  |

`host.json` and other machine-specific files are intentionally NOT
transferred. If Factory still rejects auth on the remote (host fingerprint
pinning), you'll have to re-login there.

### opencode

Transfers opencode config + auth so a new machine is logged in and
configured.

**On this machine:**

```bash
opencode-auth send
```

**On the new machine (after running `setup.sh`):**

```bash
opencode-auth receive <code>
```

Files transferred:

| File                                            | Contents                                  |
|-------------------------------------------------|-------------------------------------------|
| `~/.config/opencode/opencode.json`              | `permission: allow`, etc.                |
| `~/.config/opencode/opencode.jsonc`             | MCP server config, etc.                   |
| `~/.local/share/opencode/auth.json`              | opencode auth token                       |
| `~/.local/share/opencode/account.json`           | opencode account credentials             |

The large session DB (`opencode.db*`) and other machine/session-specific data
are intentionally NOT transferred.

## Notes

- `factory-auth` and `opencode-auth` are plain bash scripts in this repo; you
  can copy them anywhere and run them directly as long as `croc` is installed.
- The `--yes` flag is croc's global flag and must precede the `send`
  subcommand (e.g. `croc --yes send <files>`); the helpers handle this for you.
- Cursor CLI and Claude CLI installs in `setup.sh` are currently commented out;
  only opencode and droid harnesses are active.
