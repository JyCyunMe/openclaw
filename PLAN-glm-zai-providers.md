# Implementation Plan: Z.AI / Zhipu AI GLM Provider Variants

## Overview

Currently, moltbot has a single `zai` provider that uses `https://api.z.ai/api/paas/v4`. This plan adds support for **four** distinct provider configurations to handle the different Z.AI/Zhipu AI endpoints:

| Provider ID | Base URL | Use Case |
|-------------|----------|----------|
| `zai` | `https://api.z.ai/api/paas/v4` | International, pay-as-you-go |
| `zai-coding` | `https://api.z.ai/api/coding/paas/v4` | International, Coding Plan subscription |
| `zhipu` | `https://open.bigmodel.cn/api/paas/v4` | China mainland, pay-as-you-go |
| `zhipu-coding` | `https://open.bigmodel.cn/api/coding/paas/v4` | China mainland, Coding Plan subscription |

All four use:
- OpenAI-compatible API (`openai-completions`)
- Bearer token authentication
- Same model IDs (e.g., `glm-4.7`, `glm-4.6`)

---

## Files to Modify

### 1. Type Definitions

**File:** `src/commands/onboard-types.ts`

Add new AuthChoice values:
```typescript
export type AuthChoice =
  // ... existing ...
  | "zai-api-key"
  | "zai-coding-api-key"    // NEW
  | "zhipu-api-key"         // NEW
  | "zhipu-coding-api-key"  // NEW
  // ...
```

**File:** `src/commands/auth-choice-options.ts`

Add to `AuthChoiceGroupId`:
```typescript
export type AuthChoiceGroupId =
  // ... existing ...
  | "zai"
  | "zhipu"  // NEW - separate group for China
  // ...
```

---

### 2. Auth Choice Options

**File:** `src/commands/auth-choice-options.ts`

Update `AUTH_CHOICE_GROUP_DEFS` - expand the `zai` group and add `zhipu` group:

```typescript
{
  value: "zai",
  label: "Z.AI (International)",
  hint: "GLM models via api.z.ai",
  choices: ["zai-api-key", "zai-coding-api-key"],
},
{
  value: "zhipu",
  label: "Zhipu AI (China)",
  hint: "GLM models via bigmodel.cn",
  choices: ["zhipu-api-key", "zhipu-coding-api-key"],
},
```

Update `buildAuthChoiceOptions()` to add the new options:
```typescript
options.push({ value: "zai-api-key", label: "Z.AI API key (pay-as-you-go)" });
options.push({
  value: "zai-coding-api-key",
  label: "Z.AI Coding Plan API key",
  hint: "Subscription-based, optimized for coding tools"
});
options.push({ value: "zhipu-api-key", label: "Zhipu AI API key (pay-as-you-go)" });
options.push({
  value: "zhipu-coding-api-key",
  label: "Zhipu AI Coding Plan API key",
  hint: "China mainland, subscription-based"
});
```

---

### 3. Credentials Functions

**File:** `src/commands/onboard-auth.credentials.ts`

Add constants and setter functions:

```typescript
// Existing
export const ZAI_DEFAULT_MODEL_REF = "zai/glm-4.7";

// New constants
export const ZAI_CODING_DEFAULT_MODEL_REF = "zai-coding/glm-4.7";
export const ZHIPU_DEFAULT_MODEL_REF = "zhipu/glm-4.7";
export const ZHIPU_CODING_DEFAULT_MODEL_REF = "zhipu-coding/glm-4.7";

// New setter functions
export async function setZaiCodingApiKey(key: string, agentDir?: string) {
  upsertAuthProfile({
    profileId: "zai-coding:default",
    credential: {
      type: "api_key",
      provider: "zai-coding",
      key,
    },
    agentDir: resolveAuthAgentDir(agentDir),
  });
}

export async function setZhipuApiKey(key: string, agentDir?: string) {
  upsertAuthProfile({
    profileId: "zhipu:default",
    credential: {
      type: "api_key",
      provider: "zhipu",
      key,
    },
    agentDir: resolveAuthAgentDir(agentDir),
  });
}

export async function setZhipuCodingApiKey(key: string, agentDir?: string) {
  upsertAuthProfile({
    profileId: "zhipu-coding:default",
    credential: {
      type: "api_key",
      provider: "zhipu-coding",
      key,
    },
    agentDir: resolveAuthAgentDir(agentDir),
  });
}
```

