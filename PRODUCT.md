# MetaboFlow — 产品文档

> 最后更新：2026-03-21
> 自动维护：代码变更时由 Claude Code 同步更新

## 定位

代谢组学引擎聚合平台。不自研核心算法，封装集成社区成熟引擎（XCMS、MS-DIAL、MZmine 等），统一接口，用户自由选择和切换。类似 OpenRouter 对 LLM 的聚合。

## 目标用户

| Persona | 身份 | 核心诉求 |
|---------|------|---------|
| A | 湿实验室独立研究员 | 一键全流程 + 出版级图表 + 数据留在本地 |
| B | 质谱平台服务人员 | 批量处理 + 引擎可选 + 自动报告 |
| C | 生信方法学研究者 | 多引擎并行 + benchmark 对比 + 可发表数据 |
| D | 制药/临床研究员 | 合规审计 + 数据溯源 |

## 核心功能

- ✅ MetaboData 核心中间格式（所有引擎统一输入输出）
- ✅ xcms-worker（峰检测 + 预处理 + 注释，Docker 容器）
- ✅ stats-worker（差异分析 + 通路富集 + 图表，Docker 容器）
- ✅ 与 MetaboFlow_v1.r 数值一致验证（tolerance 1e-6）
- 🚧 FastAPI 后端
- 🚧 Next.js 前端（零代码 Web 界面）
- 📋 MS-DIAL 引擎适配器
- 📋 MZmine 引擎适配器
- 📋 多引擎并行对比模式
- 📋 自动报告生成（PDF + Word 双格式，含自动 Methods 段落）
- 📋 chart-service（50 种发表级图表模板：20 基础 + 30 高级，R 端渲染）
- 📋 用户认证（邀请码 + 邮箱密码 + JWT）

## 核心工作流

```
/projects                    → 项目列表
/projects/:id/upload         → 上传 mzML/mzXML
/projects/:id/pipeline       → Pipeline 设计器（每环节选引擎+调参数，支持多条 pipeline 组合）
/projects/:id/monitor        → 实时运行监控（SSE 推送）
/projects/:id/results        → 结果展示（6 Tab：Overview/Charts/Features/Annotation/Pathway/Report）
/projects/:id/report         → 报告导出（PDF + Word）
```

### Pipeline 设计器

- 每个分析环节 dropdown 选择引擎（Phase 1 各环节仅 1 个选项）
- 每个引擎独立参数面板
- 可创建多条 pipeline 组合，"Run All" 同时启动
- 架构预留：引擎列表来自后端 `/engines` API，Phase 2 新引擎直接出现

### 图表模板系统

- 50 种模板：20 基础（B01-B20）+ 30 高级（A01-A30），完整目录见 `docs/chart-template-catalog.md`
- 调研来源：Nature/Science 正刊+子刊 2020-2026 代谢组学论文
- R 端渲染（ggplot2 + ComplexHeatmap + EnhancedVolcano + patchwork）
- 统一 Nature 风格配色（NPG 色板，色盲友好）
- 每种图表附中英文解读说明
- 一键出图，发表级质量（SVG/PDF/PNG 300dpi）
- 数据源分类：26 个 A 类（直接可用）、9 个 B 类、4 个 C 类、2+8 个 D 类
- 筛选敏感性：34 个 filter-sensitive、16 个 global

### 报告导出

- PDF（Quarto）+ Word（officer R 包）双格式
- 自动生成可发表 Methods 段落（引擎+参数自动填入）
- 报告图表复用图表模板系统输出（300 dpi PNG）

## 技术架构

```
packages/
├── common/metabodata/     ← MetaboData Python 类（核心中间格式）
├── engines/
│   ├── xcms-worker/       ← R xcms 4.2.3 引擎（Docker 容器）
│   └── stats-worker/      ← R 统计分析引擎（Docker 容器）
├── backend/               ← FastAPI 后端（🚧）
├── frontend/              ← Next.js 前端（🚧）
└── chart-service/         ← 可视化服务（📋）
```

- 每个引擎独立 Docker 容器，docker compose 编排
- EngineAdapter 统一接口（见 docs/product-development-plan.md §2.4）
- 引擎版本精确锁定，禁止 `latest` tag
- 分析参数快照 + 引擎版本记录到 MetaboData.uns["provenance"]

## 依赖与基础设施

- Python 3.11+, uv 包管理
- R 4.5.0+, renv 锁定
- Docker + docker compose
- Node.js 20+（前端）

## 当前限制

- 仅支持 xcms 引擎，MS-DIAL 和 MZmine 适配器 Phase 2 开发
- Web 界面骨架已搭建，结果展示页和图表系统开发中
- 图表模板系统开发中（50 种模板）
- 用户认证系统待实现

## 集成点

| 接口 | 说明 |
|------|------|
| MetaboData JSON | 引擎间统一数据交换格式 |
| Docker API | 引擎容器管理 |
| FastAPI REST（🚧） | Web 前端与后端通信 |

## 文档索引

| 文档 | 路径 |
|------|------|
| 产品开发计划 | `docs/product-development-plan.md` |
| 引擎对比报告 | `docs/engine-comparison-report.md` |
| 科研计划 | `docs/research-plan.md` |
| 用户手册（中文） | `docs/MetaboFlow_用户手册_中文.md` |
| 用户手册（英文） | `docs/MetaboFlow_UserManual_EN.md` |
| 原始脚本（ground truth） | `MetaboFlow_v1.r` |

## 变更日志（最近 5 条）

| 日期 | 变更 | commit |
|------|------|--------|
| 2026-03-21 | Phase 1 设计确认：图表模板系统(50种)、前端多页架构、报告导出(PDF+Word)、用户认证(邀请码+JWT) | — |
| 2026-03-21 | 全栈 E2E 验证通过（2样本，42,216 features，594.7s） | — |
| 2026-03-15 | 产品开发计划 v2.0 确认 | — |
