# OpenClaw 二进制部署方案 - 最终可行方案

## 🎯 问题分析

### 为什么 Bun --compile 不工作？

OpenClaw 使用了以下与 Bun 打包器**不兼容**的依赖：

```javascript
// ❌ node-llama-cpp - 顶级 await
export const builtinLlamaCppRelease = await getBinariesGithubRelease();

// ❌ ffmpeg-static - 条件 require
const ffmpegStatic = require("ffmpeg-static");

// ❌ playwright - 子路径导入
require("chromium-bidi/lib/cjs/...");

// ❌ electron - 平台特定
require("electron");
```

这些依赖在 Bun 的静态分析阶段无法正确解析。

## ✅ 真正可行的"二进制"方案

### 方案 1: Bun App Bundle（推荐）

**创建一个自包含的应用包**

```bash
#!/bin/bash
# scripts/create-bundle.sh

set -e

echo "📦 创建 OpenClaw 自包含应用包"

# 1. 构建
pnpm build

# 2. 创建 bundle 目录
BUNDLE_DIR="openclaw-bundle-$(uname -s)-$(uname -m)"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# 3. 复制所有必要文件
cp -r dist/ "$BUNDLE_DIR/"
cp -r node_modules/ "$BUNDLE_DIR/"
cp -r assets/ "$BUNDLE_DIR/" 2>/dev/null || true
cp -r extensions/ "$BUNDLE_DIR/" 2>/dev/null || true
cp openclaw.mjs "$BUNDLE_DIR/"
cp package.json "$BUNDLE_DIR/"
cp bun.lock "$BUNDLE_DIR/" 2>/dev/null || true

# 4. 创建启动脚本
cat > "$BUNDLE_DIR/run" << 'EOF'
#!/bin/bash
# OpenClaw 启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 优先使用 Bun
if command -v bun &> /dev/null; then
    exec bun run openclaw.mjs "$@"
else
    exec node openclaw.mjs "$@"
fi
EOF

chmod +x "$BUNDLE_DIR/run"

# 5. 打包
tar czf "${BUNDLE_DIR}.tar.gz" "$BUNDLE_DIR"

echo "✅ Bundle created: ${BUNDLE_DIR}.tar.gz"
echo "📁 Size: $(du -sh "${BUNDLE_DIR}.tar.gz" | cut -f1)"
```

**使用**:

```bash
./scripts/create-bundle.sh

# 部署到目标机器
tar xzf openclaw-bundle-Linux-x86_64.tar.gz
cd openclaw-bundle-Linux-x86_64
./run gateway --dev
```

### 方案 2: Docker Single Binary（推荐用于生产）

**创建一个真正独立的"二进制"镜像**

```dockerfile
# Dockerfile.single-binary
FROM oven/bun:1.3.11 AS builder

WORKDIR /app
COPY package.json bun.lockb* ./
RUN bun install --production

COPY . .
RUN pnpm build

# 运行时镜像
FROM oven/bun:1.3.11

WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/openclaw.mjs ./openclaw.mjs
COPY --from=builder /app/assets ./assets
COPY --from=builder /app/extensions ./extensions

ENV NODE_ENV=production

ENTRYPOINT ["bun", "run", "openclaw.mjs"]
CMD ["gateway"]

# 构建和导出
docker build -f Dockerfile.single-binary -t openclaw:latest .

# 导出为 tar（类似二进制）
docker save openclaw:latest | gzip > openclaw-docker.tar.gz
```

**使用**:

```bash
# 构建
docker build -f Dockerfile.single-binary -t openclaw .

# 运行（真正的单一部署单元）
docker run -d \
  --name openclaw \
  -p 18789:18789 \
  -v ~/.openclaw:/app/.openclaw \
  openclaw
```

### 方案 3: NPM Global Install（最简单）

**将 OpenClaw 安装为全局命令**

```bash
# 安装到全局
pnpm install -g .

# 任何地方都可以使用
openclaw gateway
openclaw --version
```

这会创建：

- `/usr/local/bin/openclaw` (可执行链接)
- 所有依赖都被安装
- 像原生二进制一样使用

### 方案 4: 使用 pkg（实验性）

**尝试使用 pkg 打包器**

```bash
# 安装 pkg
bun add -d pkg

# 创建入口
cat > openclaw-pkg.js << 'EOF'
#!/usr/bin/env node
require("./dist/entry.js");
EOF

# 打包
bunx pkg openclaw-pkg.js \
  --targets node18-linux-x64,node18-macos-x64,node18-win-x64 \
  --output bin/openclaw-pkg
```

**注意**: pkg 也可能遇到相同的问题

## 🎯 推荐部署流程

### 开发环境

```bash
bun --hot run src/entry.ts gateway --dev
```

### 测试环境

```bash
# 1. 创建 bundle
./scripts/create-bundle.sh

# 2. 部署
scp openclaw-bundle-*.tar.gz user@test-server:
ssh test-server "tar xzf openclaw-bundle-*.tar.gz && cd openclaw-bundle-* && ./run gateway"
```

### 生产环境

```bash
# Docker 部署（推荐）
docker build -t openclaw .
docker run -d --restart=always -p 18789:18789 openclaw
```

## 📊 方案对比

| 方案            | 优点       | 缺点         | 推荐度     |
| --------------- | ---------- | ------------ | ---------- |
| **Bun Runtime** | 快、简单   | 需要 Bun     | ⭐⭐⭐⭐⭐ |
| **Bundle**      | 自包含     | 文件大       | ⭐⭐⭐⭐   |
| **Docker**      | 最可靠     | 需要 Docker  | ⭐⭐⭐⭐⭐ |
| **NPM Global**  | 最简单     | 需要安装依赖 | ⭐⭐⭐⭐   |
| **Bun Binary**  | 真正二进制 | **不可行**   | ❌         |
| **pkg**         | 传统方式   | 兼容性问题   | ⭐⭐       |

## 🚀 立即可用的方案

### 选项 A: 使用 Bundle（最接近二进制体验）

```bash
# 创建
cat > scripts/make-bundle.sh << 'EOF'
#!/bin/bash
pnpm build
mkdir -p openclaw-bundle
cp -r dist node_modules assets extensions openclaw.mjs openclaw-bundle/
echo '#!/bin/bash' > openclaw-bundle/openclaw
echo 'cd "$(dirname "$0")" && bun run openclaw.mjs "$@"' >> openclaw-bundle/openclaw
chmod +x openclaw-bundle/openclaw
tar czf openclaw-bundle.tar.gz openclaw-bundle
echo "✅ Bundle created: openclaw-bundle.tar.gz"
EOF
chmod +x scripts/make-bundle.sh
./scripts/make-bundle.sh

# 部署
tar xzf openclaw-bundle.tar.gz
cd openclaw-bundle
./openclaw gateway
```

### 选项 B: 使用 Docker（生产推荐）

```bash
docker build -t openclaw .
docker run -d -p 18789:18789 --name openclaw openclaw
```

## 💡 总结

**为什么不能有真正的二进制？**

- OpenClaw 依赖了与静态打包不兼容的 npm 包
- node-llama-cpp, playwright, ffmpeg-static 等无法被 Bun 打包

**最佳的"二进制"体验：**

1. ✅ **Docker 镜像** - 最接近真正的二进制
2. ✅ **Bundle** - 自包含的压缩包
3. ✅ **NPM Global** - 像二进制一样使用

这些都是**生产就绪**且**真正可用**的方案！
