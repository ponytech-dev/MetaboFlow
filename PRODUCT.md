# MetaboFlow — 产品文档

> 最后更新：2026-03-19
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
- 📋 自动报告生成（Nature 级图表）
- 📋 chart-service（出版级可视化服务）

## 核心工作流

```
用户上传 mzML/mzXML
  → 选择引擎（XCMS / MS-DIAL / MZmine）
  → 配置参数（或用预设）
  → 执行分析管线
     ├── 峰检测 → 分组 → Gap-fill → Feature 提取
     ├── 差异分析（fold change + t-test）
     ├── 通路富集（ORA / GSEA）
     └── 图表生成（火山图 / 热图 / PCA / 通路图）
  → 下载结果 + 分析报告
```

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

- 仅支持 xcms 引擎，MS-DIAL 和 MZmine 适配器未开发
- 无 Web 界面，需命令行操作
- 图表生成依赖 R，尚未独立为 chart-service

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
| 2026-03-15 | 产品开发计划 v2.0 确认 | — |