---

### 4. Config Application Functions

**File:** `src/commands/onboard-auth.config-core.ts`

Add new apply functions following the existing pattern:

```typescript
// Base URLs
const ZAI_BASE_URL = "https://api.z.ai/api/paas/v4";
const ZAI_CODING_BASE_URL = "https://api.z.ai/api/coding/paas/v4";
const ZHIPU_BASE_URL = "https://open.bigmodel.cn/api/paas/v4";
const ZHIPU_CODING_BASE_URL = "https://open.bigmodel.cn/api/coding/paas/v4";

// Model definition builder
function buildGlmModelDefinition(id: string = "glm-4.7"): ModelDefinitionConfig {
  return {
    id,
    name: `GLM ${id.replace("glm-", "")}`,
    api: "openai-completions",
    reasoning: true,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 205000,
    maxTokens: 16384,
    compat: { supportsDeveloperRole: false },
  };
}

// Apply functions for each variant
export function applyZaiCodingConfig(cfg: MoltbotConfig): MoltbotConfig { ... }
export function applyZhipuConfig(cfg: MoltbotConfig): MoltbotConfig { ... }
export function applyZhipuCodingConfig(cfg: MoltbotConfig): MoltbotConfig { ... }

// Provider config functions (register provider in models.providers)
export function applyZaiCodingProviderConfig(cfg: MoltbotConfig): MoltbotConfig { ... }
export function applyZhipuProviderConfig(cfg: MoltbotConfig): MoltbotConfig { ... }
export function applyZhipuCodingProviderConfig(cfg: MoltbotConfig): MoltbotConfig { ... }
```

---

### 5. Auth Choice Application

**File:** `src/commands/auth-choice.apply.api-providers.ts`

Add handling for the new auth choices in `applyAuthChoiceApiProviders()`:

1. Update the `tokenProvider` mapping section (~line 80):
```typescript
} else if (params.opts.tokenProvider === "zai-coding") {
  authChoice = "zai-coding-api-key";
} else if (params.opts.tokenProvider === "zhipu") {
  authChoice = "zhipu-api-key";
} else if (params.opts.tokenProvider === "zhipu-coding") {
  authChoice = "zhipu-coding-api-key";
}
```

2. Add new `if` blocks for each auth choice (following the pattern at line 371):
```typescript
if (authChoice === "zai-coding-api-key") {
  // Similar to zai-api-key but using:
  // - setZaiCodingApiKey()
  // - resolveEnvApiKey("zai-coding") with ZAI_CODING_API_KEY
  // - profileId: "zai-coding:default"
  // - applyZaiCodingConfig()
  // - ZAI_CODING_DEFAULT_MODEL_REF
}

if (authChoice === "zhipu-api-key") {
  // Similar pattern with:
  // - setZhipuApiKey()
  // - ZHIPU_API_KEY env var
  // - profileId: "zhipu:default"
  // - applyZhipuConfig()
}

if (authChoice === "zhipu-coding-api-key") {
  // Similar pattern with:
  // - setZhipuCodingApiKey()
  // - ZHIPU_CODING_API_KEY env var
  // - profileId: "zhipu-coding:default"
  // - applyZhipuCodingConfig()
}
```

---

### 6. Environment Variable Resolution

**File:** `src/agents/model-auth.ts`

Add env var mappings in `resolveEnvApiKey()` (~line 254):

