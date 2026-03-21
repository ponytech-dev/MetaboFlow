# Task: Phase 0 收尾 + Phase 1 核心打通
Created: 2026-03-21

## Objective
完成 Phase 0 剩余工作 + Phase 1 核心数据通路打通，使系统能端到端运行（前端→后端→引擎→结果展示）。

## Phases

### Phase 0 收尾（今天完成）

- [ ] Step 1: Git commit + push 所有未提交代码
  产出：6 个文件提交，无未跟踪文件
  验证：`git status` 干净

- [ ] Step 2: MetaboData HDF5 序列化实现
  产出：metabodata/io.py 新增 `to_hdf5()` / `from_hdf5()` 方法
  验证：`pytest packages/common/metabodata/tests/test_io.py` 通过

- [ ] Step 3: Docker 镜像重建（含 CAMERA）
  产出：metaboflow/qexactive:e2e 镜像构建成功
  验证：`docker images metaboflow/qexactive` 存在

- [ ] Step 4: E2E 管线 Docker 测试
  产出：4 样本全流程通过（含 Step 1b 去冗余）
  验证：results/ 含 01-07 全部文件

- [ ] Step 5: CHECKSUMS.sha256 更新
  产出：~/spectral_libraries/CHECKSUMS.sha256
  验证：`shasum -c` 通过

### Phase 1 数据通路打通（本周目标）

- [ ] Step 6: MetaboData R↔Python 序列化桥
  产出：R 端 `write_metabodata_hdf5()` / `read_metabodata_hdf5()` 函数
  验证：R 写 → Python 读 → 数据一致

- [ ] Step 7: xcms-worker 输出 MetaboData 格式
  产出：Plumber API 返回 MetaboData JSON/HDF5
  验证：Python 端调用 xcms API → 得到 MetaboData 对象

- [ ] Step 8: stats-worker 接收 MetaboData 格式
  产出：Plumber API 接收 MetaboData → 返回差异分析结果
  验证：Python 调用链 xcms → MetaboData → stats

- [ ] Step 9: annot-worker 对接去重谱库
  产出：matchms 从 deduplicated/ 加载谱库
  验证：返回带 Sources 的匹配结果

- [ ] Step 10: 后端 analysis_service 串联完整流程
  产出：`POST /api/analysis` → xcms → stats → annot → 结果
  验证：curl 调用 API → 返回完整分析结果

- [ ] Step 11: 前端对接后端 API
  产出：Wizard 提交 → 调后端 → 显示进度 → 展示结果
  验证：浏览器操作完成一次分析

## Success Criteria
- `docker-compose up` 启动全栈
- 前端上传 mzML → 后端编排 → xcms 峰检测 → stats 差异分析 → annot 注释 → 前端展示结果
- 数据通过 MetaboData 格式在引擎间传递（不是 R 变量直传）
