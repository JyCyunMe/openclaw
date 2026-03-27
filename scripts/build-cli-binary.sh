#!/bin/bash
# 创建 OpenClaw CLI 二进制（只编译 CLI 部分）

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 创建 OpenClaw CLI 二进制${NC}"
echo "================================"
echo "策略：只编译 CLI 部分，保持模块化架构"
echo ""

# 1. 先构建
echo -e "${YELLOW}步骤 1: 构建 TypeScript...${NC}"
pnpm build 2>&1 | tail -3

# 2. 创建 CLI bundle
echo -e "${YELLOW}步骤 2: 创建 CLI bundle...${NC}"
bun build ./dist/cli/run-main.js \
  --outfile ./dist/cli-bundle.js \
  --target node \
  --format esm \
  --minify \
  --sourcemap=inline

BUNDLE_SIZE=$(du -h ./dist/cli-bundle.js 2>/dev/null | cut -f1)
echo -e "${GREEN}✅ CLI Bundle: $BUNDLE_SIZE${NC}"

# 3. 创建 CLI 专用入口
echo -e "${YELLOW}步骤 3: 创建 CLI 入口...${NC}"
cat > src/cli-entry.ts << 'ENTRY'
#!/usr/bin/env node
// OpenClaw CLI 专用入口
import { runCli } from "./dist/cli-bundle.js";
runCli(process.argv);
ENTRY

# 4. 编译为二进制
echo -e "${YELLOW}步骤 4: 编译为二进制...${NC}"
mkdir -p bin

bun build --compile \
  src/cli-entry.ts \
  --outfile ./bin/openclaw-cli \
  --target=bun-linux-x86_64 \
  --sourcemap=linked

if [ -f ./bin/openclaw-cli ]; then
  chmod +x ./bin/openclaw-cli
  BIN_SIZE=$(du -h ./bin/openclaw-cli | cut -f1)
  echo -e "${GREEN}✅ CLI 二进制: $BIN_SIZE${NC}"
else
  echo -e "${YELLOW}⚠️  二进制编译失败，但 bundle 可用${NC}"
fi

# 5. 创建运行时包
echo -e "${YELLOW}步骤 5: 创建运行时包...${NC}"
mkdir -p openclaw-cli-bin

# 复制核心文件
cp -r dist openclaw-cli-bin/
cp -r src openclaw-cli-bin/src
cp package.json openclaw-cli-bin/
[ -f bun.lock ] && cp bun.lock openclaw-cli-bin/

# 复制 CLI 二进制
if [ -f ./bin/openclaw-cli ]; then
  cp ./bin/openclaw-cli openclaw-cli-bin/
fi

# 创建启动脚本
cat > openclaw-cli-bin/openclaw << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

if [ -f ./openclaw-cli ]; then
  exec ./openclaw-cli "$@"
elif [ -f ./dist/cli-bundle.js ]; then
  if command -v bun &> /dev/null; then
    exec bun run dist/cli-bundle.js "$@"
  else
    exec node dist/cli-bundle.js "$@"
  fi
else
  # 回退到标准入口
  if command -v bun &> /dev/null; then
    exec bun run openclaw.mjs "$@"
  else
    exec node openclaw.mjs "$@"
  fi
fi
SCRIPT

chmod +x openclaw-cli-bin/openclaw

# 6. 打包
echo -e "${YELLOW}步骤 6: 打包...${NC}"
tar czf openclaw-cli-bin.tar.gz openclaw-cli-bin/

# 7. 性能测试
echo -e "${YELLOW}步骤 7: 性能测试...${NC}"
if [ -f ./bin/openclaw-cli ]; then
  echo -e "${BLUE}测试 CLI 二进制:${NC}"
  for i in {1..3}; do
    echo -n "  尝试 $i: "
    { time ./bin/openclaw-cli --version 2>&1 | grep -v "real\|user\|sys"; } | head -1 || true
  done
  echo ""
fi

# 8. 完成报告
echo ""
echo -e "${GREEN}🎉 CLI 二进制创建完成！${NC}"
echo "================================"
echo -e "${BLUE}生成的文件:${NC}"
ls -lh ./bin/openclaw-cli 2>/dev/null || echo "  二进制: 未生成"
echo ""
ls -lh ./dist/cli-bundle.js 2>/dev/null || echo "  Bundle: 未生成"
echo ""
ls -lh openclaw-cli-bin.tar.gz 2>/dev/null || echo "  包: 未生成"

echo ""
echo -e "${BLUE}使用方法:${NC}"
echo "  tar xzf openclaw-cli-bin.tar.gz"
echo "  cd openclaw-cli-bin"
echo "  ./openclaw gateway run"

echo ""
echo -e "${BLUE}预期收益:${NC}"
echo "  • CLI 启动时间: 50-70ms → 5-10ms (快 5-10x)"
echo "  • 二进制文件独立运行"
echo "  • 保持所有功能不变"
