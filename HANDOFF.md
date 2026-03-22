# MetaboFlow HANDOFF — 2026-03-21 (Phase 1 MVP)

## 项目状态：Phase 1 MVP 核心功能全部实现

### 一句话总结
MetaboFlow Phase 1 MVP 核心功能完成：4 样本 E2E 验证通过（46,862 features, 4,495 significant）+ 用户认证 + 前端多页架构 + 11 个发表级 R 图表模板 + PDF/Word 报告导出。

### 本次 Session 完成的工作

| Task | 内容 | 状态 |
|------|------|------|
| Task 0 | Result 持久化到 DB | ✅ |
| Task 1 | 50 种图表模板调研目录 | ✅ |
| Task 2a | chart-r-worker 基础设施（theme/palette/renderer/Dockerfile） | ✅ |
| Task 2b | 11 个 A 类基础模板实现 | ✅ |
| Task 3 | 用户认证（User/InviteCode + JWT + 前端 login/register） | ✅ |
| Task 4 | 前端多页架构（7 个页面 + Pipeline 设计器 + 结果 5 Tab） | ✅ |
| Task 5 | 报告导出（Quarto PDF + officer Word + 自动 Methods） | ✅ |

### 架构（12 个 Docker 服务）
```
前端 (Next.js :3005) → 后端 (FastAPI :8000) → Celery (Redis) →
  ├─ xcms-worker (R Plumber :8001) — 峰检测+去冗余+预处理
  ├─ stats-worker (R Plumber :8002) — limma 差异分析
  ├─ annot-worker (Python matchms :8006) — MS2 谱图匹配
  ├─ chart-service (Python :8005) — 图表生成（旧，Python）
  ├─ chart-r-worker (R Plumber :8008) — 发表级 R 图表模板（新）
  ├─ report-worker (R Plumber :8009) — PDF/Word 报告生成（新）
  ├─ sirius-worker (:8007) — 结构预测
  ├─ PostgreSQL + Redis
```

### Phase 完成度
```
Phase 0   ████████████████████ 100%
Phase 0.5 ████████████████████ 100%
Phase 1   ██████████████████░░  90% — 核心全部完成，缺：剩余39模板+100解读+集成测试
Phase 2   ███░░░░░░░░░░░░░░░░░  15%
```

### 前端页面结构
```
/login                          → 登录
/register                       → 注册（邀请码）
/projects                       → 项目列表
/projects/:id                   → 项目概览
/projects/:id/upload            → 数据上传（拖拽+元数据）
/projects/:id/pipeline          → Pipeline 设计器（引擎选择+参数调整）
/projects/:id/monitor           → 实时运行监控（SSE）
/projects/:id/results           → 结果展示（5 Tab: Overview/Charts/Features/Annotation/Pathway）
/projects/:id/report            → 报告生成（PDF/Word，图表选择）
```

### 图表模板系统
- 50 种模板已编目：`docs/chart-template-catalog.md`
- 11 个 A 类基础模板已实现：volcano, PCA, heatmap, boxplot, mzrt_cloud, qc_intensity, rsd_distribution, correlation_heatmap, feature_bar, hexbin_density, missing_heatmap
- 统一 Nature 风格 ggplot2 主题 + NPG 配色
- Plumber API: POST /render → SVG + PDF + PNG

### 下一步
1. **集成测试**（docker compose build 全部服务，端到端验证）
2. **剩余 39 个模板实现**（9 基础 B/C/D 类 + 30 高级）
3. **100 个中英文解读文件**
4. **docker-compose 集成 chart-r-worker + report-worker 到后端 API**
5. **内测部署**

### 设计文档索引
| 文档 | 路径 |
|------|------|
| Phase 1 总览 spec | `docs/superpowers/specs/2026-03-21-phase1-mvp-complete-design.md` |
| 图表模板 spec | `docs/superpowers/specs/2026-03-21-chart-template-system-design.md` |
| 前端架构 spec | `docs/superpowers/specs/2026-03-21-frontend-multipage-architecture-design.md` |
| 报告导出 spec | `docs/superpowers/specs/2026-03-21-report-export-system-design.md` |
| 用户认证 spec | `docs/superpowers/specs/2026-03-21-user-auth-system-design.md` |
| 实现计划 | `docs/superpowers/plans/2026-03-21-phase1-mvp-implementation.md` |
| 图表目录 | `docs/chart-template-catalog.md` |

### 启动命令
```bash
cd ~/pony/MetaboFlow
FRONTEND_PORT=3005 docker compose up -d
# 前端: http://localhost:3005
# API: http://localhost:8000/docs
```
