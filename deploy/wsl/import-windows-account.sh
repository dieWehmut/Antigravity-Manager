#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <Windows-user-directory> | --db <state.vscdb>" >&2
    exit 2
}

if [[ $# == 2 && $1 == --db && -n $2 ]]; then
    database=$2
elif [[ $# == 1 && -n $1 && $1 != -* && $1 != */* && $1 != *\\* && $1 != . && $1 != .. ]]; then
    if [[ ! -d /mnt/c/Users ]]; then
        echo "Windows C: is not available at /mnt/c. Copy your database into WSL and run with --db." >&2
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
        if [[ -f "$candidate" && -r "$candidate" ]]; then
            database=$candidate
            break
        fi
    done
    if [[ -z "$database" ]]; then
        echo "No Antigravity state.vscdb found below $windows_profile." >&2
        exit 1
    fi
else
    usage
fi

if [[ ! -f "$database" || ! -r "$database" ]]; then
    echo "Cannot read the specified database: $database" >&2
    exit 1
fi
database=$(realpath -- "$database")

env_file="$HOME/.config/antigravity-tools/manager.env"
if [[ ! -r "$env_file" ]]; then
    echo "Proxy credentials are missing; run deploy/wsl/install.sh first." >&2
    exit 1
fi
web_password=$(sed -n 's/^WEB_PASSWORD=//p' "$env_file")
if [[ -z "$web_password" || "$web_password" == *$'\r'* || "$web_password" == *$'\n'* ]]; then
    echo "Invalid WEB_PASSWORD in $env_file." >&2
    exit 1
fi

payload=$(python3 -c 'import json,sys; print(json.dumps({"path": sys.argv[1]}))' "$database")
status=$(printf 'Authorization: Bearer %s\n' "$web_password" | curl --disable \
    --silent --show-error --noproxy '*' --connect-timeout 3 --max-time 90 \
    --output /dev/null --write-out '%{http_code}' --header @- \
    --header 'Content-Type: application/json' --data-binary "$payload" \
    http://127.0.0.1:8045/api/accounts/import/db-custom)

if [[ "$status" != 200 ]]; then
    echo "Account import failed (HTTP $status). Check that the database belongs to this Antigravity account and inspect the manager logs." >&2
    exit 1
fi

echo "Imported the Antigravity account from $database."
