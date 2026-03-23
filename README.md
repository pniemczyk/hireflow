# Modern Applications

AI-powered candidate screening platform that automates pre-screening through CV upload, AI-driven interview, and scored summaries for recruiters.

**Pipeline:** CV Upload → CV Processing & Scoring → AI Interview → Scored Summary + Pass/Reject decision

See [`IDEA.md`](./IDEA.md) for the full product spec, data model, planned routes, and AI architecture.

## Setup

```bash
./bin/setup   # install deps + prepare DB
mise up       # start all services (Rails + Vite + Caddy)
```

App runs at `https://apl.localhost`.

## Development

See [`CLAUDE.md`](./CLAUDE.md) for all commands (testing, linting, database, etc.) and architecture overview.
