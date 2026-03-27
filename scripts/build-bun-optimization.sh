#!/bin/bash
# OpenClaw Bun 混合优化构建脚本 v3 (修正版)
# 修正：bytecode 只能与 target bun 一起使用

set -e

echo "🚀 OpenClaw Bun 混合优化构建 v3"
echo "===================================="

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查环境
check_env() {
    echo -e "${BLUE}📋 检查环境...${NC}"

    # 检查 Bun
    if ! command -v bun &> /dev/null; then
        echo -e "${RED}❌ Bun 未安装${NC}"
        echo "安装 Bun: curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi
    echo -e "${GREEN}✅ Bun 版本: $(bun --version)${NC}"

    # 检查 Node.js（用于构建）
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}⚠️  Node.js 未安装${NC}"
    else
        echo -e "${GREEN}✅ Node.js 版本: $(node --version)${NC}"
    fi

    # 检查 pnpm（通过 Bun）
    if ! bun run pnpm --version &> /dev/null; then
        echo -e "${YELLOW}⚠️  pnpm 不可用，尝试安装...${NC}"
        bun install -g pnpm
    fi
    BUN_PNPM_VERSION=$(bun run pnpm --version 2>&1 || echo "unknown")
    echo -e "${GREEN}✅ pnpm (via Bun): $BUN_PNPM_VERSION${NC}"
}

# TypeScript 编译（tsdown 通过 Bun）
build_tsdown() {
    echo -e "${YELLOW}📦 第一步：使用 tsdown 编译 TypeScript...${NC}"
    echo -e "${BLUE}通过 Bun 运行 pnpm 以获得更好的性能${NC}"

    # 关键：使用 bun run pnpm 来运行所有 pnpm 命令
    bun run pnpm run build
    echo -e "${GREEN}✅ tsdown 编译完成${NC}"
}

# Bun 原生优化（使用 target bun）
build_bun_native() {
    echo -e "${YELLOW}⚡ 第二步：Bun 原生优化（target=bun + bytecode）...${NC}"

    mkdir -p dist-bun

    # 使用 Bun 的原生优化
    # 注意：bytecode 只能与 target bun 一起使用
    bun build ./dist/entry.js \
        --outdir ./dist-bun \
        --target bun \
        --bytecode \
        --sourcemap

    echo -e "${GREEN}✅ Bun 原生优化完成${NC}"
    echo -e "${BLUE}📈 启动速度预期提升: 2x (bytecode 优化)${NC}"
}

# Node.js 运行时兼容构建
build_node_compat() {
    echo -e "${YELLOW}🎯 第三步：Node.js 运行时兼容构建...${NC}"

    mkdir -p dist-node

    # 针对 Node.js 运行时优化（不使用 bytecode）
    bun build ./dist/entry.js \
        --outdir ./dist-node \
        --target node \
        --sourcemap \
        --minify

    echo -e "${GREEN}✅ Node.js 兼容构建完成${NC}"
    echo -e "${BLUE}📈 兼容性: 可在 Node.js 环境运行${NC}"
}

# 生产级优化（Bun 原生）
build_bun_production() {
    echo -e "${YELLOW}🔥 第四步：Bun 生产级优化...${NC}"

    mkdir -p dist-bun-prod

    # 生产级优化：bytecode + 压缩 + 环境变量
    bun build ./dist/entry.js \
        --outdir ./dist-bun-prod \
        --target bun \
        --bytecode \
        --minify \
        --sourcemap=linked \
        --define="NODE_ENV='production'" \
        --define="OPENCLAW_BUN_BUILD='true'"

    echo -e "${GREEN}✅ 生产级优化完成${NC}"
    echo -e "${BLUE}📈 体积更小，启动更快${NC}"
}

# 二进制编译（可选）
build_binary() {
    if [ "$BUILD_BINARY" = "true" ]; then
        echo -e "${YELLOW}🔨 第五步：编译二进制文件...${NC}"

        mkdir -p bin

        # 检测当前平台
        OS=$(uname -s)
        ARCH=$(uname -m)

        # 设置编译目标
        case "$OS" in
            Linux)
                TARGET="bun-linux-${ARCH}"
                ;;
            Darwin)
                TARGET="bun-darwin-${ARCH}"
                ;;
            *)
                TARGET="bun"
                ;;
        esac

        echo -e "${BLUE}编译目标: $TARGET${NC}"

        # 使用 Bun 的编译功能
        bun build --compile \
            ./openclaw.mjs \
            --outfile ./bin/openclaw \
            --target="$TARGET" \
            --bytecode \
            --sourcemap=linked

        # 如果编译成功，测试可执行文件
        if [ -f ./bin/openclaw ]; then
            chmod +x ./bin/openclaw
            echo -e "${GREEN}✅ 二进制文件生成: ./bin/openclaw${NC}"

            # 测试运行
            echo -e "${BLUE}测试二进制文件...${NC}"
            if ./bin/openclaw --version 2>&1 | grep -q "openclaw"; then
                echo -e "${GREEN}✅ 二进制文件测试成功${NC}"
            else
                echo -e "${YELLOW}⚠️  版本检查失败，但文件已生成${NC}"
            fi
        else
            echo -e "${RED}❌ 二进制编译失败${NC}"
        fi
    fi
}

