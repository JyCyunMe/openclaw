#!/bin/bash
# OpenClaw 二进制编译脚本
# 使用 Bun 的 --compile 功能生成单一可执行文件

set -e

echo "🎯 OpenClaw 二进制编译"
echo "========================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 检查 Bun
if ! command -v bun &> /dev/null; then
    echo -e "${RED}❌ Bun 未安装${NC}"
    exit 1
fi

echo -e "${BLUE}Bun 版本: $(bun --version)${NC}\n"

# 检测平台
OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
    Linux)
        TARGET="bun-linux-${ARCH}"
        BINARY_NAME="openclaw-linux-${ARCH}"
        ;;
    Darwin)
        TARGET="bun-darwin-${ARCH}"
        BINARY_NAME="openclaw-macos-${ARCH}"
        ;;
    *)
        TARGET="bun"
        BINARY_NAME="openclaw"
        ;;
esac

echo -e "${YELLOW}编译目标: $TARGET${NC}"
echo -e "${YELLOW}输出文件: $BINARY_NAME${NC}\n"

# 方法1：直接编译 openclaw.mjs
echo -e "${BLUE}方法 1: 编译入口文件...${NC}"
bun build --compile \
    ./openclaw.mjs \
    --outfile ./bin/"$BINARY_NAME" \
    --target="$TARGET" \
    --sourcemap=linked

if [ -f ./bin/"$BINARY_NAME" ]; then
    chmod +x ./bin/"$BINARY_NAME"
    echo -e "${GREEN}✅ 方法 1 成功: ./bin/$BINARY_NAME${NC}\n"
else
    echo -e "${RED}❌ 方法 1 失败${NC}\n"
fi

# 方法2：编译 dist/entry.js
echo -e "${BLUE}方法 2: 编译构建产物...${NC}"
bun build --compile \
    ./dist/entry.js \
    --outfile ./bin/"$BINARY_NAME-entry" \
    --target="$TARGET" \
    --sourcemap=linked

if [ -f ./bin/"$BINARY_NAME-entry" ]; then
    chmod +x ./bin/"$BINARY_NAME-entry"
    echo -e "${GREEN}✅ 方法 2 成功: ./bin/$BINARY_NAME-entry${NC}\n"
else
    echo -e "${RED}❌ 方法 2 失败${NC}\n"
fi

# 测试二进制文件
echo -e "${BLUE}测试二进制文件...${NC}"
for binary in ./bin/"$BINARY_NAME" ./bin/"$BINARY_NAME-entry"; do
    if [ -f "$binary" ]; then
        echo -e "\n${YELLOW}测试: $binary${NC}"
        if "$binary" --version 2>&1 | grep -q "openclaw"; then
            echo -e "${GREEN}✅ 版本检查成功${NC}"
            ls -lh "$binary"
        else
            echo -e "${YELLOW}⚠️  版本检查失败，但文件已生成${NC}"
        fi
    fi
done

echo -e "\n${GREEN}🎉 编译完成！${NC}"
echo "========================"
echo -e "${BLUE}生成的文件:${NC}"
ls -lh ./bin/ 2>/dev/null | grep -v total || echo "  没有生成二进制文件"

echo -e "\n${BLUE}使用方法:${NC}"
echo "  ./bin/$BINARY_NAME gateway ..."
echo "  ./bin/$BINARY_NAME --version"
