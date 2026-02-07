#!/usr/bin/env bash
# Validates skill structure. Runs as pre-commit hook and in CI.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Detect context: hook (GIT_INDEX_FILE set) vs CI/manual
if [ -n "${GIT_INDEX_FILE:-}" ]; then
  MODE="hook"
else
  MODE="ci"
fi

echo "==> Validating skill ($MODE mode)"

errors=0

# --- SKILL.md existence ---
if [ ! -f "SKILL.md" ]; then
  echo "  FAIL: SKILL.md not found"
  errors=$((errors + 1))
else
  echo "  OK: SKILL.md exists"
fi

# --- Frontmatter validation (bash) ---
if [ -f "SKILL.md" ]; then
  # Check starts with ---
  first_line=$(head -1 SKILL.md)
  if [ "$first_line" != "---" ]; then
    echo "  FAIL: SKILL.md must start with --- (YAML frontmatter)"
    errors=$((errors + 1))
  else
    # Check closing ---
    closing=$(awk 'NR>1 && /^---$/{print NR; exit}' SKILL.md)
    if [ -z "$closing" ]; then
      echo "  FAIL: SKILL.md frontmatter missing closing ---"
      errors=$((errors + 1))
    else
      # Extract frontmatter lines between delimiters
      frontmatter=$(sed -n "2,$((closing - 1))p" SKILL.md)

      # Check name field
      name_line=$(echo "$frontmatter" | grep -E '^name:' || true)
      if [ -z "$name_line" ]; then
        echo "  FAIL: SKILL.md frontmatter missing 'name' field"
        errors=$((errors + 1))
      else
        # Extract name value and validate hyphen-case
        name_value=$(echo "$name_line" | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'")
        if ! echo "$name_value" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$'; then
          echo "  FAIL: name '$name_value' is not valid hyphen-case"
          errors=$((errors + 1))
        else
          echo "  OK: name '$name_value' (hyphen-case)"
        fi
      fi

      # Check description field
      desc_line=$(echo "$frontmatter" | grep -E '^description:' || true)
      if [ -z "$desc_line" ]; then
        echo "  FAIL: SKILL.md frontmatter missing 'description' field"
        errors=$((errors + 1))
      else
        echo "  OK: description present"
      fi
    fi
  fi
fi

# --- Full Python validation (optional, requires PyYAML) ---
if python3 -c "import yaml" 2>/dev/null; then
  if [ -f "scripts/quick_validate.py" ]; then
    if python3 scripts/quick_validate.py .; then
      echo "  OK: quick_validate.py passed"
    else
      echo "  FAIL: quick_validate.py failed"
      errors=$((errors + 1))
    fi
  fi
else
  echo "  SKIP: PyYAML not available, skipping full frontmatter validation"
fi

# --- .gitignore patterns ---
if [ -f ".gitignore" ]; then
  has_local=false
  has_local_ext=false
  if grep -qE '^\*\.local$' .gitignore; then has_local=true; fi
  if grep -qE '^\*\.local\.\*$' .gitignore; then has_local_ext=true; fi

  if $has_local && $has_local_ext; then
    echo "  OK: .gitignore has *.local patterns"
  else
    echo "  FAIL: .gitignore missing *.local and/or *.local.* patterns"
    errors=$((errors + 1))
  fi
else
  echo "  FAIL: .gitignore not found"
  errors=$((errors + 1))
fi

# --- No .local artifacts tracked ---
if [ "$MODE" = "hook" ]; then
  # Check staged files only
  local_staged=$(git diff --cached --name-only | grep -E '\.local(\.|$)' || true)
  if [ -n "$local_staged" ]; then
    echo "  FAIL: .local artifacts staged for commit:"
    echo "$local_staged" | sed 's/^/    /'
    errors=$((errors + 1))
  else
    echo "  OK: no .local artifacts staged"
  fi
else
  # CI/manual mode: check for tracked .local files (untracked/gitignored ones are fine)
  local_tracked=$(git ls-files | grep -E '\.local(\.|$)' || true)
  if [ -n "$local_tracked" ]; then
    echo "  FAIL: .local artifacts tracked by git:"
    echo "$local_tracked" | sed 's/^/    /'
    errors=$((errors + 1))
  else
    echo "  OK: no .local artifacts tracked"
  fi
fi

# --- Script checks (if scripts/ exists) ---
if [ -d "scripts" ]; then
  for script in scripts/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      echo "  FAIL: $script is not executable"
      errors=$((errors + 1))
    else
      echo "  OK: $script is executable"
    fi
    if ! bash -n "$script" 2>/dev/null; then
      echo "  FAIL: $script has syntax errors"
      errors=$((errors + 1))
    else
      echo "  OK: $script syntax valid"
    fi
  done
fi

# --- Reference checks (if references/ exists) ---
if [ -d "references" ]; then
  for ref in references/*.md; do
    [ -f "$ref" ] || continue
    if [ ! -s "$ref" ]; then
      echo "  FAIL: $ref is empty"
      errors=$((errors + 1))
    else
      echo "  OK: $ref non-empty"
    fi
  done
fi

# --- Result ---
echo ""
if [ "$errors" -gt 0 ]; then
  echo "==> Validation failed with $errors error(s)"
  exit 1
fi

echo "==> Validation passed"
