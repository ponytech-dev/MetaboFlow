# MFSL 数据库架构设计 v2.0

> 确认日期：2026-03-24
> 状态：待确认
> 替代：2026-03-23-mfsl-architecture-upgrade-design.md（v1，已过时）

---

## 1. 总体架构

MFSL（MetaboFlow Spectral Library）是一个独立的数据资产，由两个核心库组成。两个库各自拥有完整的 8 维标签体系，通过 InChIKey 关联但不互相依赖。

### 1.1 三层结构

```
Layer 1: 数据层
  ├── deduplicated/*.msp           质谱库：60 万条 MS2 谱图峰数据（标签内嵌）
  └── compound_metadata.csv        化合物库：96 万条化合物属性（= Level 3 数据）

Layer 2: 索引层
  └── spectral_metadata.csv        质谱库的只读快速索引（从 MSP 自动生成）

Layer 3: 文档层
  └── DATABASE_MANUAL.md           来源清单 + 构建方法 + 架构说明
```

### 1.2 双库关系

```
质谱库 (Level 2)                          化合物库 (Level 3)
deduplicated/*.msp                        compound_metadata.csv
  60 万条谱图                                96 万条化合物
  每条内嵌 8 维标签                           每条有 8 维标签
  数据：peaks（碎裂谱图）                     数据：exact_mass（精确质量）
  用途：MS2 谱图匹配                          用途：MS1 精确质量匹配
           │                                         │
           └──── InChIKey（前 14 位）────────────────┘
                    增值关联，非必须依赖
```

**核心原则：**
- 两个库各自独立——质谱库的标签不依赖化合物库查询，化合物库的标签不依赖质谱库
- InChIKey 关联是增值查询——有就补充更多信息，没有也不影响基础标签和搜索
- 标签内嵌 MSP 文件——行业标准做法（MassBank/GNPS/MoNA/FragHub 均如此）
- spectral_metadata.csv 是 MSP 的衍生物——从 MSP 文件自动生成，不是数据源

### 1.3 注释匹配流程

```
用户选标签过滤（如 chemical_class=pfas, application=environmental_monitoring）
  │
  ├─→ Level 2: 在 spectral_metadata.csv 按标签过滤
  │     → 拿到目标谱图 ID 列表
  │     → 只加载对应 MSP 条目做 MS2 余弦匹配
  │     → 命中的 feature 标注 msi_level=2
  │
  ├─→ Level 2.5: SIRIUS/CSI:FingerID（Level 2 未命中的 features）
  │     → 结构预测，msi_level=3
  │
  ├─→ Level 3: 在 compound_metadata.csv 按标签过滤
  │     → 只对 Level 2 未命中的 features 做精确质量匹配
  │     → 命中的标注 msi_level=3
  │
  └─→ Level 4: 分子式推算（纯算法，无需库）
        → 仍未注释的标注 msi_level=4

用户不选标签 → 不过滤，搜全库
```

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

### 3.3 spectral_metadata.csv（只读索引，从 MSP 生成）

| 字段 | 说明 |
|------|------|
| spectrum_id | 唯一标识 |
| inchikey | InChIKey（关联化合物库） |
| name | 化合物名称 |
| precursor_mz | 前体离子质量 |
| precursor_type | 加合离子类型 |
| formula | 分子式 |
| collision_energy | 碰撞能量 |
| file_source | MSP 文件名 |
| num_peaks | 峰数量 |
| quality_score | 质量评分 |
| chemical_class | 化学类别 |
| application | 应用场景 |
| sample | 样本基质 |
| confidence | 可信度 |
| instrument | 仪器类型 |
| polarity | 离子模式 |
| reg_lists | 监管清单 |
| sources | 数据库来源 |

**生成方式**：`scripts/build_spectral_metadata.py` 解析所有 MSP 文件，提取 header 字段 + Tags 行，写入 CSV。任何时候可以从 MSP 文件重新生成。

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
| 标签过滤 | annot-worker 读 spectral_metadata → 过滤 ID → 加载 MSP | spectral_search.py 读 Tags 字段 |
| 自有扩展 | 无 | eCPIN CFM-ID 预测库 |

MFSL 的架构与搜索引擎无关——它只负责存储、索引、标签，不绑定匹配算法。

---

## 7. 物理文件结构

```
~/spectral_libraries/
├── DATABASE_MANUAL.md              # 文档（含来源清单，原 registry.csv 内容并入）
├── spectral_metadata.csv           # 谱图索引（只读，从 MSP 生成）
├── compound_metadata.csv           # 化合物元数据（= Level 3 数据）
├── deduplicated/                   # MSP 峰数据（标签内嵌）
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
| spectral_metadata.csv 是衍生物 | 从 MSP 自动生成，用于快速统计和前端展示，不是搜索必经环节 |
| 8 维标签全部适用所有化合物 | reg_lists 对非环境化合物为空值，但保留维度的统一性 |
| InChIKey 前 14 位跨库匹配 | 前 14 位是分子骨架，立体异构体共享，跨库匹配率从 35% 提升到 65% |
| 标签只用可信来源填充 | 不猜、不推测——原始库字段、库级别确定性标注、ClassyFire API |
| 两个库各自独立标签 | 质谱库 65% 谱图的化合物不在化合物库里，依赖查询会导致大量标签缺失 |
| registry.csv 并入 DATABASE_MANUAL | spectral_metadata.csv 已覆盖其索引功能，registry 降为文档 |
| 去重保留来源追溯 | Sources 字段记录所有数据库来源，去重不丢信息 |
