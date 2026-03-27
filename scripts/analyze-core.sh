#!/bin/bash
# 分析 OpenClaw 核心模块

echo "🔍 分析 OpenClaw 核心模块..."
echo ""

echo "📁 核心目录（应该编译为二进制）："
echo "  • src/infra/       - 基础设施"
echo "  • src/memory/      - 内存管理"
echo "  • src/media/       - 媒体处理"
echo "  • src/process/     - 进程管理"
echo "  • src/routing/     - 路由核心"
echo "  • src/channels/    - 通道核心（不含实现）"
echo ""

echo "📁 动态加载部分（不编译）："
echo "  • extensions/*     - 扩展（完全外部）"
echo "  • src/channels/*/  - 具体通道实现"
echo "  • src/cli/         - CLI 命令（可选）"
echo ""

echo "📊 分析依赖关系："
echo "查找哪些模块依赖 channels/plugins..."

grep -r "from.*channels" src/infra/ src/routing/ src/entry.ts 2>/dev/null | head -10
echo ""
grep -r "from.*plugins" src/infra/ src/routing/ 2>/dev/null | head -10

