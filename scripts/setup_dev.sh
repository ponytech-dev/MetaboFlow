#!/usr/bin/env bash
##############################################################################
##  scripts/setup_dev.sh
##  开发环境初始化 / Development Environment Setup
##
##  Sets up Python (uv), creates necessary directories, and runs initial checks.
##  R setup is handled within Docker containers.
##############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========== MetaboFlow 开发环境初始化 / Dev Environment Setup =========="
echo "  项目根目录/Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

## ========================= Python 环境 / Python Environment =========================

echo ""
echo "--- Python 环境 / Python Environment ---"

if ! command -v uv &>/dev/null; then
    echo "  [WARN] uv 未安装/uv not installed. Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

echo "  uv version: $(uv --version)"

## 创建虚拟环境 + 安装依赖 / Create venv + install deps
uv sync
echo "  [OK] Python 依赖已安装/Python dependencies installed"

## ========================= 目录检查 / Directory Check =========================

echo ""
echo "--- 目录结构检查 / Directory Structure Check ---"

REQUIRED_DIRS=(
    "packages/common/metabodata"
    "packages/common/metabodata/tests"
    "packages/engines/xcms-worker/R"
    "packages/engines/xcms-worker/tests/testthat"
    "packages/engines/stats-worker/R"
    "packages/engines/stats-worker/tests/testthat"
    "scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  [OK] $dir"
    else
        echo "  [CREATE] $dir"
        mkdir -p "$dir"
    fi
done

## ========================= 代码检查 / Code Checks =========================

echo ""
echo "--- 代码质量检查 / Code Quality Checks ---"

echo "  Running ruff..."
uv run ruff check . && echo "  [OK] ruff check passed" || echo "  [FAIL] ruff check failed"

echo "  Running mypy..."
uv run mypy packages/common/metabodata/ --ignore-missing-imports && echo "  [OK] mypy passed" || echo "  [FAIL] mypy failed"

echo "  Running pytest..."
uv run pytest packages/common/metabodata/tests/ -v && echo "  [OK] pytest passed" || echo "  [FAIL] pytest failed"

## ========================= 完成 / Done =========================

echo ""
echo "========== 初始化完成 / Setup Complete =========="
echo "可用命令/Available commands:"
echo "  make test-py        — 运行Python测试"
echo "  make lint           — 代码检查 (ruff + mypy)"
echo "  make docker-build   — 构建Docker镜像"
echo "  make docker-up      — 启动Docker容器"
echo "  make verify-parity  — 结果等价性验证"
