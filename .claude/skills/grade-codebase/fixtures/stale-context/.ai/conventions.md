# Conventions (last meaningful update: project inception)

This project uses a microservice layout under `services/`. Each service owns
its own Postgres schema and is deployed independently. The `make` targets in
the root Makefile are the canonical entry points for every workflow.

Database access is centralised in `src/db/client.ts`, which wraps a connection
pool. Do not call the `pg` driver directly from a handler.

> Note: this file has not been revised since the original scaffold. The code
> has since been rewritten (see `src/`), but these notes were never updated —
> which is exactly the failure this fixture exists to catch.
