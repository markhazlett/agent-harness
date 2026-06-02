# Acme API — Agent Guide

> Architecture notes and conventions live in `.ai/conventions.md`. Read that first.

## Commands

- Run the test suite: `make test`
- Start the dev server: `make dev`
- Lint: `make lint`

## Project structure

- HTTP handlers live in `services/` — one folder per microservice.
- Shared database access goes through `src/db/client.ts`. Never import `pg` directly.
- Background jobs are registered in `services/worker/jobs.ts`.

## Code style

- All new endpoints follow the pattern in `services/users/handler.ts`.
