#!/usr/bin/env bash
set -euo pipefail

version=5.0.3
sha256=34e76123974225222b79ee9f19d5e26f7bf7f065e0c0b196d07ce997968a2a3d
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
app_dir="$HOME/.local/opt/antigravity-tools/$version"
runtime_dir="$HOME/.local/opt/antigravity-runtime"
config_dir="$HOME/.config/antigravity-tools"
data_dir="$HOME/.local/share/antigravity-tools"
unit_dir="$HOME/.config/systemd/user"
app_deb=${1:-}
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

for command in curl sha256sum dpkg-deb apt-get npm openssl systemctl python3; do
    command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

if [[ -z "$app_deb" ]]; then
    app_deb="$tmp_dir/Antigravity.Tools_${version}_amd64.deb"
    curl --fail --location --retry 5 --retry-all-errors --output "$app_deb" \
        "https://github.com/lbjlaq/Antigravity-Manager/releases/download/v${version}/Antigravity.Tools_${version}_amd64.deb"
fi

actual_sha=$(sha256sum "$app_deb" | cut -d ' ' -f 1)
if [[ "$actual_sha" != "$sha256" ]]; then
    echo "Release checksum mismatch for $app_deb" >&2
    exit 1
fi

if [[ ! -x "$root/node_modules/.bin/vite" ]]; then
    (cd "$root" && npm ci --legacy-peer-deps --no-audit --no-fund)
fi
(cd "$root" && npm run build)

mkdir -p "$app_dir" "$runtime_dir" "$config_dir" "$data_dir" "$unit_dir"
chmod 700 "$config_dir" "$data_dir"
dpkg-deb --extract "$app_deb" "$app_dir"

# Keep the host distro unchanged: fetch the pinned Ubuntu runtime library set
# into this user's home and let the service load those libraries privately.
if [[ ! -e "$runtime_dir/usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.1.so.0" ]]; then
    runtime_packages=(
        libayatana-appindicator3-1 libayatana-indicator3-7 libdbusmenu-glib4 libdbusmenu-gtk3-4
        libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 libsoup-3.0-0
        libwebpdemux2 libwebpmux3 libxslt1.1 libwoff1
        libgstreamer-plugins-base1.0-0 libgstreamer-gl1.0-0 libharfbuzz-icu0
        libenchant-2-2 libhyphen0 libmanette-0.2-0 liborc-0.4-0 libgudev-1.0-0 libevdev2
    )
    (
        cd "$tmp_dir"
        apt-get download "${runtime_packages[@]}"
        for package in ./*.deb; do
            dpkg-deb --extract "$package" "$runtime_dir"
        done
    )
fi

env_file="$config_dir/manager.env"
if [[ ! -s "$env_file" ]]; then
    umask 077
    cat >"$env_file" <<EOF
API_KEY=sk-$(openssl rand -hex 32)
WEB_PASSWORD=$(openssl rand -hex 24)
ABV_BIND_LOCAL_ONLY=true
ABV_DATA_DIR=$data_dir
ABV_DIST_PATH=$root/dist
RUST_LOG=info
EOF
fi
chmod 600 "$env_file"

cat >"$unit_dir/antigravity-tools.service" <<EOF
[Unit]
Description=Antigravity Tools local reverse proxy
After=network-online.target

[Service]
Type=simple
EnvironmentFile=$env_file
Environment=LD_LIBRARY_PATH=$runtime_dir/usr/lib/x86_64-linux-gnu:$runtime_dir/usr/lib
WorkingDirectory=$root
ExecStart=$app_dir/usr/bin/antigravity-tools --headless
Restart=on-failure
RestartSec=5
UMask=0077

[Install]
WantedBy=default.target
EOF
chmod 600 "$unit_dir/antigravity-tools.service"

systemctl --user daemon-reload
systemctl --user enable --now antigravity-tools.service

for _ in $(seq 1 30); do
    if curl --silent --fail http://127.0.0.1:8045/health >/dev/null; then
        printf 'Proxy is ready: http://localhost:8045\n'
        printf 'Web UI credential file: %s\n' "$env_file"
        printf 'Use API_KEY from that file for clients at http://localhost:8045/v1\n'
        exit 0
    fi
    sleep 1
done

echo "The service did not become healthy. Check: systemctl --user status antigravity-tools.service" >&2
exit 1
