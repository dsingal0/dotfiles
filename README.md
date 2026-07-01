# dotfiles

Bootstrap script for spinning up a new remote dev pod (or any fresh Linux
box) with the same tools and config as this machine.

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
- **croc** (file transfer tool used between machines)
- **gh** (GitHub CLI)
- **uv** (Python package manager)
- **Factory CLI** (`droid`)
- **paseo** (`@getpaseo/cli`)
- **droid-to-opencode** user script (imports a Factory "droid" session into opencode so it can be resumed there); symlinked into `~/.local/bin`
- git identity (name + email) configured globally

## Notes

- Cursor CLI and Claude CLI installs in `setup.sh` are currently commented out;
  only opencode and droid harnesses are active.
