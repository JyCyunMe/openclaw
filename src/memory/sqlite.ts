import { createRequire } from "node:module";
import { installProcessWarningFilter } from "../infra/warning-filter.js";

const require = createRequire(import.meta.url);

type NodeSqliteModule = typeof import("node:sqlite");
type NodeDatabaseSync = import("node:sqlite").DatabaseSync;

type BunSqliteModule = {
  Database: new (
    path: string,
    options?: { readonly?: boolean; create?: boolean },
  ) => BunDatabase;
};

type BunDatabase = {
  prepare(sql: string): BunStatement;
  exec(sql: string): void;
  close(): void;
  loadExtension(path: string): void;
};

type BunStatement = {
  run(...params: unknown[]): { changes: number; lastInsertRowid: number };
  get(...params: unknown[]): unknown;
  all(...params: unknown[]): unknown[];
};

class BunStatementWrapper {
  private _stmt: BunStatement;
  constructor(stmt: BunStatement) {
    this._stmt = stmt;
  }
  run(...params: unknown[]): unknown {
    const converted = params.map((p) =>
      Buffer.isBuffer(p) ? new Uint8Array(p.buffer, p.byteOffset, p.byteLength) : p,
    );
    return this._stmt.run(...converted);
  }
  get(...params: unknown[]): unknown {
    const converted = params.map((p) =>
      Buffer.isBuffer(p) ? new Uint8Array(p.buffer, p.byteOffset, p.byteLength) : p,
    );
    return this._stmt.get(...converted);
  }
  all(...params: unknown[]): unknown[] {
    const converted = params.map((p) =>
      Buffer.isBuffer(p) ? new Uint8Array(p.buffer, p.byteOffset, p.byteLength) : p,
    );
    return this._stmt.all(...converted);
  }
}

let _cachedModule: NodeSqliteModule | BunSqliteModule | null = null;
let _sqliteType: "node" | "bun" | null = null;

export function getSqliteType(): "node" | "bun" | null {
  return _sqliteType;
}

function requireSqliteInternal(): NodeSqliteModule | BunSqliteModule {
  if (_cachedModule) {
    return _cachedModule;
  }

  installProcessWarningFilter();

  try {
    _cachedModule = require("node:sqlite") as NodeSqliteModule;
    _sqliteType = "node";
    return _cachedModule;
  } catch {}

  try {
    _cachedModule = require("bun:sqlite") as BunSqliteModule;
    _sqliteType = "bun";
    return _cachedModule;
  } catch {}

  throw new Error(
    "SQLite support unavailable. Use Node 22+ (built-in node:sqlite) or Bun (built-in bun:sqlite).",
  );
}

type DatabaseSyncOptions = {
  allowExtension?: boolean;
  readOnly?: boolean;
};

class BunDatabaseSync {
  private _db: BunDatabase;
  constructor(path: string, options?: DatabaseSyncOptions) {
    const { Database } = require("bun:sqlite") as BunSqliteModule;
    // bun:sqlite uses 'create' option, not 'allowExtension'
    this._db = new Database(path, {
      readonly: options?.readOnly,
      create: options?.readOnly ? false : true,
    });
  }
  prepare(sql: string) {
    const stmt = this._db.prepare(sql);
    return new BunStatementWrapper(stmt);
  }
  exec(sql: string) {
    return this._db.exec(sql);
  }
  close() {
    return this._db.close();
  }
  loadExtension(path: string) {
    return this._db.loadExtension(path);
  }
  enableLoadExtension(_enable: boolean) {
    // bun:sqlite loads extensions directly without enabling
  }
}

function createBunSqliteModule(): { DatabaseSync: typeof BunDatabaseSync } {
  return { DatabaseSync: BunDatabaseSync };
}

export function requireNodeSqlite(): NodeSqliteModule | { DatabaseSync: typeof BunDatabaseSync } {
  requireSqliteInternal();
  if (_sqliteType === "node") {
    return _cachedModule as NodeSqliteModule;
  }
  return createBunSqliteModule();
}
