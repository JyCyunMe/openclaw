# Memory Search Remote 配置笔记

## 配置路径

- `agents.defaults.memorySearch.remote` — 默认设置
- `agents.list[].memorySearch.remote` — 每个 agent 可覆盖

## Provider 请求 URL 拼接逻辑

### baseUrl 解析优先级

```
remote.baseUrl → models.providers.{provider}.baseUrl → defaultBaseUrl
```

源码位置: `src/memory/embeddings-remote-client.ts:31`

```typescript
const baseUrl = remoteBaseUrl || providerConfig?.baseUrl?.trim() || params.defaultBaseUrl;
```

### 最终端点拼接

源码位置: `src/memory/embeddings-remote-provider.ts:23`

```typescript
const url = `${client.baseUrl.replace(/\/$/, "")}/embeddings`;
```

**示例**:
- `baseUrl: "https://api.openai.com/v1"` → `https://api.openai.com/v1/embeddings`
- `baseUrl: "https://my-proxy.com/api"` → `https://my-proxy.com/api/embeddings`

## 完整请求流程

```
配置:
  memorySearch.provider = "openai"
  memorySearch.remote.baseUrl = "xxx" (可选)
  memorySearch.remote.apiKey = "sk-xxx" (可选)
  models.providers.openai.baseUrl = "yyy" (可选)

                    ↓
                    
resolveRemoteEmbeddingBearerClient():
  1. 确定 apiKey:
     remote.apiKey || resolveApiKeyForProvider("openai")
     
  2. 确定 baseUrl:
     remote.baseUrl || models.providers.openai.baseUrl || "https://api.openai.com/v1"

  3. 构建 headers:
     { "Content-Type": "application/json", "Authorization": "Bearer xxx" }

                    ↓

createRemoteEmbeddingProvider():
  拼接 URL: `${baseUrl}/embeddings`

                    ↓

HTTP POST:
  URL: https://api.openai.com/v1/embeddings
  Body: { model: "text-embedding-3-small", input: [...] }
  Headers: { Authorization: "Bearer sk-xxx", ... }
```

## 模型名处理

`normalizeOpenAiModel` (`src/memory/embeddings-openai.ts:23-32`):

```typescript
export function normalizeOpenAiModel(model: string): string {
  const trimmed = model.trim();
  if (!trimmed) return DEFAULT_OPENAI_EMBEDDING_MODEL;
  if (trimmed.startsWith("openai/")) return trimmed.slice("openai/".length);
  return trimmed; // 非 openai/ 前缀直接返回
}
```

- `BAAI/bge-m3` → 原样传递
- `openai/text-embedding-3-small` → `text-embedding-3-small`

## 第三方兼容端点配置示例

### SiliconFlow

```json
"memorySearch": {
  "enabled": true,
  "provider": "openai",
  "remote": {
    "baseUrl": "https://api.siliconflow.cn/v1",
    "apiKey": "sk-xxx...",
    "batch": {
      "enabled": false
    }
  },
  "fallback": "none",
  "model": "BAAI/bge-m3"
}
```

**请求示例**:

```bash
curl --request POST \
  --url https://api.siliconflow.cn/v1/embeddings \
  --header 'Authorization: Bearer <token>' \
  --header 'Content-Type: application/json' \
  --data '{
    "model": "BAAI/bge-m3",
    "input": ["文本1", "文本2"]
  }'
```

## Batch API 注意事项

### Batch API vs 标准 API

| 特性 | 标准 API | Batch API |
|------|----------|-----------|
| 端点 | `/embeddings` | `/batches` |
| 方式 | 同步请求 | 异步批处理 |
| 第三方兼容端点 | ✅ 通常支持 | ❌ 通常不支持 |

### Batch API 流程 (OpenAI 官方)

1. `POST /files` — 上传 JSONL 文件
2. `POST /batches` — 创建 batch job
3. `GET /batches/{id}` — 轮询状态
4. `GET /files/{id}/content` — 下载结果

### 支持 Batch 的 Provider

- `openai` (仅官方端点 `api.openai.com`)
- `gemini`
- `voyage`

### 第三方端点配置

```json
"remote": {
  "batch": {
    "enabled": false  // 必须禁用
  }
}
```

## 相关源码文件

- `src/memory/embeddings.ts` — 入口，provider 选择逻辑
- `src/memory/embeddings-remote-client.ts` — baseUrl/apiKey 解析
- `src/memory/embeddings-remote-provider.ts` — URL 拼接，请求执行
- `src/memory/embeddings-openai.ts` — OpenAI provider 实现
- `src/memory/batch-openai.ts` — OpenAI Batch API 实现
- `src/memory/manager-embedding-ops.ts` — batch 启用判断逻辑
