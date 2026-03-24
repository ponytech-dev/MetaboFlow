# MFSL 数据库架构设计 v2.0

> 确认日期：2026-03-24
> 最后更新：2026-03-24（注释流程修正 + MetaboFlow 对口 + 最终数据统计）
> 状态：待确认
> 替代：2026-03-23-mfsl-architecture-upgrade-design.md（v1，已过时）

---

## 1. 总体架构

MFSL（MetaboFlow Spectral Library）是一个独立的数据资产，由两个核心库组成，服务于分层注释流程中的不同环节。

### 1.1 双库结构

```
质谱库 (Level 2 数据)                     化合物库 (Level 3 数据)
deduplicated/*.msp                        compound_metadata.csv
  60 万条 MS2 谱图                          127 万条化合物
  每条内嵌 8 维标签                          每条有 8 维标签
  数据内容：碎裂峰（mz + intensity）         数据内容：精确质量 + SMILES + 交叉引用
  用途：Level 2 MS2 谱图匹配                用途：Level 3 MS1 匹配 + 元数据富集

  另附：DATABASE_MANUAL.md               （来源清单 + 构建方法 + 架构说明）
```

**两个库各自独立，各自拥有完整的 8 维标签。** 搜索时各自按标签过滤，不依赖对方。

### 1.2 元数据富集：两个库如何协同

质谱库和化合物库在注释流程中各司其职，但在**结果输出阶段**需要协同——Level 2 谱图匹配命中后，仅凭 MSP 文件里的信息（compound_name + InChIKey + score）不足以支撑下游通路分析（缺 KEGG ID）和结果报告（缺化学分类细节）。这是行业共同痛点：MetaboAnalystR 4.0 用本地 SQLite 解决，XCMS Online 依托 METLIN，多数工具需要用户手动做 ID 转换。

**MetaboFlow 的方案：compound_metadata.csv 承担元数据富集角色。** 具体关联机制：

1. **主关联键：InChIKey**（完整 27 位优先，前 14 位退化匹配）
   - 覆盖率：MSP 谱图中 95.8% 有 InChIKey
   - compound_metadata 已包含所有谱图化合物（100% 前 14 位匹配）

2. **补充关联键**（用于 InChIKey 缺失的 25,274 条谱图）
   - HMDB ID：50% 的无 InChIKey 谱图有 HMDB ID（12,651 条），compound_metadata 有 hmdb_id 字段
   - CAS 号：29% 有 CAS（7,206 条），compound_metadata 有 cas_number 字段
   - 关联优先级：InChIKey 27 位 → InChIKey 14 位 → HMDB ID → CAS 号

3. **富集内容**：从 compound_metadata 获取的信息
   - KEGG ID → 支撑通路富集分析（ORA/GSEA）
   - HMDB ID → 支撑 MetaboAnalyst 兼容
   - 详细化学分类（chemical_class、application、sample）→ 结果报告和图表
   - SMILES → 结构展示
   - reg_lists → 环境筛查报告

4. **富集不是搜索的前置条件**——搜索阶段（Level 2/3）各自独立完成，富集在搜索完成后执行。搜索性能不受富集步骤影响。

### 1.3 标签与 MSP 原有字段的共存

MSP 文件中原有的字段（Ion_mode、Instrument_type、Spectrum_type 等）与八维标签存在部分重复：

| MSP 原有字段 | 八维标签 | 处理方式 |
|------------|---------|---------|
| `Ion_mode: POSITIVE` | `Polarity: positive` | 原有字段保留（向后兼容），标签字段为规范化值，搜索用标签字段 |
| `Instrument_type: LC-ESI-ITFT` | `Instrument: orbitrap` | 原有字段保留原始值，标签字段为归一化类别 |
| `Spectrum_type: Predicted` | `Confidence: predicted` | 同上 |
| `Sources: massbank.msp; hmdb.msp` | （source 维度从 Sources 字段提取） | 不新增字段，直接读 Sources |
| `Collision_energy: 20` | 无对应标签 | 不是过滤维度，不纳入标签 |
| `Quality_score: 95` | 无对应标签 | 同上 |

**原则：原有字段保留不删，八维标签新增写入。matchms 解析后两组字段各自独立存在于 metadata 字典中，不冲突。annot-worker 过滤时统一使用八维标签字段名。**

### 1.3 注释匹配流程（matchms 真实工作逻辑）

