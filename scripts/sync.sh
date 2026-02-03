#!/bin/bash
# Submodule sync operations for Workflow Systems monorepo

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  status    Show status of all submodules (changes, ahead/behind)"
    echo "  update    Update all submodules to latest remote"
    echo "  commit    Interactive commit across changed submodules"
    echo "  push      Push all submodules with unpushed commits"
    echo "  add       Add a new submodule (prompts for details)"
    echo "  finalize  Commit and push parent repo with submodule updates"
    exit 1
}

status_all() {
    echo "=== Submodule Status ==="
    echo ""
    git submodule foreach --quiet '
        name=$(basename "$sm_path")
        changes=$(git status --porcelain | wc -l | tr -d " ")
        branch=$(git rev-parse --abbrev-ref HEAD)

        # Check ahead/behind
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "?")
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")

        if [ "$changes" -gt 0 ]; then
            status="[$changes uncommitted]"
        elif [ "$ahead" != "0" ] && [ "$ahead" != "?" ]; then
            status="[↑$ahead unpushed]"
        elif [ "$behind" != "0" ] && [ "$behind" != "?" ]; then
            status="[↓$behind behind]"
        else
            status="[clean]"
        fi

        printf "%-30s %-10s %s\n" "$sm_path" "$branch" "$status"
    '
}

update_all() {
    echo "=== Updating Submodules ==="
    git submodule update --remote --merge
    echo ""
    echo "Updated. Run '$0 finalize' to commit and push parent."
}

commit_changed() {
    echo "=== Committing Changed Submodules ==="

    changed=$(git submodule foreach --quiet '
        if [ -n "$(git status --porcelain)" ]; then
            echo "$sm_path"
        fi
    ')

    if [ -z "$changed" ]; then
        echo "No submodules have uncommitted changes."
        return
    fi

    echo "Submodules with changes:"
    echo "$changed"
    echo ""

    for path in $changed; do
        echo "--- $path ---"
        cd "$REPO_ROOT/$path"
        git status --short
        echo ""
        read -p "Commit message (or 'skip'): " msg
        if [ "$msg" != "skip" ] && [ -n "$msg" ]; then
            git add -A
            git commit -m "$msg"
            echo "Committed."
        else
            echo "Skipped."
        fi
        cd "$REPO_ROOT"
        echo ""
    done

    echo "Done. Run '$0 push' to push submodules, then '$0 finalize' for parent."
}

push_all() {
    echo "=== Pushing Submodules ==="
    git submodule foreach --quiet '
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$ahead" -gt 0 ]; then
            echo "Pushing $sm_path ($ahead commits)..."
            git push
        fi
    '
    echo "Done."
}

add_submodule() {
    echo "=== Add New Submodule ==="
    read -p "Git URL: " url
    read -p "Local path (e.g., skills/new-skill): " path

    if [ -z "$url" ] || [ -z "$path" ]; then
        echo "URL and path required."
        exit 1
    fi

    git submodule add "$url" "$path"
    echo "Added. Run '$0 finalize' to commit and push parent."
}

finalize_parent() {
    echo "=== Finalize Parent Repo ==="

    # Check for submodule changes
    changed=$(git diff --name-only | grep -E '^(skills|sites|external)/' || true)
    staged=$(git diff --cached --name-only | grep -E '^(skills|sites|external)/' || true)

    if [ -z "$changed" ] && [ -z "$staged" ]; then
        echo "No submodule changes to commit."

        # Check if ahead of remote
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$ahead" -gt 0 ]; then
            read -p "Parent has $ahead unpushed commits. Push now? [y/N] " push_confirm
            if [ "$push_confirm" = "y" ] || [ "$push_confirm" = "Y" ]; then
                git push
                echo "Pushed."
            fi
        fi
        return
    fi

    echo "Submodule changes:"
    [ -n "$changed" ] && echo "$changed"
    [ -n "$staged" ] && echo "$staged"
    echo ""

    # Generate default message from changed paths
    all_changed=$(echo -e "$changed\n$staged" | sort -u | xargs -n1 basename 2>/dev/null | paste -sd, -)
    default_msg="chore: update submodules ($all_changed)"

    read -p "Commit message [$default_msg]: " msg
    msg="${msg:-$default_msg}"

    # Stage submodule changes
    [ -n "$changed" ] && echo "$changed" | xargs git add

    git commit -m "$msg"
    echo "Committed."

    read -p "Push to remote? [Y/n] " push_confirm
    if [ "$push_confirm" != "n" ] && [ "$push_confirm" != "N" ]; then
        git push
        echo "Pushed."
    fi
}

case "${1:-}" in
    status) status_all ;;
    update) update_all ;;
    commit) commit_changed ;;
    push) push_all ;;
    add) add_submodule ;;
    finalize) finalize_parent ;;
    *) usage ;;
esac
