# Task: MetaboFlow 质谱数据库 — 剩余任务清单
Created: 2026-03-20 22:00

## Objective
完成质谱数据库的所有剩余工程化、数据补充和产品化工作，确保 MFSL v2.2 可交付使用。

## Current State
- MFSL v2.2: 52 库, 3.09M 原始谱图, 669K 去重, 961K L3 化合物
- 16/16 库源文件交叉验证 PASS
- DATABASE_MANUAL.md v2.2 (14 章) 已对齐
- 代码改动未 commit

## Phases

### Phase 1: 工程化收尾（高优先级）

- [ ] Step 1: Git commit + push MetaboFlow 代码
  产出：所有新增/修改文件提交到 GitHub
  验证：`git status` 无未提交文件，`git log --oneline -1` 显示新 commit

- [ ] Step 2: 重新生成 CHECKSUMS.sha256
  产出：~/spectral_libraries/CHECKSUMS.sha256 更新
  验证：`shasum -c CHECKSUMS.sha256` 全部 OK

- [ ] Step 3: 重建 Docker 镜像（含 CAMERA）
  产出：metaboflow/qexactive:e2e 镜像构建成功
  验证：`docker images metaboflow/qexactive` 显示新镜像

- [ ] Step 4: E2E 管线完整测试（4 样本 MTBLS733）
  产出：results/ 中包含 01-07 全部输出文件 + Fig1-4
  验证：`ls results_qe_v3/` 显示所有预期文件，exit code 0

- [ ] Step 5: annot-worker 对接去重库
  产出：matchms 引擎使用 deduplicated/ 谱库而非 converted/
  验证：annot-worker 返回带 Sources 字段的匹配结果

### Phase 2: 数据补充（中优先级）

- [ ] Step 6: ChEBI 201K 条补 InChIKey（通过 ChEBI REST API）
  产出：level3_compounds.csv 中 ChEBI 来源的 InChIKey 覆盖率提升
  验证：`python3 -c "..."` 显示 ChEBI InChIKey 覆盖率

- [ ] Step 7: KEGG 19K 条补 InChIKey（通过 KEGG REST + PubChem）
  产出：KEGG 来源的 InChIKey 覆盖率提升
  验证：同上

- [ ] Step 8: DrugBank 注册+下载+集成
  产出：DrugBank 化合物加入 Level 3
  验证：rebuild_level3.py 包含 load_drugbank()

- [ ] Step 9: 化合物分类标注（ClassyFire）
  产出：Level 3 CSV 新增 compound_class 列
  验证：抽检 10 个化合物的分类是否正确

- [ ] Step 10: 物种来源标注整合
  产出：NPAtlas organism 信息整合到 Level 3
  验证：grep "organism" level3_compounds.csv

### Phase 3: 产品化（低优先级）

- [ ] Step 11: Registry SQLite 重建
  产出：registry.db 与 registry.csv 同步
  验证：`sqlite3 registry.db "SELECT count(*) FROM libraries"` = 52

- [ ] Step 12: 前端库筛选器 UI 设计
  产出：设计文档或 Figma 原型
  验证：N/A（设计阶段）

- [ ] Step 13: 用户自建库工具（组合化学建库脚本）
  产出：scripts/build_custom_library.py
  验证：用测试数据运行产出 MSP 文件

- [ ] Step 14: SIRIUS 账号注册
  产出：SIRIUS_USER/SIRIUS_PASSWORD 环境变量配置
  验证：sirius-worker 容器启动不报认证错误

## Constraints
- spectral_libraries/ 目录不在 git 中（~4.5GB，太大）
- Docker 镜像构建需要 30-60 分钟（Bioconductor 编译）
- PubChem API 限速 5 req/s
- NIST 23 购买决策待定（$550）

## Success Criteria
- Phase 1 完成后：E2E 管线在 Docker 中端到端通过（10 步全覆盖）
- Phase 2 完成后：L3 InChIKey 覆盖率从 82.7% 提升到 90%+
- Phase 3 完成后：产品可交付用户使用