```
Step 1: annot-worker 启动时加载 MSP 文件
  → refs = matchms.load_from_msp("deduplicated/*.msp")
  → 60 万条 Spectrum 对象全部加载到内存
  → 每条的 metadata 包含内嵌的 8 维标签字段
  → MetaboFlow 对口：annot-worker/app/matchms_engine.py

Step 2: 用户选标签过滤（可选）
  → filtered = [r for r in refs if r.metadata.get("chemical_class") == "pfas"]
  → Python 层面的内存过滤，不涉及文件 IO
  → 不选标签则 filtered = refs（全库）
  → MetaboFlow 对口：AnnotationParams.tag_filter

Step 3: Level 2 — MS2 谱图匹配
  → 对每个 query spectrum（来自用户 mzML 的 MS2 数据）
  → matchms.CosineGreedy.pair(query, ref) 逐一计算余弦相似度
  → score >= 0.7 的标注为 Level 2 命中
  → 命中结果：InChIKey + compound_name + score（来自 MSP metadata）
  → MetaboFlow 对口：annotation_orchestrator.py Line 65-117

Step 4: 元数据富集（compound_metadata.csv）
  → Level 2 命中的化合物，用 InChIKey（前 14 位）查 compound_metadata
  → 补充：KEGG ID、HMDB ID、通路信息、详细化学分类
  → 这是行业痛点——多数工具需要用户手动做 ID 转换
  → MetaboFlow 自动完成，无需用户操作
  → MetaboFlow 对口：annotation_orchestrator.py Step 5（待实现）

Step 5: Level 2.5 — SIRIUS 结构预测（可选）
  → 对 Level 2 未命中且有 MS2 数据的 features
  → SIRIUS/CSI:FingerID 计算预测
  → MetaboFlow 对口：annotation_orchestrator.py Line 123-171

Step 6: Level 3 — MS1 精确质量匹配
  → 对仍未注释的 features
  → 在 compound_metadata.csv 中按 exact_mass ± ppm 匹配
  → 如果用户选了标签，compound_metadata 同样做标签过滤
  → 命中结果：compound_name + exact_mass + 化合物标签
  → MetaboFlow 对口：annotation_orchestrator.py Line 173-191

Step 7: Level 4 — 分子式推算
  → 仍未注释的 features，纯算法推算可能的分子式
  → 无需外部库
  → MetaboFlow 对口：annotation_orchestrator.py Line 193-203
```

**关键说明：**
- matchms 直接加载 MSP 文件，不需要中间索引文件
- 元数据富集（Step 4）使用完整 27 位 InChIKey 优先匹配，匹配不到退化为前 14 位，再匹配不到用 HMDB ID / CAS 号补充关联
- Level 2 和 Level 3 是完全独立的代码路径，只共享标签过滤逻辑
- compound_metadata.csv 承担两个角色：Level 3 数据源 + 元数据富集来源

---

## 2. 八维标签体系

### 2.1 标签定义

| # | 维度 | 回答的问题 | 适用范围 | 存储位置 |
|---|------|-----------|---------|---------|
| 1 | `chemical_class` | 化学结构属于什么类？ | 所有 | MSP + compound_metadata |
| 2 | `application` | 在什么领域被关注？ | 所有 | MSP + compound_metadata |
| 3 | `sample` | 样本基质/生物来源？ | 所有 | MSP + compound_metadata |
| 4 | `source` | 数据来自哪些数据库？ | 所有 | MSP（Sources 字段）+ compound_metadata（sources 字段） |
| 5 | `confidence` | 谱图可信度？ | 谱图级 | MSP |
| 6 | `instrument` | 什么仪器采集的？ | 谱图级 | MSP |
| 7 | `polarity` | 离子模式？ | 谱图级 | MSP |
| 8 | `reg_lists` | 属于哪些监管清单？ | 所有 | MSP + compound_metadata |

### 2.2 标签值域

**chemical_class**（对齐 ClassyFire/NPClassifier）：
metabolite, lipid, fatty_acid, terpenoid, alkaloid, amino_acid_peptide, carbohydrate, steroid, nucleoside, glycan, polyketide, shikimate_phenylpropanoid, organophosphate, organohalogen, pfas, pesticide, natural_product, unknown

**application**：
pharmaceutical, environmental_monitoring, food_safety, forensic, toxicology, agrochemical, general

**sample**：
human, plant, microbial, marine, animal, water, soil, air, blood, urine, food, synthetic, natural, unknown

**source**：
massbank, gnps, hmdb, isdb, norman, msnlib, msdial, nist, respect, foodb, embl-mcf（多值分号分隔）

**confidence**：
experimental, predicted, mixed

**instrument**：
orbitrap, qtof, qqq, ion_trap, tof, ei, dart, predicted, mixed

**polarity**：
positive, negative

