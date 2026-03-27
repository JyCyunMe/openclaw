#!/bin/bash
# 创建真正可用的 OpenClaw 二进制文件

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 创建 OpenClaw 真正可用的二进制文件${NC}"
echo "=================================="

# 1. 先构建项目
echo -e "${YELLOW}步骤 1: 构建项目...${NC}"
pnpm build

# 2. 创建独立的入口文件
echo -e "${YELLOW}步骤 2: 创建独立入口...${NC}"
cat > openclaw-standalone.mjs << 'ENTRYEOF'
#!/usr/bin/env node
// OpenClaw 独立二进制入口

const MIN_NODE_MAJOR = 22;
const MIN_NODE_MINOR = 12;

const parseNodeVersion = (rawVersion) => {
  const [majorRaw = "0", minorRaw = "0"] = rawVersion.split(".");
  return {
    major: Number(majorRaw),
    minor: Number(minorRaw),
  };
};

const isSupportedNodeVersion = (version) =>
  version.major > MIN_NODE_MAJOR ||
  (version.major === MIN_NODE_MAJOR && version.minor >= MIN_NODE_MINOR);

const ensureSupportedNodeVersion = () => {
  if (isSupportedNodeVersion(parseNodeVersion(process.versions.node))) {
    return;
  }
  process.stderr.write(
    `openclaw: Node.js v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+ is required\n`
  );
  process.exit(1);
};

ensureSupportedNodeVersion();

// 动态导入入口
import("./dist/entry.js").catch((err) => {
  console.error("Failed to load entry:", err);
  process.exit(1);
});
ENTRYEOF

# 3. 使用 Bun 打包所有依赖到一个文件
echo -e "${YELLOW}步骤 3: 打包所有依赖...${NC}"
bun build ./dist/entry.js \
  --outfile ./dist/openclaw-bundle.js \
  --target bun \
  --format esm \
  --sourcemap=inline

# 4. 创建自包含的入口
echo -e "${YELLOW}步骤 4: 创建自包含入口...${NC}"
cat > openclaw-selfcontained.mjs << 'SELFEOF'
#!/usr/bin/env node
// OpenClaw 自包含入口

// 导入打包后的代码
import "./dist/openclaw-bundle.js";
SELFEOF

# 5. 编译为二进制
echo -e "${YELLOW}步骤 5: 编译为二进制...${NC}"
bun build --compile \
  ./openclaw-selfcontained.mjs \
  --outfile ./bin/openclaw \
  --target=bun-linux-x86_64 \
  --sourcemap=linked

if [ -f ./bin/openclaw ]; then
  chmod +x ./bin/openclaw
  echo -e "${GREEN}✅ 二进制文件创建成功: ./bin/openclaw${NC}"
  
  # 6. 测试
  echo -e "${YELLOW}步骤 6: 测试二进制文件...${NC}"
  if ./bin/openclaw --version 2>&1 | head -1; then
    echo -e "${GREEN}✅ 二进制文件测试成功！${NC}"
  else
    echo -e "${YELLOW}⚠️  二进制文件生成但可能需要调试${NC}"
  fi
  
  ls -lh ./bin/openclaw
else
  echo -e "❌ 二进制编译失败"
  exit 1
fi
