#!/usr/bin/env bash
# 运行 WhaleBarKit 断言检查器（本机 CLT 无 XCTest/Testing，用自研检查器承载单测）
set -euo pipefail
cd "$(dirname "$0")/.."
swift run -c debug WhaleBarKitChecks
