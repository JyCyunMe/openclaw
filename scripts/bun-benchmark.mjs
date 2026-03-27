// Bun 性能优化脚本
// 用于测试和验证 Bun 的性能提升

import { spawn } from "node:child_process";
import fs from "node:fs";

const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const RESET = "\x1b[0m";

// 测试配置
const RUNS = 5;
const COMMAND = process.argv[2] || "--version";
const ARGS = [COMMAND];

// 运行基准测试
async function benchmark(name, command, args) {
  const times = [];

  console.log(`${CYAN}📊 ${name}${RESET}`);

  for (let i = 0; i < RUNS; i++) {
    const start = performance.now();

    await new Promise((resolve, reject) => {
      const proc = spawn(command, args, {
        stdio: ["ignore", "pipe", "pipe"],
      });

      let stdout = "";
      let stderr = "";

      proc.stdout.on("data", (data) => {
        stdout += data.toString();
      });

      proc.stderr.on("data", (data) => {
        stderr += data.toString();
      });

      proc.on("close", (code) => {
        if (code !== 0 && code !== null) {
          // 忽略错误，只测时间
        }
        resolve();
      });

      proc.on("error", reject);
    });

    const end = performance.now();
    const duration = end - start;
    times.push(duration);

    process.stdout.write(`  Run ${i + 1}: ${duration.toFixed(0)}ms\n`);
  }

  const avg = times.reduce((a, b) => a + b, 0) / times.length;
  const min = Math.min(...times);
  const max = Math.max(...times);

  console.log(
    `  ${GREEN}Average: ${avg.toFixed(0)}ms | Min: ${min.toFixed(0)}ms | Max: ${max.toFixed(0)}ms${RESET}\n`,
  );

  return { avg, min, max };
}

// 检查文件是否存在
function checkFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.log(`${YELLOW}⚠️  文件不存在: ${filePath}${RESET}\n`);
    return false;
  }
  return true;
}

// 主流程
async function main() {
  console.log(`${CYAN}🚀 OpenClaw Bun 性能基准测试${RESET}`);
  console.log(`${CYAN}================================${RESET}\n`);

  const results = {};

  // 测试 Node.js 运行时
  if (checkFile("./openclaw.mjs")) {
    results.node = await benchmark("Node.js 运行时", "node", ["openclaw.mjs", ...ARGS]);
  }

  // 测试 Bun 运行时
  if (checkFile("./openclaw.mjs")) {
    results.bun = await benchmark("Bun 运行时", "bun", ["run", "openclaw.mjs", ...ARGS]);
  }

  // 测试 Bun 优化版本
  if (checkFile("./dist-bun/entry.js")) {
    results.bunOptimized = await benchmark("Bun 优化版本", "bun", [
      "run",
      "dist-bun/entry.js",
      ...ARGS,
    ]);
  }

  // 测试编译后的 Node.js 版本
  if (checkFile("./dist/entry.js")) {
    results.compiled = await benchmark("Node.js 编译版本", "node", ["dist/entry.js", ...ARGS]);
  }

  // 测试二进制版本
  if (checkFile("./bin/openclaw")) {
    results.binary = await benchmark("二进制版本", "./bin/openclaw", ARGS);
  }

  // 汇总结果
  console.log(`${CYAN}📈 性能对比汇总${RESET}`);
  console.log(`${CYAN}===================${RESET}\n`);

  if (results.node && results.bun) {
    const speedup = results.node.avg / results.bun.avg;
    console.log(`Bun vs Node.js: ${GREEN}${speedup.toFixed(2)}x${RESET} 更快\n`);
  }

  if (results.node && results.bunOptimized) {
    const speedup = results.node.avg / results.bunOptimized.avg;
    console.log(`Bun 优化 vs Node.js: ${GREEN}${speedup.toFixed(2)}x${RESET} 更快\n`);
  }

  if (results.node && results.binary) {
    const speedup = results.node.avg / results.binary.avg;
    console.log(`二进制 vs Node.js: ${GREEN}${speedup.toFixed(2)}x${RESET} 更快\n`);
  }

  console.log(`${GREEN}✅ 基准测试完成${RESET}`);
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
