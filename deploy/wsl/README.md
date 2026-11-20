# Run Antigravity Tools in WSL

This starts the upstream headless server as a systemd user service. The proxy
listens on port `8045` and is restricted to the WSL loopback interface; WSL's
localhost forwarding makes it available to Windows at `http://localhost:8045`.

From the repository root, run:

```bash
./deploy/wsl/install.sh
```

The installer builds the checked-out frontend, verifies and extracts the
upstream v5.0.3 x86_64 Debian release, and downloads its GTK/WebKit runtime
libraries into `~/.local/opt` without installing system packages. It creates a
dedicated user service and stores the generated Web UI password and API key in
`~/.config/antigravity-tools/manager.env` with mode `0600`.

Open `http://localhost:8045` in Windows and use `WEB_PASSWORD` from that file
for the management UI. Configure Windows clients with the `API_KEY` from the
same file and base URL `http://localhost:8045/v1`. Do not expose port 8045 to
the LAN; this setup intentionally binds only to loopback.

The WSL process cannot scan Windows Antigravity's local account database as a
native Windows process would. The browser version of the manager offers OAuth
sign-in; its **Custom DB** file picker is desktop-only. To reuse an existing
Windows login, make the Windows drive available in WSL and submit the Windows
IDE database path to the import API (close Antigravity before copying or
importing its database):

```bash
WEB_PASSWORD=$(sed -n 's/^WEB_PASSWORD=//p' "$HOME/.config/antigravity-tools/manager.env")
curl --fail --request POST http://localhost:8045/api/accounts/import/db-custom \
  --header "x-api-key: $WEB_PASSWORD" --header 'Content-Type: application/json' \
  --data '{"path":"/mnt/c/Users/<Windows-user>/AppData/Roaming/Antigravity IDE/User/globalStorage/state.vscdb"}'
```

Replace `<Windows-user>` with the Windows account directory name. The import
reads the database and exchanges its refresh token with Google. If the Windows
drive is unavailable, add the account through the manager's OAuth flow.

Service commands:

```bash
systemctl --user status antigravity-tools.service
systemctl --user restart antigravity-tools.service
systemctl --user stop antigravity-tools.service
```
