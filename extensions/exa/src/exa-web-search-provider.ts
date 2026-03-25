import { Type } from "@sinclair/typebox";
import {
  buildSearchCacheKey,
  DEFAULT_SEARCH_COUNT,
  MAX_SEARCH_COUNT,
  formatCliCommand,
  readCachedSearchPayload,
  readConfiguredSecretString,
  readNumberParam,
  readProviderEnvValue,
  readStringParam,
  resolveProviderWebSearchPluginConfig,
  resolveSearchCacheTtlMs,
  resolveSearchCount,
  resolveSearchTimeoutSeconds,
  setTopLevelCredentialValue,
  setProviderWebSearchPluginConfigValue,
  type SearchConfigRecord,
  type WebSearchProviderPlugin,
  type WebSearchProviderToolDefinition,
  withTrustedWebSearchEndpoint,
  writeCachedSearchPayload,
} from "openclaw/plugin-sdk/provider-web-search";

const DEFAULT_EXA_ENDPOINT = "https://mcp.exa.ai/mcp";

type ExaConfig = {
  baseUrl?: string;
};

type ExaMcpRequest = {
  jsonrpc: "2.0";
  id: number;
  method: "tools/call";
  params: {
    name: "web_search_exa";
    arguments: {
      query: string;
      numResults?: number;
      livecrawl?: "fallback" | "preferred";
      type?: "auto" | "fast" | "deep";
      contextMaxCharacters?: number;
    };
  };
};

type ExaMcpResponse = {
  result?: {
    content: Array<{ type: string; text: string }>;
  };
  error?: {
    code: number;
    message: string;
  };
};

type ExaSearchResult = {
  title: string;
  url: string;
  publishedDate?: string;
  score?: number;
};

function resolveExaConfig(searchConfig?: SearchConfigRecord): ExaConfig {
  const exa = searchConfig?.exa;
  return exa && typeof exa === "object" && !Array.isArray(exa) ? (exa as ExaConfig) : {};
}

function resolveExaApiKey(searchConfig?: SearchConfigRecord): string | undefined {
  return (
    readConfiguredSecretString(searchConfig?.apiKey, "tools.web.search.apiKey") ??
    readProviderEnvValue(["EXA_API_KEY"])
  );
}

function resolveExaBaseUrl(exa?: ExaConfig): string {
  return exa?.baseUrl || DEFAULT_EXA_ENDPOINT;
}

function createExaSchema() {
  return Type.Object({
    query: Type.String({ description: "Search query string." }),
    numResults: Type.Optional(
      Type.Number({
        description: "Number of results to return (1-10).",
        minimum: 1,
        maximum: MAX_SEARCH_COUNT,
      }),
    ),
    livecrawl: Type.Optional(
      Type.String({
        description: "Live crawl mode: 'fallback' or 'preferred'.",
      }),
    ),
    type: Type.Optional(
      Type.String({
        description: "Search type: 'auto', 'fast', or 'deep'.",
      }),
    ),
    contextMaxCharacters: Type.Optional(
      Type.Number({
        description: "Maximum characters to return per result.",
      }),
    ),
  });
}

function missingExaKeyPayload() {
  return {
    error: "missing_exa_api_key",
    message: `web_search (exa) needs an Exa API key. Run \`${formatCliCommand("openclaw configure --section web")}\` to store it, or set EXA_API_KEY in the Gateway environment.`,
    docs: "https://docs.openclaw.ai/tools/web",
  };
}