**reg_lists**：
norman_susdat, eu_watch_list, stockholm_pops, epa_pfas_master, epa_ccl5, cal_prop65, edc_list, pmt_list, sin_list, pesticide_list, pharmaceutical_list, drinking_water_contaminant, food_contact（多值分号分隔）

### 2.3 标签规则

- **有就标，没有就空。不猜、不推测、不用低可信度方法补。**
- 允许多值——`application=pharmaceutical;environmental_monitoring`
- 允许空值——空表示"未知"，比不准确的标签更好
- 标签来源必须可追溯——每个标签的填充方法在本文档 §4 中记录

---

## 3. 文件格式

### 3.1 MSP 谱图文件（标签内嵌）

```
Name: Caffeine
PrecursorMZ: 195.0877
Precursor_type: [M+H]+
Ion_mode: POSITIVE
Collision_energy: 20
Formula: C8H10N4O2
InChIKey: RYYVLZVUVIJVGH-UHFFFAOYSA-N
SMILES: CN1C=NC2=C1C(=O)N(C(=O)N2C)C
Instrument_type: Orbitrap
Chemical_class: alkaloid
Application: pharmaceutical
Sample: human
Confidence: experimental
Reg_lists: eu_watch_list
Sources: massbank_orbitrap_positive.msp; hmdb_predicted_positive.msp
Source_count: 2
Quality_score: 100
Num Peaks: 15
53.0386 1234
...
```

每个标签维度独立一行。没有值的维度不写（不写空值行）。
matchms 原生兼容——每行自动解析为 `spectrum.metadata['chemical_class']` 等独立字段，零适配成本。
经实测验证：matchms `load_from_msp()` 直接识别自定义字段名，空行自动跳过。

### 3.2 compound_metadata.csv

| 字段 | 说明 |
|------|------|
| inchikey | 主键 |
| name | 化合物名称 |
| formula | 分子式 |
| exact_mass | 精确质量（Level 3 匹配数据） |
| smiles | SMILES 结构式 |
| chemical_class | 化学类别 |
| application | 应用场景 |
| sample | 样本基质 |
| reg_lists | 监管清单 |
| sources | 数据库来源 |
| kegg_id | KEGG ID |
| hmdb_id | HMDB ID |
| chebi_id | ChEBI ID |
| lipidmaps_id | LipidMaps ID |
| cas_number | CAS 号 |

*（spectral_metadata.csv 已废弃——其内容被 MSP 内嵌标签 + compound_metadata 完全覆盖，不参与数据处理流程）*

---

## 4. 标签填充策略

### 4.1 只使用可信来源

标签填充遵循"有就标，没有就空"原则。以下是每个标签维度的可信填充方法：

### 4.2 四层填充（按优先级）

**Layer 1：库级别确定性标注（零成本，100% 可信）**

整个库的定位决定了部分标签，无需逐条判断：

| 来源 | 确定性标签 |
|------|-----------|
| NORMAN 全部 | application=environmental_monitoring; confidence=predicted |
| ISDB 全部 | chemical_class=natural_product; confidence=predicted |
| HMDB experimental | confidence=experimental |
| HMDB predicted | confidence=predicted |
| MSnLib MCE Drug | application=pharmaceutical; confidence=experimental |
| MSnLib NIH NP | chemical_class=natural_product; confidence=experimental |
| MSnLib Otava Pep | chemical_class=amino_acid_peptide; confidence=experimental |
| FooDB | application=food_safety; sample=food; confidence=experimental |
| ReSpect | sample=plant; confidence=experimental |
| NIST EPA | application=environmental_monitoring; confidence=experimental |
| NIST Glycan | chemical_class=glycan; confidence=experimental |
| NIST DART | confidence=experimental |

**Layer 2：MSP 文件已有字段（直接读取，100% 可信）**

| MSP 字段 | 映射到标签 | 覆盖来源 |
|---------|-----------|---------|
| Ion_mode | polarity | 全部（100%） |
| Sources | source | 全部（100%） |
| Instrument_type | instrument | MassBank, HMDB, MS-DIAL, MSnLib, FooDB, ReSpect |
| ONTOLOGY（MS-DIAL） | chemical_class | MS-DIAL（93%） |

**Layer 3：从原始库重新提取（需额外下载/处理，100% 可信）**

