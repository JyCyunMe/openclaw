# OpenClaw CLI 性能分析与二进制化方案

## 🔍 CLI 性能瓶颈分析

### 当前 CLI 启动流程

```typescript
// src/cli/run-main.ts - CLI 主入口
export async function runCli(argv: string[] = process.argv) {
  // 步骤 1-10: 基础设置（~10ms）
  normalizeWindowsArgv(argv);
  parseCliProfileArgs(normalizedArgv);
  loadDotEnv({ quiet: true });
  normalizeEnv();

  // 步骤 11: 运行时检查（~5ms）
  assertSupportedRuntime();

  // 步骤 12: 尝试路由（~5ms）
  await tryRouteCli(normalizedArgv);

  // 步骤 13: 动态导入（瓶颈！~30-50ms）
  await import("./program.js"); // ❌ 慢
  await import("./program/program-context.js"); // ❌ 慢
  await import("./program/command-registry.js"); // ❌ 慢
  await import("./program/register.subclis.js"); // ❌ 慢
  await import("../plugins/cli.js"); // ❌ 慢
  await import("../config/config.js"); // ❌ 慢

  // 步骤 14: 解析命令（~5ms）
  await program.parseAsync(parseArgv);
}
```

### 性能分解（估算）

| 步骤     | 耗时        | 原因                |
| -------- | ----------- | ------------------- |
| 基础设置 | 10ms        | 同步操作            |
| 动态导入 | **30-50ms** | **模块解析 + 加载** |
| 命令解析 | 5ms         | Commander.js 解析   |
| **总计** | **45-65ms** | **动态导入占 70%**  |

## 💡 为什么使用动态导入？

OpenClaw 使用动态导入的原因：

1. **按需加载** - 只加载需要的 CLI 命令
2. **避免循环依赖** - 延迟加载解决循环引用
3. **减小初始包大小** - 核心包更小

## 🎯 二进制化方案

### 方案 1: 预编译 CLI 模块（推荐）

**将 CLI 相关模块预编译为单个 bundle，消除动态导入**

```bash
# 创建 CLI bundle
bun build src/cli/run-main.ts \
  --outfile ./dist/cli-bundle.js \
  --target node \
  --format esm \
  --minify \
  --sourcemap=inline
```

**创建精简入口：**

```typescript
// src/cli-fast-entry.ts
// 静态导入所有 CLI 模块
import { runCli } from "./cli/run-main.js";

// 预热常用模块
import "./program.js";
import "./program/build-program.js";
import "./program/command-registry.js";
import "./program/register.subclis.js";

// 运行
runCli(process.argv);
```

**预期性能提升：30-50ms → 5-10ms（快 5-10x）**

### 方案 2: 使用 pkg 编译 CLI

```bash
# 安装 pkg
bun add -d pkg

# 编译 CLI
bunx pkg dist/cli-bundle.js \
  --targets node18-linux-x64,node18-macos-x64 \
  --output bin/openclaw-cli
```

### 方案 3: 使用 Nexe

```bash
# 安装 nexe
bun add -d nexe

# 编译
bunx nexe dist/cli-bundle.js \
  --target node18-linux-x64 \
  --output bin/openclaw-cli
```

## 📊 性能对比预估

| 方案             | 启动时间 | 大小   | 可行性    |
| ---------------- | -------- | ------ | --------- |
| 当前（动态导入） | 50-70ms  | ~10MB  | ✅ 当前   |
| CLI Bundle       | 10-20ms  | ~15MB  | ✅ 可行   |
| pkg 二进制       | 5-15ms   | ~50MB  | ⚠️ 需测试 |
| 完整二进制       | <5ms     | ~100MB | ❌ 不可行 |

## 🚀 立即可行的优化

### Step 1: 创建 CLI Bundle

```bash
bun build src/cli/run-main.ts \
  --outfile ./dist/cli-fast.js \
  --external "src/channels/*" \
  --external "extensions/*" \
  --minify
```

### Step 2: 创建快速启动脚本

```typescript
// src/fast-cli.ts
import { runCli } from "./dist/cli-fast.js";
runCli(process.argv);
```

### Step 3: 编译为二进制

```bash
bun build --compile \
  src/fast-cli.ts \
  --outfile ./bin/openclaw-cli \
  --target=bun-linux-x86_64
```

## ✅ 预期收益

1. **CLI 启动快 5-10x**：50-70ms → 5-10ms
2. **二进制文件独立**：不需要 node_modules
3. **部署简单**：单一可执行文件
4. **向后兼容**：功能完全相同

## 🎯 实施建议

1. 先尝试 CLI Bundle 方案（最简单）
2. 如果成功，再尝试编译为二进制
3. 保持 channels/插件 动态加载（不编译）
