#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <Windows-user-directory>" >&2
    exit 2
fi

env_file="$HOME/.config/antigravity-tools/manager.env"
if [[ ! -r "$env_file" ]]; then
    echo "Proxy credentials are missing; run deploy/wsl/install.sh first." >&2
    exit 1
fi

if [[ ! -d /mnt/c/Users ]]; then
    echo "Windows C: is not available at /mnt/c in this WSL session." >&2
    exit 1
fi

windows_profile="/mnt/c/Users/$1/AppData/Roaming"
candidates=(
    "$windows_profile/Antigravity IDE/User/globalStorage/state.vscdb"
    "$windows_profile/antigravity-ide/User/globalStorage/state.vscdb"
    "$windows_profile/antigravity_ide/User/globalStorage/state.vscdb"
    "$windows_profile/Antigravity/User/globalStorage/state.vscdb"
)

database=
for candidate in "${candidates[@]}"; do
    if [[ -r "$candidate" ]]; then
        database=$candidate
        break
    fi
done

if [[ -z "$database" ]]; then
    echo "No Antigravity state.vscdb found below $windows_profile." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$env_file"
set +a

payload=$(python3 -c 'import json,sys; print(json.dumps({"path": sys.argv[1]}))' "$database")
response=$(curl --silent --show-error --write-out '\n%{http_code}' \
    --request POST "http://127.0.0.1:8045/api/accounts/import/db-custom" \
    --header "Authorization: Bearer $WEB_PASSWORD" \
    --header 'Content-Type: application/json' \
    --data-binary "$payload")
status=${response##*$'\n'}

if [[ "$status" != 200 ]]; then
    echo "Account import failed (HTTP $status). Check that the database belongs to this Antigravity account and inspect the manager logs." >&2
    exit 1
fi

echo "Imported the Antigravity account from $database."
