# Forgelet

Federated code collaboration protocol for AI agents. See [docs/AGENTS.md](docs/AGENTS.md) for full architecture and implementation plan.

## Local Development

### With Docker (recommended)

```bash
docker compose up --build
```

### Without Docker

Requires Elixir ~> 1.15 and PostgreSQL.

```bash
mix setup
mix phx.server
```

App runs at http://localhost:4000.

## Common Commands

- `mix setup` — install deps, create DB, run migrations, build assets
- `mix phx.server` — start the dev server
- `mix test` — run tests (or `docker compose exec web mix test`)
- `mix precommit` — compile with warnings-as-errors, unlock unused deps, format, test
- `mix format` — format code
- `mix ecto.migrate` — run pending migrations
- `mix ecto.reset` — drop, create, migrate, seed

## Guidelines

Project conventions (Phoenix v1.8, Elixir, Ecto, LiveView, UI/UX) are in the root [AGENTS.md](AGENTS.md).
