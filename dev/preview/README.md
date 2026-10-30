# Sandbox preview stack

Everything here exists only to run this repository inside the Base44 sandbox.
It is not part of the shipped GitHub MCP Server.

- `index.html` — a small console served on port 3000. It performs a real MCP
  handshake against the running Go server (`initialize` → `notifications/initialized`
  → `tools/list` → `resources/list`), and can call any listed tool. GitHub-backed
  tools need a personal access token, which the console keeps in the browser tab's
  `sessionStorage` only; nothing is sent anywhere else.
- `nginx.conf` — serves that page and proxies the server's Streamable HTTP
  endpoint under `/mcp`, so the console and the API share one origin.
- `air.toml` — live-reload config: rebuilds `cmd/github-mcp-server` and restarts
  `github-mcp-server http` on Go source changes.
- `go-dev.Dockerfile` — Go toolchain plus `air`. The repository is bind-mounted,
  never baked in.

Start it from the repository root:

```bash
docker compose -f docker-compose.base44.yml up -d --build
```

Ports: `3000` preview console, `8000` the MCP endpoint itself (point a real MCP
client at `https://<8000-host>/`). UI source changes are not watched — rebuild
those with `docker compose -f docker-compose.base44.yml run --rm ui-build` and
then restart `api` (the bundles are embedded at compile time).
