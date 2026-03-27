#!/usr/bin/env node
// OpenClaw 核心二进制入口
// 包含 CLI 和核心基础设施，channels 动态加载

import { initPluginRuntime } from "./channels/plugins/runtime.js";
import { runCli } from "./cli/run-main.js";

// 初始化插件运行时（支持动态加载 channels）
initPluginRuntime();

// 运行 CLI
runCli(process.argv).catch((error) => {
  console.error("[openclaw] Failed to start:", error);
  process.exit(1);
});
