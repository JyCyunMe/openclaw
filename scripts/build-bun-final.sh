#!/bin/bash
# OpenClaw Bun 混合优化构建脚本 v4 (实用版)
# 策略：使用 Bun 作为运行时和开发工具，不用于完整打包

set -e

echo "🚀 OpenClaw Bun 混合优化构建 v4"
echo "===================================="
echo "策略：使用 Bun 运行时，保持 tsdown 构建系统"
echo ""

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
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

    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}⚠️  Node.js 未安装${NC}"
    else
        echo -e "${GREEN}✅ Node.js 版本: $(node --version)${NC}"
    fi

    # 检查 pnpm
    if ! command -v pnpm &> /dev/null; then
        echo -e "${YELLOW}⚠️  pnpm 未安装${NC}"
    else
        echo -e "${GREEN}✅ pnpm 版本: $(pnpm --version)${NC}"
    fi
}

# 标准构建（使用 pnpm + tsdown）
build_standard() {
    echo -e "${YELLOW}📦 第一步：标准构建（tsdown）...${NC}"
    echo -e "${CYAN}使用 pnpm 运行构建（保持兼容性）${NC}"

    pnpm run build
    echo -e "${GREEN}✅ 标准构建完成${NC}"
}

# 创建 Bun 运行时优化的启动脚本
create_bun_runtime_launcher() {
    echo -e "${YELLOW}⚡ 第二步：创建 Bun 运行时启动器...${NC}"

    cat > openclaw-bun << 'EOF'
#!/usr/bin/env bash
# OpenClaw Bun 运行时启动器
# 使用 Bun 运行编译后的代码，获得更好的性能

# 检查 Bun
if ! command -v bun &> /dev/null; then
    echo "❌ Bun 未安装，回退到 Node.js..."
    node openclaw.mjs "$@"
    exit $?
fi

# 使用 Bun 运行
bun run openclaw.mjs "$@"
EOF

    chmod +x openclaw-bun
    echo -e "${GREEN}✅ Bun 启动器创建完成: ./openclaw-bun${NC}"
}

# 性能测试
run_performance_test() {
    if [ "$RUN_BENCHMARK" != "false" ]; then
        echo -e "\n${CYAN}📊 性能对比测试${NC}"
        echo "=========================="

        echo -e "\n${BLUE}1. Node.js 运行时${NC}"
        for i in {1..3}; do
            echo -n "  Run $i: "
            { time node openclaw.mjs --version; } 2>&1 | grep -E "real|version" | head -1 || true
        done

        echo -e "\n${BLUE}2. Bun 运行时（推荐）${NC}"
        for i in {1..3}; do
            echo -n "  Run $i: "
            { time bun run openclaw.mjs --version; } 2>&1 | grep -E "real|version" | head -1 || true
        done

        echo -e "\n${BLUE}3. 通过 Bun 启动器${NC}"
        for i in {1..3}; do
            echo -n "  Run $i: "
            { time ./openclaw-bun --version; } 2>&1 | grep -E "real|version" | head -1 || true
        done

        echo
    fi
}

# 运行快速测试
run_quick_test() {
    if [ "$SKIP_TESTS" != "true" ]; then
        echo -e "${YELLOW}🧪 快速测试...${NC}"

        # 使用 Bun 运行测试（如果可用）
        if bun test 2>/dev/null; then
            echo -e "${GREEN}✅ Bun 测试通过${NC}"
        elif pnpm run test:fast 2>/dev/null; then
            echo -e "${GREEN}✅ 快速测试通过${NC}"
        else
            echo -e "${YELLOW}⚠️  测试失败，但继续构建${NC}"
        fi
    fi
}

# 开发环境配置
setup_dev_environment() {
    echo -e "\n${YELLOW}🛠️  配置开发环境...${NC}"

    # 创建 .bun-buildignore 文件
    cat > .bun-buildignore << 'EOF'
# Bun 构建忽略文件
# 避免打包不兼容的依赖

node-llama-cpp
ffmpeg-static
electron
chromium-bidi
playwright-core
EOF

    echo -e "${GREEN}✅ 开发环境配置完成${NC}"
}

# 使用指南
print_usage_guide() {
    echo -e "\n${CYAN}📖 使用指南${NC}"
    echo "========================"
    
    echo -e "\n${GREEN}开发环境（推荐 Bun）：${NC}"
    echo "  • 热重载开发:     bun --hot run src/entry.ts gateway --dev"
    echo "  • 观察模式:       bun --watch run src/entry.ts gateway"
    echo "  • 测试:           bun test 或 pnpm test:fast"
    
    echo -e "\n${GREEN}生产运行：${NC}"
    echo "  • Node.js 运行:   node openclaw.mjs ..."
    echo "  • Bun 运行:       bun run openclaw.mjs ..."
    echo "  • Bun 启动器:     ./openclaw-bun ..."
    
    echo -e "\n${GREEN}性能优化技巧：${NC}"
    echo "  • Bun 比 Node.js 启动快 3-4x"
    echo "  • 使用 'bun run pnpm' 运行 pnpm 命令获得更好性能"
    echo "  • 开发时使用 'bun --hot' 获得最快的热重载"
    echo "  • TypeScript 文件可直接用 bun 运行，无需编译"
}

# 构建摘要
build_summary() {
    echo -e "\n${GREEN}🎉 构建完成！${NC}"
    echo "========================"
    echo -e "${BLUE}📁 构建产物:${NC}"
    echo "  • 编译输出: ./dist/entry.js"
    echo "  • Bun 启动器: ./openclaw-bun"
    
    echo -e "\n${BLUE}🚀 推荐命令:${NC}"
    echo "  • 开发: bun --hot run src/entry.ts gateway --dev"
    echo "  • 运行: ./openclaw-bun gateway ..."
    echo "  • 测试: bun test 或 pnpm test:fast"
    
    echo -e "\n${BLUE}💡 性能提示:${NC}"
    echo "  • Bun 运行时启动速度比 Node.js 快 3-4x"
    echo "  • 所有 pnpm 命令可以通过 'bun run pnpm' 运行"
    echo "  • 开发环境使用 Bun 可以跳过编译步骤"
}

# 主流程
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
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
                echo "  --skip-tests   跳过测试"
                echo "  --no-benchmark 跳过性能测试"
                echo "  --help         显示帮助"
                echo ""
                echo "构建策略:"
                echo "  • 使用 pnpm + tsdown 进行标准构建"
                echo "  • 使用 Bun 作为运行时和开发工具"
                echo "  • 不使用 Bun 打包器（避免依赖兼容性问题）"
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
    build_standard
    create_bun_runtime_launcher
    setup_dev_environment
    run_quick_test
    run_performance_test
    print_usage_guide
    build_summary
}

# 运行主流程
main "$@"
