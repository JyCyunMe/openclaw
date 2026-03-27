import type { DatabaseSync } from "./sqlite.js";
import { getSqliteType } from "./sqlite.js";

export async function loadSqliteVecExtension(params: {
  db: DatabaseSync;
  extensionPath?: string;
}): Promise<{ ok: boolean; extensionPath?: string; error?: string }> {
  try {
    const sqliteVec = await import("sqlite-vec");
    const resolvedPath = params.extensionPath?.trim() ? params.extensionPath.trim() : undefined;
    const extensionPath = resolvedPath ?? sqliteVec.getLoadablePath();

    const sqliteType = getSqliteType();

    if (sqliteType === "bun") {
      sqliteVec.load(params.db as unknown as import("bun:sqlite").Database);
    } else {
      params.db.enableLoadExtension(true);
      if (resolvedPath) {
        params.db.loadExtension(extensionPath);
      } else {
        sqliteVec.load(params.db);
      }
    }

    return { ok: true, extensionPath };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { ok: false, error: message };
  }
}
