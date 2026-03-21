# MetaboFlow HANDOFF — 2026-03-21 (Updated)

## 项目状态：Phase 1 MVP 4 样本 E2E 全链路验证通过

### 一句话总结
MetaboFlow 全栈 4 样本 E2E 验证通过：mzML 上传 → xcms 峰检测（46,862 features）→ CAMERA 去冗余 → limma 差异分析（4,495 significant features）→ MetaboData HDF5 输出，耗时约 21 分钟。

### 本次 Session 修复的集成问题

| 问题 | 根因 | 修复 |
|------|------|------|
| xcms-worker 4 样本崩溃 | Docker 内 fork 并行不稳定 | 加 `register(SerialParam())` |
| Group 分配硬编码 | xcms 用正则猜 group 而非 API 传入 | 接受 `sample_metadata` 参数 |
| stats-worker 从未执行 | 缺少 `metabodata_bridge.R` + `rhdf5` | 复制文件 + Dockerfile 加依赖 |
| R JSON 标量数组问题 | R jsonlite 把标量包装为 `[value]` | Celery task 中 unwrap |
| HDF5 读取失败 | `column_names` attribute 未写入 | fallback 到从 dataset 名推断 |
| Celery 不检查错误 | xcms/stats 返回 error 被忽略 | 检查 success/error 字段 |

### 架构
```
前端 (Next.js :3005) → 后端 (FastAPI :8000) → Celery (Redis) →
  ├─ xcms-worker (R Plumber :8001) — 峰检测+去冗余+预处理 → MetaboData HDF5
  ├─ stats-worker (R Plumber :8002) — limma 差异分析 ← MetaboData HDF5
  ├─ annot-worker (Python matchms :8006) — MS2 谱图匹配（MFSL 52库/96万化合物）
  ├─ chart-service (Python :8005) — 图表生成
  └─ sirius-worker (:8007) — 结构预测（待注册账号）
```

### Phase 完成度
```
Phase 0   ████████████████████ 100% — monorepo + 模块化 + Docker + CI/CD + E2E
Phase 0.5 ████████████████████ 100% — MFSL 数据库（52库/96万化合物/669K去重谱图）
Phase 1   ████████████████░░░░  75% — 4样本E2E通过，设计全部确认，缺图表模板/前端结果页/报告导出/认证
Phase 2   ███░░░░░░░░░░░░░░░░░  15% — SIRIUS 代码完成/MSI 5级定义/MFSL 竞品超越
```

### 已验证的 4 样本 E2E 数据流
```
4 x mzML (SA1/SA2 vs SB1/SB2, MTBLS733 斑马鱼数据)
  → xcms /run_pipeline (SerialParam, ~21min)
    → 143,933 chromatographic peaks
    → 46,862 features (grouped + filled)
    → CAMERA 去冗余
    → metabodata.h5
  → stats /run_stats
    → limma: 4,495 significant features (adj.P<0.05, |log2FC|>1.5)
    → metabodata_stats.h5
  → completed (1262s)
```

### Phase 1 已确认设计（4 段）

| 设计 | 文档 |
|------|------|
| 图表模板系统 | `docs/superpowers/specs/2026-03-21-chart-template-system-design.md` |
| 前端多页架构 | `docs/superpowers/specs/2026-03-21-frontend-multipage-architecture-design.md` |
| 报告导出系统 | `docs/superpowers/specs/2026-03-21-report-export-system-design.md` |
| 用户认证系统 | `docs/superpowers/specs/2026-03-21-user-auth-system-design.md` |
| 完整总览 | `docs/superpowers/specs/2026-03-21-phase1-mvp-complete-design.md` |

### Phase 1 下一步（优先级排序）
1. **图表模板调研**（4 Agent 并行：调研/数据需求/PonylabASMS参考/配色系统）
2. **前端多页架构实现**（Pipeline 设计器 + 结果展示 5 Tab）
3. **报告导出**（PDF Quarto + Word officer，自动 Methods 段落）
4. **用户认证**（邀请码 + JWT + 数据隔离）
5. **Result 持久化**（Celery task 写回 n_features/n_significant 到 DB）

### 已知待修复
- API `/result` 返回 0：Celery task 的 runtime 数据未写回 DB（n_features/n_significant 只在日志中）
- `max(nchar(...))` 警告：HDF5 写入时空字符串列触发，无害但应清理

### 启动命令
```bash
cd ~/pony/MetaboFlow
FRONTEND_PORT=3005 docker compose up -d
# 前端: http://localhost:3005
# API: http://localhost:8000/docs
```
