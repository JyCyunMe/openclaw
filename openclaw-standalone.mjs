#!/usr/bin/env node
// OpenClaw 独立二进制入口

const MIN_NODE_MAJOR = 22;
const MIN_NODE_MINOR = 12;

const parseNodeVersion = (rawVersion) => {
  const [majorRaw = "0", minorRaw = "0"] = rawVersion.split(".");
  return {
    major: Number(majorRaw),
    minor: Number(minorRaw),
  };
};

const isSupportedNodeVersion = (version) =>
  version.major > MIN_NODE_MAJOR ||
  (version.major === MIN_NODE_MAJOR && version.minor >= MIN_NODE_MINOR);

const ensureSupportedNodeVersion = () => {
  if (isSupportedNodeVersion(parseNodeVersion(process.versions.node))) {
    return;
  }
  process.stderr.write(`openclaw: Node.js v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+ is required\n`);
  process.exit(1);
};

ensureSupportedNodeVersion();

// 动态导入入口
import("./dist/entry.js").catch((err) => {
  console.error("Failed to load entry:", err);
  process.exit(1);
});
