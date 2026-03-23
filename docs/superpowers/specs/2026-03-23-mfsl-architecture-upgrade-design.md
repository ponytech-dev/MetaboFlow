# MFSL 数据库架构升级设计

> 确认日期：2026-03-23
> 状态：已确认（5 段设计全部通过用户审批）

## 背景与动机

### 现有架构问题

1. **标签断层**：7 维标签只存在于 registry.csv（库文件级别，50 行），化合物级别（96 万条）完全没有标签。用户选"只搜 PFAS"时无法精确到化合物。
2. **Level 3 命名误导**：`level3_compounds.csv` 名字暗示它只用于 Level 3 匹配，但实际上所有 Level 匹配后都需要查询化合物属性。
3. **质谱库谱图缺 InChIKey**：8.3%（55,636 条）谱图无 InChIKey，无法关联到化合物元数据。
4. **环境非靶向标签缺失**：无法按 PFAS/农药/监管清单等维度过滤搜索。

### 升级目标

- 建立统一化合物元数据表，用 InChIKey 关联所有 Level
- 每个化合物拥有完整标签（化合物级 4 维 + 谱图级 3 维）
- 支持环境非靶向筛查的标签过滤
- 补全质谱库谱图的 InChIKey 覆盖率

---

## 1. 双库架构

MFSL 由两个核心库组成，通过 InChIKey 关联：

```
┌─────────────────────────────────┐     InChIKey      ┌──────────────────────────────────┐
│        质谱库 (Spectral DB)      │ ◄──────────────► │     化合物元数据库 (Compound DB)    │
│                                 │                   │                                  │
│  存储：deduplicated/*.msp       │                   │  存储：compound_metadata.csv      │
│  内容：57.9 万条 MS2 谱图        │                   │  内容：96.1 万条化合物             │
│  每条：InChIKey + peaks +        │                   │  每条：InChIKey + 基础属性 +       │
│        PrecursorMZ + metadata   │                   │        4 维标签 + 交叉引用         │
│  用途：Level 2 MS2 谱图匹配      │                   │  用途：Level 3 MS1 匹配 +          │
│                                 │                   │        所有 Level 的属性查询       │
│  谱图级标签（3 维）：             │                   │                                  │
│    confidence (experimental/    │                   │  化合物级标签（4 维）：              │
│               predicted)        │                   │    chemical_class                 │
│    instrument (orbitrap/qtof..) │                   │    application                    │
│    polarity (pos/neg)           │                   │    sample                         │
│                                 │                   │    reg_lists                      │
└─────────────────────────────────┘                   └──────────────────────────────────┘

registry.csv = 来源管理清单（记录 MSP 文件的下载来源和构建信息，不参与数据处理）
```

### 核心原则

- 质谱库存谱图数据（peaks），化合物库存化合物属性（标签/结构/交叉引用）
- 两库通过 InChIKey 关联——Level 2 匹配命中后查化合物库拿标签，Level 3 直接在化合物库搜
- confidence/instrument/polarity 是谱图属性（同一化合物可有不同仪器的谱图），留在质谱库
- chemical_class/application/sample/reg_lists 是化合物属性，放在化合物库
- Level 1（用户自建标准品库）和 Level 4（算法推算分子式）不需要额外库

### 标签维度分配

| 维度 | 化合物级 | 谱图级 | 说明 |
|------|---------|--------|------|
| chemical_class | ✅ | — | 化学结构类别 |
| application | ✅ | — | 应用场景 |
| sample | ✅ | — | 样本基质/来源 |
| reg_lists | ✅ | — | 监管清单成员 |
| confidence | — | ✅ | 谱图可信度 |
| instrument | — | ✅ | 采集仪器 |
| polarity | — | ✅ | 离子模式 |

---

## 2. compound_metadata.csv 字段定义

由 `level3_compounds.csv` 升级而来：

### 基础属性

| 字段 | 类型 | 说明 |
|------|------|------|
| `inchikey` | string | 主键，27 字符 |
| `name` | string | 化合物名称（缺失时填 InChIKey 前 14 位） |
| `formula` | string | 分子式 |
| `exact_mass` | float | 单同位素精确质量（缺失时从 SMILES 用 RDKit 计算） |
| `smiles` | string | SMILES 结构式（98.9% 覆盖率） |

### 化合物级标签（4 维）

| 字段 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| `chemical_class` | string | 化学结构类别（对齐 NPClassifier） | metabolite, lipid, pfas, pesticide, alkaloid, terpenoid, amino_acid_peptide, carbohydrate, steroid, glycan, organophosphate, organohalogen, unknown |
| `application` | string | 应用/监管场景 | pharmaceutical, environmental_monitoring, food_safety, forensic, toxicology, agrochemical, general |
| `sample` | string | 样本基质/生物来源 | human, plant, microbial, marine, water, soil, air, blood, urine, food, synthetic, unknown |
| `reg_lists` | string | 监管清单成员（多值分号分隔） | eu_watch_list; stockholm_pops; epa_pfas_master; epa_ccl5; cal_prop65 |

### 交叉引用

| 字段 | 类型 | 说明 |
|------|------|------|
| `kegg_id` | string | KEGG Compound ID |
| `hmdb_id` | string | HMDB ID |
| `chebi_id` | string | ChEBI ID |
| `lipidmaps_id` | string | LipidMaps ID |
| `cas_number` | string | CAS 登记号 |

### 来源追溯

| 字段 | 类型 | 说明 |
|------|------|------|
| `sources` | string | 数据库来源（HMDB;COCONUT;MassBank 等） |

### 标签规则

- 允许空值——不是每个化合物都有所有标签
- 允许多值——`application=pharmaceutical;environmental_monitoring`
- 不填默认值——空值表示"未知"

