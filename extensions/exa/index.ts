import { definePluginEntry } from "openclaw/plugin-sdk/core";
import { createExaWebSearchProvider } from "./src/exa-web-search-provider.js";

export default definePluginEntry({
  id: "exa",
  name: "Exa Plugin",
  description: "Exa web search provider plugin",
  register(api) {
    api.registerWebSearchProvider(createExaWebSearchProvider());
  },
});
