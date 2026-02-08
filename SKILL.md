---
name: submodule-sync
description: Manage git submodules in the Workflow Systems monorepo. Use when user asks to sync submodules, check submodule status, commit across repos, update submodules, add new submodules, or mentions "/sync". Handles the complexity of committing in submodules first then updating parent references.
---

# Submodule Sync

Manage submodules across skills/, sites/, external/, configs/, plugins/, and mcp-servers/ directories.

## Commands

Run `scripts/sync.sh` from repo root:

```bash
./skills/submodule-sync/scripts/sync.sh <command>
```

| Command | Purpose |
|---------|---------|
| `status` | Show all submodules with uncommitted changes, unpushed commits, or behind remote |
| `update` | Pull latest from all submodule remotes |
| `commit` | Interactive commit across submodules with changes |
| `push` | Push all submodules with unpushed commits |
| `add` | Add a new submodule (bootstraps skill template for skills/ paths) |
| `validate` | Run validate-skill.sh across all skill submodules |
| `init-hooks` | Set core.hooksPath in all skill submodules (for fresh clones) |
| `finalize [msg]` | Commit and push parent repo (pass message for non-interactive) |

## Workflow: Committing Changes

When changes exist across multiple submodules:

1. **Check status**: `./skills/submodule-sync/scripts/sync.sh status`
2. **Commit in submodules**: `./skills/submodule-sync/scripts/sync.sh commit`
3. **Push submodules**: `./skills/submodule-sync/scripts/sync.sh push`
4. **Finalize parent**: `./skills/submodule-sync/scripts/sync.sh finalize`

## Manual Operations

**Update single submodule:**
```bash
cd skills/some-skill
git pull origin main
cd ../..
git add skills/some-skill
git commit -m "update some-skill"
```

**Add submodule manually:**
```bash
git submodule add git@github.com:user/repo.git skills/new-skill
git commit -m "add new-skill submodule"
```

**Clone repo with submodules:**
```bash
git clone --recurse-submodules <url>
# Or after clone:
git submodule update --init --recursive
```
