# Working notes for this repository (Base44 sandbox)

This repository is the **GitHub MCP Server**: a Go MCP server (`cmd/github-mcp-server`,
toolsets in `pkg/github`) plus a React/Primer bundle of **MCP App UIs** (`ui/`) that are
embedded into the binary. It is not a web application — there is no product frontend and
no HTML is served by the Go server. The one browser surface here is the sandbox preview
console described below.

## Running it in the sandbox

```bash
docker compose -f docker-compose.base44.yml up -d --build   # start
docker compose -f docker-compose.base44.yml ps              # status
docker compose -f docker-compose.base44.yml logs -f api     # server + air logs
```

Services:

| service    | what it is                                                                   | host port |
| ---------- | ---------------------------------------------------------------------------- | --------- |
| `api`      | Go server built from the bind mount, run as `github-mcp-server http` by `air` | 8000      |
| `web`      | nginx serving `dev/preview/index.html`, proxies `/mcp` to `api`               | 3000      |
| `ui-build` | one-shot: `npm ci && npm run build` in `ui/` (writes `pkg/github/ui_dist/`)   | –         |

`dev/preview/` and `docker-compose.base44.yml` are sandbox-only tooling.

## Non-obvious things that cost time

- **Every MCP request needs an `Authorization` header**, and the *shape* is validated
  before routing: `Bearer` + a token starting with `ghp_`/`gho_`/`github_pat_`/… or a
  40-char hex legacy token. Anything else is `400 Authorization header is badly
  formatted`; a missing header is `401` + `WWW-Authenticate`. The preview console
  therefore sends a placeholder `ghp_placeholder` for the token-less handshake —
  listing tools works, calling a GitHub-backed tool does not.
- **A token is required but never configured on the server.** In `http` mode the token
  comes from the request, not `GITHUB_PERSONAL_ACCESS_TOKEN`; nothing needs to be
  provisioned for the server to boot. Real GitHub data needs a PAT pasted into the
  console (kept in that tab's `sessionStorage` only) or sent by a real MCP client.
- **UI bundles are embedded at compile time.** `pkg/github/ui_dist/*.html` is gitignored
  and produced by the `ui-build` service; `pkg/github/ui_embed.go` (`go:embed`) bakes it
  into the binary. After editing `ui/`, rebuild that one-shot service and restart `api`,
  otherwise `resources/list` keeps serving the old HTML (and, with no bundles, the four
  `ui://github-mcp-server/…` resources are simply not registered).
- **Toolchains are pinned high:** `go.mod` needs Go ≥ 1.26.8 (dev image uses
  `golang:1.27.1-alpine`), `ui/package.json` needs Node `^26` (`node:26-alpine`).
- `delete_repository disabled: request-state encryption key is not configured` in the
  logs is expected; set `GITHUB_MCP_SERVER_MRTR_STATE_KEY` (base64, 32 bytes) to expose
  that tool.
- Go live reload is `air` with polling enabled (`dev/preview/air.toml`); a rebuild takes
  ~10–15 s and the container restarts its child process, so a healthcheck blip is normal.

## Verifying

```bash
# unauthenticated: proves the HTTP server is up
curl -s localhost:3000/.well-known/oauth-protected-resource

# MCP over streamable HTTP (SSE response); any token-shaped string works for listing
TOK=ghp_localcheck
curl -s -X POST localhost:3000/mcp -H "Authorization: Bearer $TOK" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -H 'Mcp-Method: tools/list' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

`tools/list` returns 46 tools; `resources/list` returns the four MCP App UIs when the
`ui-build` service has populated `pkg/github/ui_dist`.

Tests run inside the container:

```bash
docker compose -f docker-compose.base44.yml exec -T api go test ./pkg/http/...
```

`e2e/e2e_test.go` talks to the real GitHub API and needs a token; it is not part of the
sandbox loop.