```typescript
if (normalized === "zai") {
  return pick("ZAI_API_KEY") ?? pick("Z_AI_API_KEY");
}
if (normalized === "zai-coding") {
  return pick("ZAI_CODING_API_KEY") ?? pick("ZAI_API_KEY") ?? pick("Z_AI_API_KEY");
}
if (normalized === "zhipu") {
  return pick("ZHIPU_API_KEY");
}
if (normalized === "zhipu-coding") {
  return pick("ZHIPU_CODING_API_KEY") ?? pick("ZHIPU_API_KEY");
}
```

Note: The coding variants fall back to the general API key since the same key works on both endpoints.

---

### 7. Provider Normalization

**File:** `src/agents/model-selection.ts`

Update `normalizeProviderId()` to handle aliases:

```typescript
export function normalizeProviderId(provider: string): string {
  const normalized = provider.trim().toLowerCase();
  if (normalized === "z.ai" || normalized === "z-ai") return "zai";
  if (normalized === "z.ai-coding" || normalized === "z-ai-coding") return "zai-coding";
  if (normalized === "zhipuai" || normalized === "zhipu-ai") return "zhipu";
  if (normalized === "zhipuai-coding" || normalized === "zhipu-ai-coding") return "zhipu-coding";
  // ... existing ...
  return normalized;
}
```

---

### 8. Model Compatibility

**File:** `src/agents/model-compat.ts`

Update to handle all GLM provider variants:

```typescript
export function normalizeModelCompat(model: Model<Api>): Model<Api> {
  const baseUrl = model.baseUrl ?? "";
  const isGlm =
    model.provider === "zai" ||
    model.provider === "zai-coding" ||
    model.provider === "zhipu" ||
    model.provider === "zhipu-coding" ||
    baseUrl.includes("api.z.ai") ||
    baseUrl.includes("bigmodel.cn");

  if (!isGlm || !isOpenAiCompletionsModel(model)) return model;
  // ... force supportsDeveloperRole: false ...
}
```

---

### 9. Usage Tracking (Optional)

**File:** `src/infra/provider-usage.fetch.zai.ts`

Consider whether usage tracking needs updates for the different endpoints. The current implementation uses `https://api.z.ai/api/monitor/usage/quota/limit` which may only work for the international endpoint.

**File:** `src/infra/provider-usage.shared.ts`

Add labels for new providers:

```typescript
export const PROVIDER_LABELS: Record<string, string> = {
  // ... existing ...
  zai: "Z.AI",
  "zai-coding": "Z.AI Coding",
  zhipu: "Zhipu AI",
  "zhipu-coding": "Zhipu AI Coding",
};
```

---

### 10. Non-Interactive Onboarding

**File:** `src/commands/onboard-non-interactive/local/auth-choice.ts`

Add CLI flags and handling:

```typescript
// Add to opts interface
zaiCodingApiKey?: string;
zhipuApiKey?: string;
zhipuCodingApiKey?: string;

// Add detection logic
if (opts.zaiCodingApiKey) {
  return { authChoice: "zai-coding-api-key", token: opts.zaiCodingApiKey, tokenProvider: "zai-coding" };
}
if (opts.zhipuApiKey) {
  return { authChoice: "zhipu-api-key", token: opts.zhipuApiKey, tokenProvider: "zhipu" };
}
if (opts.zhipuCodingApiKey) {
  return { authChoice: "zhipu-coding-api-key", token: opts.zhipuCodingApiKey, tokenProvider: "zhipu-coding" };
}
```

---

## Documentation Updates

### 11. Provider Documentation

**File:** `docs/providers/zai.md`

Rewrite to explain all four variants:

```markdown
# Z.AI / Zhipu AI (GLM Models)

Z.AI and Zhipu AI provide access to GLM models. There are four provider configurations
depending on your region and subscription type:

## Provider Variants

| Provider | Region | Plan Type | Base URL |
|----------|--------|-----------|----------|
| `zai` | International | Pay-as-you-go | api.z.ai |
| `zai-coding` | International | Coding Plan | api.z.ai/coding |
| `zhipu` | China | Pay-as-you-go | bigmodel.cn |
| `zhipu-coding` | China | Coding Plan | bigmodel.cn/coding |

## Which should I use?

- **International users with pay-as-you-go**: Use `zai`
- **International users with Coding Plan subscription ($3-15/mo)**: Use `zai-coding`
- **China mainland users with pay-as-you-go**: Use `zhipu`
- **China mainland users with Coding Plan**: Use `zhipu-coding`

## CLI Setup

```bash
# International (pay-as-you-go)
moltbot onboard --auth-choice zai-api-key

