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
native Windows process would. Once `/mnt/c` is available, import the Windows
login by passing the Windows profile directory name:

```bash
./deploy/wsl/import-windows-account.sh <Windows-user>
```

The helper checks the Antigravity IDE and Classic profile locations, then asks
the manager to read the database and exchange its refresh token with Google.

If `/mnt/c` is unavailable, close Antigravity and use Windows File Explorer to
copy your `state.vscdb` (from `%APPDATA%\Antigravity IDE\User\globalStorage` or
the corresponding `Antigravity` folder) to
`\\wsl.localhost\<distro>\home\<Linux-user>\.local\share\antigravity-tools`.
Then import the copy from WSL:

```bash
./deploy/wsl/import-windows-account.sh --db "$HOME/.local/share/antigravity-tools/state.vscdb"
```

The backup can contain login credentials. Keep it in the private data directory,
and remove the copy after a successful import. If the installed Antigravity
version does not store an importable login in this database, use **Accounts →
Add Account → OAuth** in the management UI to authorize the same Google account.

Service commands:

```bash
systemctl --user status antigravity-tools.service
systemctl --user restart antigravity-tools.service
systemctl --user stop antigravity-tools.service
```