| 来源 | 可提取标签 | 方法 |
|------|-----------|------|
| HMDB metabolites XML | chemical_class（ClassyFire 四级）, sample（biofluid/tissue） | 下载 hmdb_metabolites.xml，InChIKey 关联 |
| MassBank 原始记录 | chemical_class（CH$COMPOUND_CLASS + ChemOnt） | 下载 2025 版原始记录，重新提取 |
| ReSpect SQL dump | chemical_class（化合物类）, sample（植物种属） | 从原始数据重新提取 |
| LipidMaps CSV | chemical_class（三级脂质分类） | 本地 CSV 已有，InChIKey 关联 |
| NORMAN SusDat | reg_lists（130+ S-list 映射） | 已完成 |

**Layer 4：ClassyFire/NPClassifier API 计算（确定性算法，可信）**

对有 SMILES 但仍缺 chemical_class 的谱图/化合物：
- ClassyFire API：`http://classyfire.wishartlab.com/entities/{InChIKey}.json`
- NPClassifier API：`https://npclassifier.gnps2.org/classify?smiles={SMILES}`
- 两者都是基于化学结构规则的确定性分类，不是统计预测

### 4.3 不使用的方法

- ❌ PubChem Name 模糊查询（命中率低，结果不可靠）
- ❌ 从一个库的标签"推测"另一个库的标签
- ❌ 任何统计/机器学习预测方法

---

## 5. 去重机制

### 5.1 去重键

`InChIKey前14位 + Precursor_type`

前 14 位代表分子骨架（connectivity layer），忽略立体化学。同一化合物的不同立体异构体共享去重键。

### 5.2 去重流程

1. 所有来源的谱图按去重键分组
2. 同组内按 Quality_score（8 维评分，0-100）+ 峰数排序
3. 保留质量最高的一条谱图的 peaks 数据
4. 被丢弃谱图的元数据合并到保留谱图：
   - `Sources`：记录所有来源文件名
   - `Source_count`：来源数量
   - `Synonyms`：补充化合物别名
   - 缺失的 formula/collision_energy 从被丢弃谱图补充

### 5.3 无 InChIKey 的谱图

不参与去重，全部保留。标注完整的谱图级标签（confidence/instrument/polarity），化合物级标签留空。

---

## 6. 跨产品使用

MFSL 是独立数据资产，MetaboFlow 和 PonylabASMS 各自复制一份使用。