---

## 3. 标签填充策略

### Phase 1（立即，零成本）

| 标签 | 方法 | 来源 |
|------|------|------|
| `application` | 从 sources 字段规则推导 | NORMAN→environmental_monitoring, T3DB→toxicology, FooDB→food_safety, ChEBI→pharmaceutical 等 |
| `chemical_class` | 从 sources 推导基础分类 | HMDB→metabolite, LipidMaps→lipid, COCONUT→natural_product, TSCA→industrial_chemical |

### Phase 2（1-2 天）

| 标签 | 方法 | 来源 |
|------|------|------|
| `reg_lists` | 下载 NORMAN SusDat S0（Zenodo, 124MB, CC BY 4.0），用 InChIKey 匹配 130+ 个 S 标签列表 | NORMAN SusDat |
| `chemical_class` 细化 | 从 SusDat 的列表分类推导 PFAS/pesticide 等细分类别 | NORMAN SusDat |
| `sample` | HMDB biofluid_locations 回填 human 子类（blood/urine/csf） | HMDB XML |

### Phase 3（3-5 天）

| 标签 | 方法 | 来源 |
|------|------|------|
| `chemical_class` 精确 | ClassyFire/NPClassifier API 从 SMILES 批量计算 | ClassyFire API（~90% 覆盖率） |

---

## 4. 数据处理流程变更

### 用户搜索流程

```
用户选标签: chemical_class=pfas, sample=water

Step 1: compound_metadata.csv 过滤
  → 筛出符合标签的 InChIKey 集合

Step 2: Level 2 匹配（MS2）
  → annot-worker 只对 InChIKey 集合内的谱图做余弦匹配
  → 无 InChIKey 的谱图默认包含（兜底策略）
  → 命中后从 compound_metadata 拿完整标签写入结果

Step 3: Level 2 未命中 → Level 3 匹配（MS1）
  → 只在 InChIKey 集合内的化合物做精确质量匹配

Step 4: Level 3 未命中 → Level 4（SIRIUS 分子式推算）

用户不选标签 → 不过滤，搜全库
```

### 代码变更

| 文件 | 变更 |
|------|------|
| `annot-worker/matchms_engine.py` | 加 `inchikey_filter` 可选参数 |
| `xcms-worker/R/annotation_ms1.R` | 加 InChIKey 白名单过滤 |
| 后端 `AnnotationParams` | `tag_filter` 字段对接新标签维度 |

---

## 5. 质谱库 InChIKey 补全

### 当前缺口

55,636 条谱图（8.3%）无 InChIKey。

### 补全方案

| 步骤 | 方法 | 数量 | 预估成功率 |
|------|------|------|-----------|
| Step 1 | SMILES → InChIKey（RDKit 本地计算） | 19,667 | ~99% |
| Step 2 | InChI → InChIKey（RDKit 本地计算） | 1,835 | ~100% |
| Step 3 | Name → InChIKey（PubChem API 查询） | 33,953 | ~60-80% |

补全后写回 MSP 文件的 `InChIKey:` 字段。

### 兜底策略

补不上 InChIKey 的谱图：
- 用户选标签过滤时，**默认包含**（宁可多搜不漏掉）
- 匹配结果标注 `tag_verified: false`
- 用户可在高级设置选择"严格模式"排除无 InChIKey 谱图

### 新增脚本

`scripts/backfill_inchikey_spectra.py` — 三步补全 + 报告未补上的条数

---

## 6. 文件变更清单与向后兼容

### 文件变更

| 变更 | 说明 |
|------|------|
| `level3_compounds.csv` → `compound_metadata.csv` | 改名 + 加 4 列标签字段 |
| `registry.csv` | 不变，继续作为来源管理清单 |
| `deduplicated/*.msp` | InChIKey 补全后原地更新 |
| `DATABASE_MANUAL.md` | 更新：双库架构、标签维度、升级原因和过程 |
| `scripts/rebuild_level3.py` → `scripts/rebuild_compound_metadata.py` | 改名，输出 compound_metadata.csv |
| `scripts/fill_tags.py` | 新建，标签填充逻辑（Phase 1/2/3） |
| `scripts/backfill_inchikey_spectra.py` | 新建，质谱库 InChIKey 补全 |

### 向后兼容

- 软链接：`ln -s compound_metadata.csv level3_compounds/combined/level3_compounds.csv`
- annot-worker 找不到 compound_metadata.csv 时自动回退到 level3_compounds.csv
- 新增标签列在旧代码中被 CSV 读取自动忽略

### 数据清洗（同步执行）

| 操作 | 数量 |
|------|------|
| RDKit 从 SMILES 计算缺失 exact_mass | 28,210 条 |
| 空名字填 InChIKey 前 14 位 | 357,728 条 |
| 删除无 mass + 无 SMILES + 无 name | 585 条 |

---

## 7. 设计决策记录

| 决策 | 理由 |
|------|------|
| origin 改名为 sample | 统一覆盖生物来源（human/plant）和环境介质（water/soil），避免两套维度 |
| reg_lists 不合并到 source | source 是"数据来自哪个数据库"，reg_lists 是"在哪些监管清单上"，不同问题 |
| 标签允许空值不填默认值 | 不准确的标签比空值更有害 |
| 无 InChIKey 谱图默认包含搜索 | 宁可多搜不漏掉，排除需要用户主动选择严格模式 |
| compound_metadata 而非 compound_database | 强调这是属性表不是独立数据库，避免与"Level 3 数据库"概念混淆 |
| confidence/instrument/polarity 留在谱图级 | 同一化合物可有不同仪器/可信度的谱图，这三维是谱图属性不是化合物属性 |
