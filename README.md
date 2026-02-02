# Submodule Sync

Manage git submodules in monorepos with proper commit ordering.

## Usage

Invoke via Claude Code:

- "sync submodules"
- "check submodule status"
- "commit across repos"

Or run directly:

```bash
./scripts/sync.sh status   # Show submodules with changes
./scripts/sync.sh commit   # Interactive commit across submodules
./scripts/sync.sh push     # Push all with unpushed commits
```

## Requirements

- Git with submodule support
- Bash
