#!/usr/bin/env bun
import { $ } from "bun";

console.log("🚀 Starting optimized build (Bun)...");

// Phase 1: Parallel compilation
console.log("📦 Phase 1: Compilation (parallel)...");
await Promise.all([$`pnpm canvas:a2ui:bundle`, $`tsdown`]);

// Phase 2: Parallel post-build
console.log("📝 Phase 2: Post-build (parallel)...");
await Promise.all([
  $`node scripts/copy-plugin-sdk-root-alias.mjs`,
  $`pnpm build:plugin-sdk:dts`,
  $`node --import tsx scripts/write-plugin-sdk-entry-dts.ts`,
  $`node --import tsx scripts/canvas-a2ui-copy.ts`,
  $`node --import tsx scripts/copy-hook-metadata.ts`,
  $`node --import tsx scripts/copy-export-html-templates.ts`,
  $`node --import tsx scripts/write-build-info.ts`,
  $`node --import tsx scripts/write-cli-startup-metadata.ts`,
  $`node --import tsx scripts/write-cli-compat.ts`,
]);

console.log("✅ Build complete!");
