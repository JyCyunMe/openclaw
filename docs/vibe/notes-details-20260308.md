# 问题修复笔记

## 日期：2026-03-08

---

## 1. SQLite node/bun 降级封装

### 问题描述

- **文件**: `src/memory/sqlite.ts`, `src/memory/sqlite-vec.ts`
- **现象**: Bun 运行时下 `node:sqlite` 不可用，导致 gateway 启动失败
- **原因**: Node.js 22+ 内置 `node:sqlite`，Bun 内置 `bun:sqlite`，两者 API 不同

### 解决方案

1. **封装层设计** (`src/memory/sqlite.ts`)
   - 缓存模块加载，只尝试一次
   - 优先 `node:sqlite`，失败后降级 `bun:sqlite`
   - 创建 `BunDatabaseSync` 适配器类，统一 API

2. **API 差异处理**
   ```typescript
   // node:sqlite
   new DatabaseSync(path, { allowExtension: true, readOnly: true })
   db.enableLoadExtension(true)
   db.loadExtension(path)
   
   // bun:sqlite (适配后)
   new BunDatabaseSync(path, { allowExtension: true, readOnly: true })
   db.enableLoadExtension(true)  // 空实现，bun 直接加载
   db.loadExtension(path)
   ```

3. **sqlite-vec 兼容**
   - `sqlite-vec.load()` 同时支持 node 和 bun
   - 根据 `getSqliteType()` 选择加载方式

### 影响范围

- ✅ Node.js 22+ 不受影响
- ✅ Bun 环境自动降级
- ⚠️ macOS + bun + sqlite-vec 需要配置自定义 SQLite 库：
  ```typescript
  Database.setCustomSQLite("/usr/local/opt/sqlite3/lib/libsqlite3.dylib");
  ```

### 提交

- 分支: `refactor/sqlite`
- Commit: `refactor(sqlite): add bun:sqlite fallback support`

---

## 2. Web Search Exa Provider

### 问题描述

- **文件**: `src/agents/tools/web-search.ts`
- **现象**: 需要一个无需 API Key 的默认搜索提供商
- **需求**: Exa 搜索作为默认回退

### 解决方案

1. **Exa MCP 集成**
   - 端点: `https://mcp.exa.ai/mcp`
   - 认证: 无需 API Key（免费层）
   - 协议: JSON-RPC 2.0 (MCP)

2. **配置支持**
   ```json
   {
     "tools": {
       "web": {
         "search": {
           "provider": "exa",
           "exa": {
             "numResults": 8,
             "livecrawl": "fallback",
             "type": "auto"
           }
         }
       }
     }
   }
   ```

3. **自动检测优先级**
   ```
   Perplexity → Brave → Gemini → Grok → Kimi → Exa (默认)
   ```

### 影响范围

- ✅ 无 API Key 时自动使用 Exa
- ✅ 可显式配置 `provider: "exa"`
- ✅ 更新了 schema labels 和 help text

### 提交

- 分支: `feat/web-search-exa`
- Commit: `feat(web-search): add Exa search provider`

---

## 3. Memory Search Remote 配置

### 问题描述

- **文件**: `src/memory/embeddings-remote-client.ts`
- **现象**: 第三方 embedding 端点配置不清晰
- **需求**: SiliconFlow 等 OpenAI 兼容端点的正确配置

### 解决方案

详细笔记见: [memory-search-remote-config.md](./memory-search-remote-config.md)

关键点：
- `provider: "openai"` 使用 OpenAI 兼容格式
- `baseUrl` 自动拼接 `/embeddings`
- 第三方端点禁用 `batch.enabled`

### 提交

- 笔记文件: `docs/vibe/memory-search-remote-config.md`

---

## 4. Web Search TypeScript apiKey 类型错误

### 问题描述

- **文件**: `src/agents/tools/web-search.ts`
- **现象**: 编译错误 `Type 'string | undefined' is not assignable to type 'string'`
- **原因**: `runWebSearch` 的 `apiKey` 参数类型是 `string | undefined`，但各 provider 函数期望 `string`

### 解决方案

1. **使用空值合并运算符**
   ```typescript
   // 修改前
   apiKey: params.apiKey,  // string | undefined
   
   // 修改后
   apiKey: params.apiKey ?? "",  // string
   ```

2. **Brave Search 特殊处理**
   ```typescript
   // 条件展开 header，避免 undefined 值
   headers: {
     Accept: "application/json",
     ...(params.apiKey ? { "X-Subscription-Token": params.apiKey } : {}),
   }
   ```

3. **添加显式泛型类型**
   ```typescript
   const mapped = await withTrustedWebSearchEndpoint<
     Array<{ title: string; url: string; description: string; ... }>
   >(...)
   ```

### 提交

- 分支: `feat/web-search-exa`
- Commit: `fix(web-search): fix TypeScript errors for optional apiKey`

---

## 5. Zod Schema 验证错误 (exa provider)

### 问题描述

- **文件**: `src/config/zod-schema.agent-runtime.ts`
- **现象**: 配置 `provider: "exa"` 报错 `Invalid input (allowed: "brave", "perplexity", "grok", "gemini", "kimi")`
- **原因**: Zod schema 的 `ToolsWebSearchSchema` 没有包含 `z.literal("exa")`

### 解决方案

1. **更新 provider 枚举**
   ```typescript
   provider: z.union([
     z.literal("brave"),
     z.literal("perplexity"),
     z.literal("grok"),
     z.literal("gemini"),
     z.literal("kimi"),
     z.literal("exa"),  // ← 新增
   ]).optional(),
   ```

2. **添加 exa 配置 schema**
   ```typescript
   exa: z.object({
     baseUrl: z.string().optional(),
     numResults: z.number().int().min(1).max(20).optional(),
     livecrawl: z.union([z.literal("fallback"), z.literal("preferred")]).optional(),
     type: z.union([z.literal("auto"), z.literal("fast"), z.literal("deep")]).optional(),
     contextMaxCharacters: z.number().int().positive().optional(),
   }).strict().optional(),
   ```

### 关键点

TypeScript 类型定义 (`types.tools.ts`) 和 Zod schema (`zod-schema.agent-runtime.ts`) 是**两套独立系统**：
- 类型定义影响编译时类型检查
- Zod schema 影响运行时配置验证
- **两者必须同步更新**

### 提交

- 分支: `feat/web-search-exa`
- Commit: `fix(config): add exa to zod validation schema`

---
