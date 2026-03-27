# OpenClaw 精简二进制设计方案

## 🎯 核心理念

**将 CLI + 核心基础设施编译为二进制，channel 实现作为插件动态加载**

## 📦 架构设计

### ✅ 编译为二进制（核心）

```
核心二进制包含：
├── src/infra/           # 基础设施（环境、配置、错误处理）
├── src/memory/          # 内存管理（SQLite 封装）
├── src/media/           # 媒体处理核心
├── src/process/         # 进程管理
├── src/routing/         # 路由核心
├── src/gateway/         # Gateway 服务器核心
├── src/cli/             # CLI 系统
│   ├── program/         # Commander.js 框架
│   ├── gateway-cli/     # Gateway 命令
│   └── *.cli.ts         # 其他 CLI 命令
├── src/provider-web/    # Web 提供者
└── src/channels/        # 仅接口定义
    ├── plugins/         # 插件系统
    ├── *.ts             # 类型定义
    └── registry.ts      # 注册表

预计大小：50-100MB（不包含具体 channel 实现）
```

### 🔌 动态加载（外部）

```
运行时动态加载：
├── extensions/          # 扩展（完全外部）
│   ├── msteams/
│   ├── matrix/
│   └── ...
└── src/channels/*/      # Channel 实现
    ├── telegram/        # Telegram 实现
    ├── discord/         # Discord 实现
    ├── signal/          # Signal 实现
    ├── slack/           # Slack 实现
    ├── imessage/        # iMessage 实现
    └── ...

这些通过 require/import 动态加载
```

## 🔄 加载机制

### 1. 核心二进制启动

```typescript
// 核心入口（编译为二进制）
import { buildProgram } from "./cli/program/build-program.js";
import { registerGatewayCommands } from "./cli/gateway-cli/register.js";
import { registerPluginSystem } from "./channels/plugins/runtime.js";

// 构建基础 CLI
const program = buildProgram();
registerGatewayCommands(program);

// 插件系统（动态加载 channel）
const pluginRegistry = registerPluginSystem(program);

// 解析命令
await program.parseAsync(process.argv);
```

### 2. Channel 动态加载

```typescript
// 插件系统运行时加载
export async function loadChannelPlugin(channelName: string) {
  try {
    // 动态导入 channel 实现
    const channel = await import(`./channels/${channelName}/index.js`);
    return channel.default || channel;
  } catch (error) {
    console.error(`Failed to load channel: ${channelName}`);
    throw error;
  }
}
```

## 📊 大小对比

| 方案           | 大小          | 说明             |
| -------------- | ------------- | ---------------- |
| 完整 bundle    | 978MB         | 包含所有内容     |
| **核心二进制** | **~50-100MB** | **仅核心 + CLI** |
| + Telegram     | +20MB         | 动态加载         |
| + Discord      | +30MB         | 动态加载         |
| + Signal       | +15MB         | 动态加载         |
| 其他 channels  | +50MB         | 按需加载         |

## 🎯 实施步骤

### Step 1: 创建核心入口

```typescript
// src/core-binary-entry.ts
import { runCli } from "./cli/run-main.js";
import { initPluginRuntime } from "./channels/plugins/runtime.js";

// 初始化插件系统
initPluginRuntime();

// 运行 CLI
runCli(process.argv);
```

### Step 2: 编译核心

```bash
bun build src/core-binary-entry.ts \
  --outfile ./dist/core-binary.js \
  --target node \
  --external "src/channels/telegram/*" \
  --external "src/channels/discord/*" \
  --external "src/channels/signal/*" \
  --external "src/channels/slack/*" \
  --external "src/channels/imessage/*" \
  --external "src/channels/whatsapp/*" \
  --external "src/channels/line/*" \
  --external "extensions/*"
```

### Step 3: 编译为二进制

```bash
bun build --compile \
  ./dist/core-binary.js \
  --outfile ./bin/openclaw-core \
  --target=bun-linux-x86_64
```

### Step 4: 打包结构

```
openclaw-core/
├── bin/
│   └── openclaw-core     # 核心二进制 (50-100MB)
├── channels/            # Channel 实现（外部）
│   ├── telegram/
│   ├── discord/
│   └── ...
├── extensions/          # 扩展（外部）
│   └── ...
└── openclaw             # 启动脚本
```

## ✅ 优势

1. **快速启动** - 核心功能立即可用
2. **按需加载** - 只加载使用的 channels
3. **小体积** - 核心二进制只有 50-100MB
4. **易维护** - Channel 独立开发和部署
5. **灵活性** - 可以动态添加/删除 channels

## 🚀 使用示例

```bash
# 安装核心
tar xzf openclaw-core.tar.gz
cd openclaw-core

# 使用核心功能（不需要 channels）
./openclaw-core gateway run --port 18789

# 动态加载 channels（按需）
./openclaw-core channels install telegram
./openclaw-core gateway run --channels telegram,discord
```
