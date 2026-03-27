#!/bin/bash
set -e

echo "🚀 Starting optimized build..."

# Phase 1: Parallel compilation
echo "📦 Phase 1: Compilation (parallel)..."
pnpm canvas:a2ui:bundle &
TSDOWN_PID=$!

tsdown &
CANVAS_PID=$!

wait $TSDOWN_PID $CANVAS_PID

# Phase 2: Parallel post-build
echo "📝 Phase 2: Post-build (parallel)..."

node scripts/copy-plugin-sdk-root-alias.mjs &
PID1=$!

pnpm build:plugin-sdk:dts &
PID2=$!

node --import tsx scripts/write-plugin-sdk-entry-dts.ts &
PID3=$!

node --import tsx scripts/canvas-a2ui-copy.ts &
PID4=$!

node --import tsx scripts/copy-hook-metadata.ts &
PID5=$!

node --import tsx scripts/copy-export-html-templates.ts &
PID6=$!

node --import tsx scripts/write-build-info.ts &
PID7=$!

node --import tsx scripts/write-cli-startup-metadata.ts &
PID8=$!

node --import tsx scripts/write-cli-compat.ts &
PID9=$!

wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6 $PID7 $PID8 $PID9

echo "✅ Build complete!"