# 运行测试（通过 Bun）
run_tests() {
    if [ "$SKIP_TESTS" != "true" ]; then
        echo -e "${YELLOW}🧪 运行测试...${NC}"

        # 使用 Bun 运行快速测试
        if bun run pnpm run test:fast; then
            echo -e "${GREEN}✅ 测试通过${NC}"
        else
            echo -e "${YELLOW}⚠️  测试失败，但继续构建${NC}"
        fi
    fi
}

# 性能基准测试
run_benchmark() {
    if [ "$RUN_BENCHMARK" != "false" ]; then
        echo -e "\n${BLUE}📊 性能基准测试${NC}"
        echo "========================"

        # 测试 Node.js 启动时间
        echo -e "\nNode.js:"
        for i in {1..3}; do
            /usr/bin/time -f "  Run $i: %E" node openclaw.mjs --version 2>&1 | grep -E "(Run|version)" || true
        done

        # 测试 Bun 直接运行
        echo -e "\nBun (direct):"
        for i in {1..3}; do
            /usr/bin/time -f "  Run $i: %E" bun run openclaw.mjs --version 2>&1 | grep -E "(Run|version)" || true
        done

        # 测试 Bun 原生优化版本（如果存在）
        if [ -f ./dist-bun/entry.js ]; then
            echo -e "\nBun (native+bytecode):"
            for i in {1..3}; do
                /usr/bin/time -f "  Run $i: %E" bun run dist-bun/entry.js --version 2>&1 | grep -E "(Run|version)" || true
            done
        fi

        # 测试 Node.js 兼容版本（如果存在）
        if [ -f ./dist-node/entry.js ]; then
            echo -e "\nNode.js (兼容构建):"
            for i in {1..3}; do
                /usr/bin/time -f "  Run $i: %E" node dist-node/entry.js --version 2>&1 | grep -E "(Run|version)" || true
            done
        fi

        # 测试二进制版本（如果存在）
        if [ -f ./bin/openclaw ]; then
            echo -e "\n二进制文件:"
            for i in {1..3}; do
                /usr/bin/time -f "  Run $i: %E" ./bin/openclaw --version 2>&1 | grep -E "(Run|version)" || true
            done
        fi

        echo
    fi
}

# 构建摘要
build_summary() {
    echo -e "\n${GREEN}🎉 构建完成！${NC}"
    echo "========================"
    echo -e "${BLUE}📁 构建产物:${NC}"
    echo "  • 原始编译: ./dist/entry.js"
    echo "  • Bun 原生优化: ./dist-bun/entry.js (推荐 Bun 运行时)"
    echo "  • Node.js 兼容: ./dist-node/entry.js (兼容 Node.js)"
    [ -d ./dist-bun-prod ] && echo "  • 生产级优化: ./dist-bun-prod/entry.js"
    [ -f ./bin/openclaw ] && echo "  • 二进制文件: ./bin/openclaw"

    echo -e "\n${BLUE}🚀 使用方法:${NC}"
    echo "  • Node.js:      node openclaw.mjs ..."
    echo "  • Bun (推荐):   bun run openclaw.mjs ..."
    echo "  • Bun 原生:     bun run dist-bun/entry.js ..."
    echo "  • Node.js 兼容: node dist-node/entry.js ..."
    [ -f ./bin/openclaw ] && echo "  • 二进制:       ./bin/openclaw ..."

    echo -e "\n${BLUE}💡 性能提示:${NC}"
    echo "  • Bun 原生版本（bytecode）启动速度提升 ~2x"
    echo "  • 所有 pnpm 命令建议通过 'bun run pnpm' 运行"
    echo "  • 开发环境使用 'bun --hot' 获得最快热重载"
    echo "  • 生产环境使用 dist-bun-prod 体积最小"
}

# 主流程
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --binary)
                BUILD_BINARY=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --no-benchmark)
                RUN_BENCHMARK=false
                shift
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --binary       编译二进制文件"
                echo "  --skip-tests   跳过测试"
                echo "  --no-benchmark 跳过性能测试"
                echo "  --help         显示帮助"
                echo ""
                echo "示例:"
                echo "  $0                    # 标准构建"
                echo "  $0 --binary          # 构建二进制"
                echo "  $0 --skip-tests      # 跳过测试"
                echo ""
                echo "构建产物:"
                echo "  • dist-bun/          Bun 原生优化（推荐 Bun 运行时）"
                echo "  • dist-node/         Node.js 兼容构建"
                echo "  • dist-bun-prod/     生产级优化（体积最小）"
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
        esac
    done

    check_env
    build_tsdown
    build_bun_native
    build_node_compat
    build_bun_production
    build_binary
    run_tests
    run_benchmark
    build_summary
}

# 运行主流程
main "$@"
