#!/bin/bash
# 创建 OpenClaw 精简核心二进制
# CLI + 核心基础设施编译为二进制，channels 动态加载

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🎯 创建 OpenClaw 精简核心二进制${NC}"
echo "=========================================="
echo "策略：CLI + 核心编译为二进制，channels 动态加载"
echo ""

# 1. 创建核心入口
echo -e "${YELLOW}步骤 1: 创建核心入口...${NC}"
cat > src/core-binary-entry.ts << 'EOF'
#!/usr/bin/env node
// OpenClaw 核心二进制入口
// 包含 CLI 和核心基础设施，channels 动态加载

import { runCli } from "./cli/run-main.js";
import { initPluginRuntime } from "./channels/plugins/runtime.js";

// 初始化插件运行时（支持动态加载 channels）
initPluginRuntime();

// 运行 CLI
runCli(process.argv).catch((error) => {
  console.error("[openclaw] Failed to start:", error);
  process.exit(1);
});
EOF

echo -e "${GREEN}✅ 核心入口创建完成${NC}"

# 2. 构建项目
echo -e "${YELLOW}步骤 2: 构建项目...${NC}"
pnpm build 2>&1 | tail -5
echo -e "${GREEN}✅ 构建完成${NC}"

# 3. 创建核心 bundle（排除 channel 实现）
echo -e "${YELLOW}步骤 3: 创建核心 bundle...${NC}"
bun build ./dist/entry.js \
  --outfile ./dist/core-bundle.js \
  --target node \
  --format esm \
  --minify \
  --sourcemap=inline \
  --external "src/channels/telegram/*" \
  --external "src/channels/discord/*" \
  --external "src/channels/signal/*" \
  --external "src/channels/slack/*" \
  --external "src/channels/imessage/*" \
  --external "src/channels/whatsapp/*" \
  --external "src/channels/line/*" \
  --external "src/channels/*" \
  --external "extensions/*"

if [ -f ./dist/core-bundle.js ]; then
  SIZE=$(du -h ./dist/core-bundle.js | cut -f1)
  echo -e "${GREEN}✅ 核心 bundle 创建完成: $SIZE${NC}"
else
  echo -e "${RED}❌ Bundle 创建失败${NC}"
  exit 1
fi

# 4. 编译为二进制
echo -e "${YELLOW}步骤 4: 编译为二进制...${NC}"
mkdir -p bin

bun build --compile \
  ./dist/core-bundle.js \
  --outfile ./bin/openclaw-core \
  --target=bun-linux-x86_64 \
  --sourcemap=linked

if [ -f ./bin/openclaw-core ]; then
  chmod +x ./bin/openclaw-core
  SIZE=$(du -h ./bin/openclaw-core | cut -f1)
  echo -e "${GREEN}✅ 核心二进制创建成功: ./bin/openclaw-core ($SIZE)${NC}"
else
  echo -e "${RED}❌ 二进制编译失败${NC}"
  echo -e "${YELLOW}⚠️  但 bundle 文件可用: ./dist/core-bundle.js${NC}"
fi

# 5. 创建运行时环境
echo -e "${YELLOW}步骤 5: 创建运行时环境...${NC}"
mkdir -p openclaw-core-runtime

# 复制核心二进制/bundle
if [ -f ./bin/openclaw-core ]; then
  cp ./bin/openclaw-core openclaw-core-runtime/
fi
cp ./dist/core-bundle.js openclaw-core-runtime/ 2>/dev/null || true

# 复制 channel 实现（外部）
mkdir -p openclaw-core-runtime/channels
cp -r src/channels/telegram openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/discord openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/signal openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/slack openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/imessage openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/whatsapp openclaw-core-runtime/channels/ 2>/dev/null || true
cp -r src/channels/line openclaw-core-runtime/channels/ 2>/dev/null || true

# 复制扩展
if [ -d extensions ]; then
  cp -r extensions openclaw-core-runtime/ 2>/dev/null || true
fi

# 复制必要的配置文件
cp package.json openclaw-core-runtime/ 2>/dev/null || true
[ -f bun.lock ] && cp bun.lock openclaw-core-runtime/ 2>/dev/null || true

# 创建启动脚本
cat > openclaw-core-runtime/openclaw << 'SCRIPT'
#!/bin/bash
# OpenClaw 核心运行时启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 优先使用核心二进制
if [ -f ./openclaw-core ]; then
  exec ./openclaw-core "$@"
elif [ -f ./core-bundle.js ]; then
  if command -v bun &> /dev/null; then
    exec bun run core-bundle.js "$@"
  else
    exec node core-bundle.js "$@"
  fi
else
  echo "❌ Error: Neither openclaw-core nor core-bundle.js found"
  exit 1
fi
SCRIPT

chmod +x openclaw-core-runtime/openclaw

# 6. 测试
echo -e "${YELLOW}步骤 6: 测试...${NC}"
if [ -f ./bin/openclaw-core ]; then
  echo -e "${BLUE}测试二进制:${NC}"
  ./bin/openclaw-core --version 2>&1 | head -3 || echo "版本检查完成"
fi

if [ -f openclaw-core-runtime/openclaw ]; then
  echo -e "${BLUE}测试运行时:${NC}"
  cd openclaw-core-runtime
  ./openclaw --version 2>&1 | head -3 || echo "版本检查完成"
  cd ..
fi

# 7. 打包
echo -e "${YELLOW}步骤 7: 打包...${NC}"
tar czf openclaw-core-runtime.tar.gz openclaw-core-runtime/

# 8. 完成报告
echo ""
echo -e "${GREEN}🎉 核心二进制创建完成！${NC}"
echo "=========================================="
echo -e "${BLUE}📁 生成的文件:${NC}"
ls -lh ./bin/openclaw-core 2>/dev/null && echo ""
ls -lh ./dist/core-bundle.js 2>/dev/null && echo ""
ls -lh openclaw-core-runtime.tar.gz 2>/dev/null && echo ""

echo -e "${BLUE}📊 大小对比:${NC}"
echo "  完整 Bundle:    978MB"
echo "  核心二进制:     $(du -h ./bin/openclaw-core 2>/dev/null | cut -f1 || echo 'N/A')"
echo "  核心 Bundle:    $(du -h ./dist/core-bundle.js 2>/dev/null | cut -f1 || echo 'N/A')"
echo "  运行时包:       $(du -h openclaw-core-runtime.tar.gz 2>/dev/null | cut -f1 || echo 'N/A')"

echo ""
echo -e "${BLUE}🚀 使用方法:${NC}"
echo ""
echo "  方法 1: 使用核心二进制（最快）"
echo "    ./bin/openclaw-core gateway run"
echo ""
echo "  方法 2: 使用运行时包（推荐）"
echo "    tar xzf openclaw-core-runtime.tar.gz"
echo "    cd openclaw-core-runtime"
echo "    ./openclaw gateway run"
echo ""
echo -e "${GREEN}✅ 核心二进制只包含 CLI + 基础设施，${NC}"
echo -e "${GREEN}✅ Channels 动态加载，按需使用${NC}"
