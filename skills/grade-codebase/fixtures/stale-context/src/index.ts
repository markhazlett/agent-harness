// Real entry point. Note: the actual architecture contradicts CLAUDE.md.
// There is no `services/` directory, no Makefile, and no `src/db/client.ts`.
// Handlers live here in `src/`, and they import `pg` directly — the exact
// opposite of what the (stale) agent guide claims.
import { Pool } from "pg";

const pool = new Pool();

export async function getUser(id: string) {
  const { rows } = await pool.query("select * from users where id = $1", [id]);
  return rows[0];
}
