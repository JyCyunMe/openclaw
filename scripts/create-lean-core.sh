#!/bin/bash
# 创建超精简核心二进制 - 完全排除有问题的依赖

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 创建超精简核心二进制${NC}"
echo "=================================="
echo "策略：完全排除有问题的依赖，运行时加载"
echo ""

# 1. 创建最小化入口
echo -e "${YELLOW}步骤 1: 创建最小化入口...${NC}"
cat > src/lean-entry.mjs << 'ENTRY'
#!/usr/bin/env node
// OpenClaw 超精简入口 - 只包含绝对必要的部分

import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// 动态加载真实入口
async function main() {
  try {
    // 动态加载已编译的入口
    const { runCli } = await import("./dist/cli/run-main.js");
    await runCli(process.argv);
  } catch (error) {
    console.error("[openclaw] Failed to start:", error.message);
    process.exit(1);
  }
}

main();
ENTRY

echo -e "${GREEN}✅ 入口创建完成${NC}"

# 2. 使用 Bun 直接编译（跳过 bundle）
echo -e "${YELLOW}步骤 2: 直接编译入口...${NC}"
bun build --compile \
  src/lean-entry.mjs \
  --outfile ./bin/openclaw-lean \
  --target=bun-linux-x86_64 \
  --sourcemap=linked

if [ -f ./bin/openclaw-lean ]; then
  chmod +x ./bin/openclaw-lean
  SIZE=$(du -h ./bin/openclaw-lean | cut -f1)
  echo -e "${GREEN}✅ 精简二进制创建成功: $SIZE${NC}"
else
  echo -e "${YELLOW}⚠️  直接编译失败，尝试 bundle 方式${NC}"
  
  # 备选方案：先 bundle 再编译
  bun build src/lean-entry.mjs \
    --outfile ./dist/lean-bundle.js \
    --target node \
    --format esm
    
  bun build --compile \
    ./dist/lean-bundle.js \
    --outfile ./bin/openclaw-lean \
    --target=bun-linux-x86_64
    
  if [ -f ./bin/openclaw-lean ]; then
    chmod +x ./bin/openclaw-lean
    SIZE=$(du -h ./bin/openclaw-lean | cut -f1)
    echo -e "${GREEN}✅ 二进制创建成功: $SIZE${NC}"
  fi
fi

# 3. 创建运行时包
echo -e "${YELLOW}步骤 3: 创建运行时包...${NC}"
mkdir -p openclaw-lean

# 复制编译输出
cp -r dist openclaw-lean/
cp -r node_modules openclaw-lean/
cp openclaw.mjs openclaw-lean/
cp package.json openclaw-lean/

# 复制二进制
if [ -f ./bin/openclaw-lean ]; then
  cp ./bin/openclaw-lean openclaw-lean/
fi

# 创建启动脚本
cat > openclaw-lean/openclaw << 'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

if [ -f ./openclaw-lean ]; then
  exec ./openclaw-lean "$@"
else
  if command -v bun &> /dev/null; then
    exec bun run openclaw.mjs "$@"
  else
    exec node openclaw.mjs "$@"
  fi
fi
SCRIPT

chmod +x openclaw-lean/openclaw

# 4. 打包
echo -e "${YELLOW}步骤 4: 打包...${NC}"
tar czf openclaw-lean.tar.gz openclaw-lean/

# 5. 报告
echo ""
echo -e "${GREEN}🎉 精简版本创建完成！${NC}"
echo "=================================="
ls -lh ./bin/openclaw-lean 2>/dev/null && echo ""
ls -lh openclaw-lean.tar.gz 2>/dev/null && echo ""

echo -e "${BLUE}📊 对比:${NC}"
echo "  完整版:  978MB"
echo "  精简版:  $(du -sh openclaw-lean.tar.gz 2>/dev/null | cut -f1 || echo 'N/A')"
echo ""
echo -e "${BLUE}使用方法:${NC}"
echo "  tar xzf openclaw-lean.tar.gz"
echo "  cd openclaw-lean"
echo "  ./openclaw gateway run"