function createExaToolDefinition(searchConfig?: SearchConfigRecord): WebSearchProviderToolDefinition {
  const exaConfig = resolveExaConfig(searchConfig);

  return {
    description:
      "Search the web using Exa API. Provides high-quality web search with intelligent result ranking. Returns titles, URLs, and publication dates.",
    parameters: createExaSchema(),
    execute: async (args) => {
      const apiKey = resolveExaApiKey(searchConfig);
      if (!apiKey) {
        return missingExaKeyPayload();
      }

      const params = args as Record<string, unknown>;
      const query = readStringParam(params, "query", { required: true });
      const numResults = readNumberParam(params, "numResults", { integer: true }) ?? searchConfig?.maxResults ?? undefined;
      const livecrawl = readStringParam(params, "livecrawl") as "fallback" | "preferred" | undefined;
      const type = readStringParam(params, "type") as "auto" | "fast" | "deep" | undefined;
      const contextMaxCharacters = readNumberParam(params, "contextMaxCharacters", { integer: true });

      // Validate parameters
      if (livecrawl && livecrawl !== "fallback" && livecrawl !== "preferred") {
        return {
          error: "invalid_livecrawl",
          message: "livecrawl must be 'fallback' or 'preferred'.",
          docs: "https://docs.openclaw.ai/tools/web",
        };
      }

      if (type && type !== "auto" && type !== "fast" && type !== "deep") {
        return {
          error: "invalid_type",
          message: "type must be 'auto', 'fast', or 'deep'.",
          docs: "https://docs.openclaw.ai/tools/web",
        };
      }

      const cacheKey = buildSearchCacheKey([
        "exa",
        query,
        resolveSearchCount(numResults, DEFAULT_SEARCH_COUNT),
        livecrawl,
        type,
        contextMaxCharacters,
      ]);
      const cached = readCachedSearchPayload(cacheKey);
      if (cached) {
        return cached;
      }

      const start = Date.now();
      const timeoutSeconds = resolveSearchTimeoutSeconds(searchConfig);
      const cacheTtlMs = resolveSearchCacheTtlMs(searchConfig);
      const baseUrl = resolveExaBaseUrl(exaConfig);

      // Build Exa MCP request
      const requestBody: ExaMcpRequest = {
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: {
          name: "web_search_exa",
          arguments: {
            query,
            numResults: resolveSearchCount(numResults, DEFAULT_SEARCH_COUNT),
            ...(livecrawl ? { livecrawl } : {}),
            ...(type ? { type } : {}),
            ...(contextMaxCharacters ? { contextMaxCharacters } : {}),
          },
        },
      };

      try {
        const results = await withTrustedWebSearchEndpoint(
          {
            url: baseUrl,
            timeoutSeconds,
            init: {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${apiKey}`,
              },
              body: JSON.stringify(requestBody),
            },
          },
          async (res) => {
            if (!res.ok) {
              const detail = await res.text();
              throw new Error(`Exa API error (${res.status}): ${detail || res.statusText}`);
            }

            const data = (await res.json()) as ExaMcpResponse;

            if (data.error) {
              throw new Error(`Exa MCP error: ${data.error.message}`);
            }

            const textContent = data.result?.content?.find((c) => c.type === "text")?.text;
            if (!textContent) {
              throw new Error("No text content in Exa response");
            }

            const parsedResults = JSON.parse(textContent) as ExaSearchResult[];

            return parsedResults.map((entry) => ({
              title: entry.title,
              url: entry.url,
              published: entry.publishedDate || undefined,
              score: entry.score,
            }));
          },
        );

        const payload = {
          query,
          provider: "exa",
          count: results.length,
          tookMs: Date.now() - start,
          externalContent: {
            untrusted: true,
            source: "web_search",
            provider: "exa",
            wrapped: true,
          },
          results,
        };

        writeCachedSearchPayload(cacheKey, payload, cacheTtlMs);
        return payload;
      } catch (error) {
        return {
          error: "exa_search_failed",
          message: error instanceof Error ? error.message : "Unknown error",
          query,
          provider: "exa",
        };
      }
    },
  };
}

export function createExaWebSearchProvider(): WebSearchProviderPlugin {
  return {
    id: "exa",
    label: "Exa",
    hint: "AI-powered web search · intelligent ranking",
    envVars: ["EXA_API_KEY"],
    placeholder: "exa_...",
    signupUrl: "https://exa.ai",
    docsUrl: "https://docs.openclaw.ai/tools/web",
    autoDetectOrder: 20,
    credentialPath: "plugins.entries.exa.config.webSearch.apiKey",
    inactiveSecretPaths: ["plugins.entries.exa.config.webSearch.apiKey"],
    getCredentialValue: (searchConfig) => searchConfig?.apiKey,
    setCredentialValue: setTopLevelCredentialValue,
    getConfiguredCredentialValue: (config) => resolveProviderWebSearchPluginConfig(config, "exa")?.apiKey,
    setConfiguredCredentialValue: (configTarget, value) => {
      setProviderWebSearchPluginConfigValue(configTarget, "exa", "apiKey", value);
    },
    createTool: (ctx) =>
      createExaToolDefinition(
        (() => {
          const searchConfig = ctx.searchConfig as SearchConfigRecord | undefined;
          const pluginConfig = resolveProviderWebSearchPluginConfig(ctx.config, "exa");
          if (!pluginConfig) {
            return searchConfig;
          }
          return {
            ...(searchConfig ?? {}),
            ...(pluginConfig.apiKey === undefined ? {} : { apiKey: pluginConfig.apiKey }),
            exa: {
              ...resolveExaConfig(searchConfig),
              ...pluginConfig,
            },
          } as SearchConfigRecord;
        })(),
      ),
  };
}

export const __testing = {
  resolveExaConfig,
  resolveExaApiKey,
  resolveExaBaseUrl,
} as const;
