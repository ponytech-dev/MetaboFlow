# Task: Phase 0 收尾 + Phase 1 核心打通
Created: 2026-03-21
Updated: 2026-03-21 02:50

## Objective
全栈端到端验证通过：前端上传 mzML → 后端编排 → xcms 峰检测 → stats 差异分析 → 前端展示结果

## Phases

### Phase 0 收尾（已完成）

- [x] Step 1: Git commit + push
- [x] Step 2: MetaboData HDF5 序列化（已有，12/12 测试通过）
- [x] Step 3: Docker 镜像重建（含 CAMERA，2.68GB）
- [x] Step 4: E2E Docker 测试（7 步全通，CAMERA 首次通过）
- [x] Step 5: CHECKSUMS 更新
- [x] Step 6: R↔Python MetaboData 桥（metabodata_bridge.R）

### Phase 1 数据通路打通（已完成代码，等镜像构建）

- [x] Step 7: xcms Plumber `/run_pipeline` 输出 MetaboData HDF5
- [x] Step 8: stats Plumber `/run_stats` 接收 MetaboData HDF5
- [x] Step 9: annot-worker 对接 deduplicated/ 去重库
- [x] Step 10: 后端 analysis_tasks 串联 MetaboData 流
- [x] Step 11: 前端 Wizard → API → 结果页
- [x] Step 12: Docker compose 全栈启动（10 服务，9 healthy）
- [x] Step 13: Celery 任务注册 + API 端到端验证（create→upload→start→completed）
- [x] Step 14: 文件跨容器可见（共享 /data volume）
- [ ] Step 15: xcms-worker 安装 Bioconductor 包 ← BUILDING
  产出：xcms-worker 能处理 mzML 文件，返回非零 features
  验证：`curl POST /run_pipeline` → `n_features > 0`
- [ ] Step 16: 真实 mzML 全流程端到端 ← BLOCKED by Step 15
  产出：上传 2 mzML → 检测到 features → 差异分析 → completed
  验证：`GET /progress` 显示 n_features > 0

## 已修复的集成问题

| 问题 | 修复 |
|------|------|
| Frontend TS 类型不匹配 | 用 AnalysisConfig camelCase 属性 |
| Next.js standalone 输出缺失 | 加 `output: 'standalone'` |
| Celery 找不到 celery 命令 | 改为 `uv run celery` |
| Frontend 端口 3000 被占 | 改为 `${FRONTEND_PORT:-3001}` |
| R workers 缺 plumber（libsodium） | Dockerfile 加 `libsodium-dev` |
| Celery 不注册 tasks | `-I app.tasks.analysis_tasks` 显式导入 |
| _analyses 字典已被 SQLAlchemy 替代 | 改用 analysis_service API |
| AnalysisResult 没有 config 属性 | 直接从 DB 读 config_json |
| Path import 在使用之后 | 移到文件顶部 |
| 上传路径 ./data vs /data | 改为绝对路径 /data/ |
| xcms-worker 缺 Bioconductor 包 | Dockerfile 加 xcms/MSnbase/CAMERA/rhdf5 |

## Success Criteria
- [x] `docker compose up` 启动 10 个服务（9+ healthy）
- [x] API 全流程 create→upload→start→completed
- [ ] xcms-worker 处理真实 mzML 返回 features > 0 ← PENDING
- [ ] stats-worker 返回 significant features > 0 ← PENDING
