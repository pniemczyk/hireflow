# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

AI-powered candidate screening platform. Candidates upload a CV, the system scores it against job criteria, then conducts an adaptive AI-driven interview, producing a scored summary with red flags and strengths for a human recruiter to make the final call.

**Pipeline:** CV Upload (Stage 1) → CV Processing & Scoring (Stage 2) → AI Interview — checklist-driven adaptive loop (Stage 3) → Scored Summary + Pass/Reject (Stage 4)

**AI stack:** Claude API for CV extraction, CV evaluation, interview conduction, and summary generation. ElevenLabs for TTS voice output.

Full product spec, data model, planned routes, and file structure: [`IDEA.md`](./IDEA.md)

---

## Agent OS Documentation

### Product Context
- **Mission & Vision:** @.agent-os/product/mission.md
- **Technical Architecture:** @.agent-os/product/tech-stack.md
- **Development Roadmap:** @.agent-os/product/roadmap.md
- **Decision History:** @.agent-os/product/decisions.md

### Development Standards
- **Code Style:** @~/.agent-os/standards/code-style.md
- **Best Practices:** @~/.agent-os/standards/best-practices.md

### Project Management
- **Active Specs:** @.agent-os/specs/
- **Spec Planning:** Use `@~/.agent-os/instructions/create-spec.md`
- **Tasks Execution:** Use `@~/.agent-os/instructions/execute-tasks.md`

## Workflow Instructions

When asked to work on this codebase:

1. **First**, check @.agent-os/product/roadmap.md for current priorities
2. **Then**, follow the appropriate instruction file:
   - For new features: @.agent-os/instructions/create-spec.md
   - For tasks execution: @.agent-os/instructions/execute-tasks.md
3. **Always**, adhere to the standards in the files listed above

## Important Notes

- Product-specific files in `.agent-os/product/` override any global standards
- User's specific instructions override (or amend) instructions found in `.agent-os/specs/...`
- Always adhere to established patterns, code style, and best practices documented above.

---

## Development Commands

### Setup
```bash
./bin/setup          # Install deps, prepare DB
./bin/setup --reset  # Reset DB during setup
```

### Running the App
```bash
mise up              # Start all services via Overmind (web + vite + caddy)
mise down            # Stop all services
```
The app runs at `https://apl.localhost` (Caddy reverse proxy on port 3110).

Individual services:
- Rails: `bin/rails server -p 3120`
- Vite: `bin/vite dev` (port 3066)
- Caddy: `caddy run --config Caddyfile`

### Testing
```bash
bin/rails test                              # All unit/integration tests
bin/rails test test/models/foo_test.rb      # Single test file
bin/rails test test/models/foo_test.rb:42   # Single test at line number
bin/rails test:system                       # Capybara system tests
bin/ci                                      # Full CI pipeline (lint + security + tests)
```

### Linting & Security
```bash
bin/rubocop                    # Lint Ruby (omakase preset)
bin/brakeman --quiet           # Security scan
bin/bundler-audit              # Gem vulnerability check
```

### Database
```bash
bin/rails db:prepare   # Create + migrate
bin/rails db:reset     # Drop + create + seed
```

### Dependencies
```bash
bundle install    # Ruby gems
yarn install      # JS packages
mise pull         # git pull + bundle + yarn
```

---

## Architecture

### Stack
- **Rails 8.1** with SQLite (4 databases: primary, cache, queue, cable)
- **Solid Queue / Cache / Cable** for background jobs, caching, WebSockets
- **Vite** (port 3066) for frontend assets, served via Caddy reverse proxy
- **Stimulus + Turbo** for interactivity; React islands possible via Stimulus bridge
- **TailwindCSS v4** (CSS-first config) + DaisyUI + Iconify (Lucide icons)
- **Active Storage** for file uploads (CV PDFs)
- **Minitest** for unit/integration tests; Capybara + Selenium for system tests

### Frontend Structure
- Entry points: `app/frontend/entrypoints/application.{js,css}`
- JavaScript lives in `app/frontend/javascript/` — Stimulus controllers in `controllers/*_controller.js`, auto-registered
- CSS lives in `app/frontend/stylesheets/` — `application.tailwind.css` is the Tailwind v4 CSS-first config
- `@/` path alias resolves to `app/frontend`
- Vite reloads on changes to routes.rb, helpers, views, and frontend files

### Processes & Ports
| Service | Port | Notes |
|---------|------|-------|
| Caddy (public) | 3110 | `apl.localhost` with internal TLS |
| Rails | 3120 | Behind Caddy |
| Vite HMR | 3066 | Behind Caddy at `vite.apl.localhost` |

### CI/CD (GitHub Actions)
Five jobs: `scan_ruby` (Brakeman + bundler-audit), `lint` (RuboCop), `test`, `system-test` (optional), artifact upload for failed screenshots.

### Design System
Stage designs live in `materials/design/`. The "Ethereal Agent" dark aesthetic uses deep charcoal (#131313), glassmorphism, and dual-font (Manrope + Inter). Reference `materials/design/1_CV_upload/DESIGN.md` and `materials/design/2_AI_interview/DESIGN.md` before building UI.
