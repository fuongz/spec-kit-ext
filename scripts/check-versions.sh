#!/usr/bin/env bash
# check-versions.sh — verify extension.yml versions match catalog.json
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${REPO_ROOT}/extensions/catalog.json"
ERRORS=0

if [ ! -f "${CATALOG}" ]; then
  echo "ERROR: catalog.json not found at ${CATALOG}"
  exit 1
fi

# Extract extension IDs from catalog.json
CATALOG_IDS=$(python3 -c "
import json
with open('${CATALOG}') as f:
    data = json.load(f)
for k in data.get('extensions', {}).keys():
    print(k)
")

for EXT_ID in ${CATALOG_IDS}; do
  MANIFEST="${REPO_ROOT}/extensions/${EXT_ID}/extension.yml"

  if [ ! -f "${MANIFEST}" ]; then
    echo "MISSING  ${EXT_ID}: extension.yml not found (referenced in catalog.json)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  CATALOG_VER=$(python3 -c "
import json
with open('${CATALOG}') as f:
    data = json.load(f)
print(data['extensions']['${EXT_ID}']['version'])
")

  # Extract version from extension.yml without requiring yq
  # Matches the first `version:` line under the `extension:` block
  MANIFEST_VER=$(python3 -c "
import re, sys
text = open('${MANIFEST}').read()
# Match 'version:' inside the extension: block (indented)
m = re.search(r'^extension:\n(?:  \S.*\n)*?  version:\s*(\S+)', text, re.MULTILINE)
if m:
    print(m.group(1))
else:
    sys.exit(1)
" 2>/dev/null) || {
    echo "PARSE_ERR ${EXT_ID}: could not read version from extension.yml"
    ERRORS=$((ERRORS + 1))
    continue
  }

  if [ "${CATALOG_VER}" = "${MANIFEST_VER}" ]; then
    echo "OK       ${EXT_ID}  v${CATALOG_VER}"
  else
    echo "MISMATCH ${EXT_ID}: catalog.json=${CATALOG_VER}  extension.yml=${MANIFEST_VER}"
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
if [ "${ERRORS}" -gt 0 ]; then
  echo "FAIL: ${ERRORS} version mismatch(es) found."
  exit 1
else
  echo "OK: all extension versions match catalog.json."
fi
