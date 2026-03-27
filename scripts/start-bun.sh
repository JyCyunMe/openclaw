#!/bin/bash
# 快速启动脚本 - 使用 Bun 运行 OpenClaw

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 OpenClaw Bun 快速启动${NC}"
echo "========================"

# 检查 Bun
if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}⚠️  Bun 未安装，使用 Node.js...${NC}"
    node openclaw.mjs "$@"
    exit $?
fi

# 优先使用 Bun 运行
echo -e "${GREEN}✅ 使用 Bun 运行 (性能优化)${NC}"
echo -e "${BLUE}提示: 所有 pnpm 命令建议通过 'bun run pnpm' 运行${NC}\n"

# 直接使用 Bun 运行
bun run openclaw.mjs "$@"