# International (Coding Plan)
moltbot onboard --auth-choice zai-coding-api-key

# China (pay-as-you-go)
moltbot onboard --auth-choice zhipu-api-key

# China (Coding Plan)
moltbot onboard --auth-choice zhipu-coding-api-key
```

## Environment Variables

| Provider | Primary Env Var | Fallback |
|----------|-----------------|----------|
| `zai` | `ZAI_API_KEY` | `Z_AI_API_KEY` |
| `zai-coding` | `ZAI_CODING_API_KEY` | `ZAI_API_KEY` |
| `zhipu` | `ZHIPU_API_KEY` | - |
| `zhipu-coding` | `ZHIPU_CODING_API_KEY` | `ZHIPU_API_KEY` |

## Important Notes

- **Same API key, different endpoints**: Your API key works on both general and coding
  endpoints, but the billing is different. Using a Coding Plan key on the general
  endpoint may return error 1113 ("Insufficient balance").

- **Regional keys are not interchangeable**: Keys from z.ai don't work on bigmodel.cn
  and vice versa.

- **Coding endpoint optimized for tools**: The `/coding/` endpoints have better
  tool-calling performance and are recommended for use with coding assistants.
```

**File:** `docs/providers/glm.md`

Update to reference the four provider variants.

**File:** `docs/providers/index.md`

Add entries for the new providers.

---

## Testing

### 12. Unit Tests

**Files to create/update:**
- `src/commands/auth-choice-options.test.ts` - Test new auth choices appear
- `src/agents/model-selection.test.ts` - Test provider normalization
- `src/agents/model-compat.test.ts` - Test GLM compat for all variants

### 13. Live Tests (Optional)

**File:** `src/agents/zai.live.test.ts`

Consider adding tests for the coding endpoint variant.

---

## Implementation Order

1. **Phase 1: Types & Constants**
   - Update `onboard-types.ts` with new AuthChoice values
   - Add constants to `onboard-auth.credentials.ts`
   - Add base URLs to `onboard-auth.config-core.ts`

2. **Phase 2: Auth & Credentials**
   - Add setter functions in `onboard-auth.credentials.ts`
   - Add env var resolution in `model-auth.ts`
   - Add provider normalization in `model-selection.ts`

3. **Phase 3: Config Application**
   - Add apply functions in `onboard-auth.config-core.ts`
   - Wire up in `auth-choice.apply.api-providers.ts`

4. **Phase 4: UI & Options**
   - Update `auth-choice-options.ts` with new groups/options
   - Update non-interactive flow

5. **Phase 5: Compatibility & Usage**
   - Update `model-compat.ts`
   - Update `provider-usage.shared.ts`

6. **Phase 6: Documentation**
   - Rewrite `docs/providers/zai.md`
   - Update `docs/providers/glm.md`
   - Update `docs/providers/index.md`

7. **Phase 7: Testing**
   - Add/update unit tests
   - Manual testing of all four flows

---

## Open Questions

1. **Should the coding variants share the same API key env var?**
   - Current plan: `ZAI_CODING_API_KEY` falls back to `ZAI_API_KEY`
   - Alternative: Completely separate env vars

2. **Usage tracking for China endpoints?**
   - The current usage fetch uses `api.z.ai` - does bigmodel.cn have equivalent?

3. **Model catalog differences?**
   - Are all models available on all endpoints, or are some region-specific?

---

## References

- Implementation notes: `~/Developer/GLM-ZAI-provider-notes.md`
- Existing Z.AI implementation: `src/commands/auth-choice.apply.api-providers.ts:371-432`
- Provider pattern example: Moonshot/Kimi Code (two variants of same family)