| | MetaboFlow | PonylabASMS |
|---|---|---|
| 搜索引擎 | matchms (cosine) | Flash Entropy Search |
| 复制内容 | deduplicated/*.msp + compound_metadata.csv | 同左 |
| 标签过滤 | annot-worker 加载 MSP → 按 metadata 字段过滤 → 余弦匹配 | spectral_search.py 读 metadata 字段过滤 |
| 自有扩展 | 无 | eCPIN CFM-ID 预测库 |

MFSL 的架构与搜索引擎无关——它只负责存储、索引、标签，不绑定匹配算法。

---

## 7. 物理文件结构

```
~/spectral_libraries/
├── DATABASE_MANUAL.md              # 文档（含来源清单、构建方法、架构说明）
├── compound_metadata.csv           # 化合物元数据（= Level 3 数据 + 元数据富集来源）
├── deduplicated/                   # MSP 峰数据（8 维标签内嵌）
│   ├── massbank_orbitrap_positive.msp
│   ├── norman_positive.msp
│   └── ... (50 个文件)
├── norman_susdat/                  # NORMAN SusDat 原始下载
├── scripts/                        # 构建/维护脚本
│   ├── rebuild_compound_metadata.py
│   ├── dedup_and_quality.py
│   ├── build_spectral_metadata.py
│   ├── fill_tags_msp.py            # 标签写入 MSP
│   ├── fill_norman_tags.py
│   └── backfill_smiles_pubchem.py
└── raw/                            # 原始下载文件（存档）
```

---

## 8. 设计决策记录

| 决策 | 理由 |
|------|------|
| 标签内嵌 MSP 而非仅存 CSV | 行业标准（MassBank/GNPS/MoNA/FragHub），自包含，不会 MSP/CSV 不同步 |
| 删除 spectral_metadata.csv | 内容已被 MSP 内嵌标签 + compound_metadata 完全覆盖，不参与数据处理流程 |
| 8 维标签全部适用所有化合物 | reg_lists 对非环境化合物为空值，但保留维度的统一性 |
| InChIKey 前 14 位跨库匹配 | 前 14 位是分子骨架，立体异构体共享，跨库匹配率从 35% 提升到 65% |
| 标签只用可信来源填充 | 不猜、不推测——原始库字段、库级别确定性标注、ClassyFire API |
| 两个库各自独立标签 | 质谱库搜索不依赖 compound_metadata，各自按内嵌标签过滤 |
| compound_metadata 覆盖所有谱图化合物 | 从 MSP 提取 13.6 万"谱图独有"化合物合并到 compound_metadata，实现 100% InChIKey 覆盖 |
| registry.csv 并入 DATABASE_MANUAL | spectral_metadata.csv 已覆盖其索引功能，registry 降为文档 |
| 去重保留来源追溯 | Sources 字段记录所有数据库来源，去重不丢信息 |
| MSP 标签用独立字段行（非 Tags 单行） | matchms 实测：独立字段行自动解析为 metadata 字典，零适配成本 |

---

## 9. 最终数据统计

### 9.1 质谱库（deduplicated/*.msp）

| 指标 | 数值 |
|------|------|
| 总谱图数 | 602,899 |
| MSP 文件数 | 50 |
| InChIKey 覆盖率 | 95.8%（577,625 条） |
| 无 InChIKey（保留） | 25,274 条（glycan/ReSpect/HMDB predicted/NIST EPA） |
| 质量评分范围 | 0-100（8 维加权） |

### 9.2 化合物元数据库（compound_metadata.csv）

| 字段 | 覆盖率 | 数量 |
|------|--------|------|
| **总量** | — | **1,269,678** |
| name | 100.0% | 1,269,678 |
| formula | 99.8% | 1,267,247 |
| exact_mass | 99.7% | 1,266,259 |
| smiles | 80.7% | 1,025,074 |
| chemical_class | 78.2%（NPClassifier 补充中，预计→84%） | 992,391 |
| application | 40.0% | 508,343 |
| sample | 73.8% | 937,190 |
| reg_lists | 6.8% | 85,774 |
| kegg_id | 2.1% | 27,007 |
| hmdb_id | 17.2% | 217,895 |

### 9.3 InChIKey 覆盖关系

| 指标 | 数值 |
|------|------|
| compound_metadata 唯一 InChIKey | 1,068,604 |
| MSP 谱图唯一 InChIKey | 483,861 |
| MSP → compound_metadata 匹配率（前 14 位） | **100%** |

---

## 10. 与 MetaboFlow 代码对口

### 10.1 关键文件映射

| MFSL 数据 | MetaboFlow 代码 | 说明 |
|-----------|-----------------|------|
| deduplicated/*.msp | `annot-worker/app/matchms_engine.py` | matchms 加载 MSP，按 metadata 标签过滤，计算余弦相似度 |
| compound_metadata.csv | `xcms-worker/R/annotation_ms1.R` | Level 3 精确质量匹配 |
| compound_metadata.csv | `annotation_orchestrator.py` Step 4 | 元数据富集（InChIKey → KEGG/HMDB/通路） |
| MSP 标签字段 | `AnnotationParams.tag_filter` | 前端标签过滤传给后端 |
| MSP 内嵌标签字段 | `annot-worker` 加载后按 `metadata` 字典过滤 | 搜索前的标签筛选 |

### 10.2 标签字段名对齐

MSP 文件中的字段名必须与 matchms 解析后的 metadata key 一致：

| MSP 字段行 | matchms metadata key | MetaboFlow 模型字段 |
|-----------|---------------------|-------------------|
| `Chemical_class: alkaloid` | `spectrum.metadata["chemical_class"]` | `TagFilter.compound_class`（需改名对齐） |
| `Application: pharmaceutical` | `spectrum.metadata["application"]` | `TagFilter.application`（新增） |
| `Sample: human` | `spectrum.metadata["sample"]` | `TagFilter.organism`（需改名对齐） |
| `Confidence: experimental` | `spectrum.metadata["confidence"]` | `TagFilter.confidence` |
| `Instrument: orbitrap` | `spectrum.metadata["instrument"]` | `TagFilter.instrument` |
| `Reg_lists: eu_watch_list` | `spectrum.metadata["reg_lists"]` | `TagFilter.reg_lists`（新增） |

**需要修改 MetaboFlow 的 `TagFilter` 模型**：将 `compound_class` 改为 `chemical_class`，`organism` 改为 `sample`，新增 `application` 和 `reg_lists`。

### 10.3 compound_metadata.csv 字段与 AnnotationHit 对齐

| compound_metadata 字段 | AnnotationHit 模型字段 | 说明 |
|----------------------|---------------------|------|
| name | compound_name | ✅ 已对齐 |
| inchikey | inchikey | ✅ 已对齐 |
| formula | formula | ✅ 已对齐 |
| smiles | （缺失，需新增） | 结构展示需要 |
| kegg_id | kegg_id | ✅ 已对齐 |
| hmdb_id | hmdb_id | ✅ 已对齐 |
| chemical_class | （缺失，需新增） | 结果标签展示 |
| application | （缺失，需新增） | 结果标签展示 |
