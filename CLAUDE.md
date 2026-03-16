# MetaboFlow 项目规则

## 项目定位
代谢组学引擎聚合平台——不自研核心算法引擎，封装集成现有社区引擎，统一接口。
独立项目，不与 PonyLab / PonylabASMS 混合。

## 技术栈
- **Python**: 3.11+, uv 包管理, FastAPI 后端
- **R**: 4.5.0+, renv 锁定, 引擎容器内运行
- **前端**: React + Next.js + Tailwind + shadcn/ui（Phase 1 开始）
- **Docker**: 每个引擎独立容器，docker compose 编排

## 代码规范
- Python: ruff lint + mypy 严格模式
- R: 函数式风格，不依赖全局变量，参数显式传递
- 测试: Python pytest / R testthat
- 引擎版本必须精确锁定，禁止 `latest` tag

## 关键原则
1. MetaboData 是核心中间格式，所有引擎输入输出都经过它
2. 引擎适配器遵循 EngineAdapter 接口（见 docs/product-development-plan.md §2.4）
3. 每次分析的参数快照 + 引擎版本记录到 MetaboData.uns["provenance"]
4. R 代码拆分为 xcms-worker 和 stats-worker 两个独立容器

## 文件结构
- `packages/common/metabodata/` — MetaboData Python 类
- `packages/engines/xcms-worker/` — 峰检测 + 预处理 + 注释
- `packages/engines/stats-worker/` — 差异分析 + 通路富集 + 图表
- `packages/backend/` — FastAPI 后端（Phase 1）
- `packages/frontend/` — Next.js 前端（Phase 1）
- `docs/` — 产品计划、战略分析、科研计划
- `MetaboFlow_v1.r` — 原始脚本，作为 ground truth 保留

## 验证标准
- 模块化代码的输出必须与 v1.r 数值一致（tolerance 1e-6）
- 所有引擎的 Docker 镜像必须能独立构建
- CI 全绿才能合并 PR
