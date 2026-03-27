#!/bin/bash
# 创建 OpenClaw 自包含应用包

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 创建 OpenClaw 自包含应用包${NC}"
echo "=================================="

# 1. 构建
echo -e "${YELLOW}步骤 1: 构建项目...${NC}"
pnpm build

# 2. 创建 bundle 目录
BUNDLE_DIR="openclaw-bundle-$(uname -s)-$(uname -m)"
echo -e "${YELLOW}步骤 2: 创建 bundle 目录...${NC}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# 3. 复制所有必要文件
echo -e "${YELLOW}步骤 3: 复制文件...${NC}"
cp -r dist/ "$BUNDLE_DIR/"
cp -r node_modules/ "$BUNDLE_DIR/"
cp -r assets/ "$BUNDLE_DIR/" 2>/dev/null || true
cp -r extensions/ "$BUNDLE_DIR/" 2>/dev/null || true
cp openclaw.mjs "$BUNDLE_DIR/"
cp package.json "$BUNDLE_DIR/"
[ -f bun.lock ] && cp bun.lock "$BUNDLE_DIR/"

# 4. 创建启动脚本
echo -e "${YELLOW}步骤 4: 创建启动脚本...${NC}"
cat > "$BUNDLE_DIR/openclaw" << 'SCRIPT'
#!/bin/bash
# OpenClaw 启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 优先使用 Bun
if command -v bun &> /dev/null; then
    exec bun run openclaw.mjs "$@"
elif command -v node &> /dev/null; then
    exec node openclaw.mjs "$@"
else
    echo "❌ Error: Neither bun nor node found in PATH"
    exit 1
fi
SCRIPT

chmod +x "$BUNDLE_DIR/openclaw"

# 5. 创建 README
cat > "$BUNDLE_DIR/README.md" << 'README'
# OpenClaw Bundle

这是一个自包含的 OpenClaw 应用包。

## 使用方法

```bash
# 直接运行
./openclaw gateway --dev

# 查看版本
./openclaw --version

# 查看帮助
./openclaw --help
```

## 目录结构

- `dist/` - 编译后的代码
- `node_modules/` - 依赖包
- `assets/` - 资源文件
- `extensions/` - 扩展
- `openclaw.mjs` - 入口文件
- `openclaw` - 启动脚本

## 系统要求

- Node.js 22+ 或 Bun 1.3+
- (可选) 186MB 磁盘空间

## 数据目录

配置和数据存储在 `~/.openclaw/`
README

# 6. 打包
echo -e "${YELLOW}步骤 5: 打包...${NC}"
tar czf "${BUNDLE_DIR}.tar.gz" "$BUNDLE_DIR"

# 7. 完成
echo -e "${GREEN}✅ Bundle 创建成功！${NC}"
echo ""
echo -e "${BLUE}Bundle 信息:${NC}"
echo "  文件名: ${BUNDLE_DIR}.tar.gz"
echo "  大小: $(du -sh "${BUNDLE_DIR}.tar.gz" | cut -f1)"
echo "  文件数: $(find "$BUNDLE_DIR" -type f | wc -l)"
echo ""
echo -e "${BLUE}使用方法:${NC}"
echo "  1. 解压: tar xzf ${BUNDLE_DIR}.tar.gz"
echo "  2. 运行: cd ${BUNDLE_DIR} && ./openclaw gateway"
echo ""
echo -e "${GREEN}🎉 完成！${NC}"
