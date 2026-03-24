# MFSL 数据库架构 v2 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 MFSL 从旧架构（registry.csv + level3_compounds + 无标签 MSP）迁移到 v2 架构（8 维标签内嵌 MSP + compound_metadata + DATABASE_MANUAL 重构）。

**Architecture:** MSP 文件写入 8 维标签独立字段行（matchms 原生兼容）。compound_metadata.csv 作为 Level 3 数据源 + 元数据富集来源。MetaboFlow TagFilter 模型与新标签字段名对齐。DATABASE_MANUAL 重构为完整的架构说明书。

**Tech Stack:** Python 3.12 + RDKit + matchms, R (annotation_ms1.R), FastAPI (Pydantic models)

**Spec:** `docs/superpowers/specs/2026-03-24-mfsl-architecture-v2-design.md`

---

## File Structure

### 新建
- `~/spectral_libraries/scripts/fill_tags_msp.py` — 8 维标签写入 MSP 文件
- `~/spectral_libraries/scripts/verify_msp_tags.py` — 验证 MSP 标签完整性

### 修改
- `~/spectral_libraries/deduplicated/*.msp` — 50 个 MSP 文件写入标签
- `~/spectral_libraries/DATABASE_MANUAL.md` — 完全重构
- `packages/backend/app/models/analysis.py` — TagFilter 模型对齐
- `packages/engines/annot-worker/app/matchms_engine.py` — 标签过滤逻辑

### 删除
- `~/spectral_libraries/registry.csv` — 内容并入 DATABASE_MANUAL
- `~/spectral_libraries/registry.db` — SQLite 版本一并删除
- `~/spectral_libraries/spectral_metadata.csv` — 已废弃

---

## Task 1: 八维标签写入 MSP 文件

**Goal:** 为 60 万条谱图写入 Chemical_class / Application / Sample / Confidence / Instrument / Polarity / Reg_lists 标签字段行。Source 维度使用已有的 Sources 字段。

**Files:**
- Create: `~/spectral_libraries/scripts/fill_tags_msp.py`
- Modify: `~/spectral_libraries/deduplicated/*.msp` (50 files)

- [ ] **Step 1: 创建标签写入脚本**

`~/spectral_libraries/scripts/fill_tags_msp.py`：

核心逻辑：
1. 加载 compound_metadata.csv 构建 InChIKey → 标签映射（InChIKey 前 14 位）
2. 定义库级别确定性标签规则（Layer 1）
3. 逐个 MSP 文件处理：
   a. 解析每条谱图
   b. 确定标签值（优先级：MSP 已有字段 > compound_metadata 查询 > 库级别规则）
   c. 写入标签字段行（在 Num Peaks: 之前）
4. 不覆盖已有的原始字段（Ion_mode, Instrument_type 等保留）

**库级别标签规则（Layer 1）：**

```python
FILE_TAGS = {
    # NORMAN — 环境污染物预测谱
    "norman_negative.msp": {"application": "environmental_monitoring", "confidence": "predicted"},
    "norman_positive.msp": {"application": "environmental_monitoring", "confidence": "predicted"},
    # ISDB — 天然产物预测谱
    "isdb_positive.msp": {"chemical_class": "natural_product", "confidence": "predicted", "sample": "plant"},
    "isdb_negative.msp": {"chemical_class": "natural_product", "confidence": "predicted", "sample": "plant"},
    # HMDB experimental
    "hmdb_experimental_positive.msp": {"confidence": "experimental"},
    "hmdb_experimental_negative.msp": {"confidence": "experimental"},
    # HMDB predicted
    "hmdb_predicted_positive.msp": {"confidence": "predicted"},
    # MSnLib
    "msnlib_mcedrug_positive.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_mcedrug_negative.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_mcebio_positive.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_mcebio_negative.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_mcescaf_positive.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_mcescaf_negative.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_enamdisc_positive.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_enamdisc_negative.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_enammol_positive.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_enammol_negative.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "msnlib_nihnp_positive.msp": {"chemical_class": "natural_product", "confidence": "experimental"},
    "msnlib_nihnp_negative.msp": {"chemical_class": "natural_product", "confidence": "experimental"},
    "msnlib_otavapep_positive.msp": {"chemical_class": "amino_acid_peptide", "confidence": "experimental"},
    "msnlib_otavapep_negative.msp": {"chemical_class": "amino_acid_peptide", "confidence": "experimental"},
    # FooDB
    "foodb_experimental_positive.msp": {"application": "food_safety", "sample": "food", "confidence": "experimental"},
    "foodb_experimental_negative.msp": {"application": "food_safety", "sample": "food", "confidence": "experimental"},
    # ReSpect
    "respect_positive.msp": {"sample": "plant", "confidence": "experimental"},
    # NIST
    "nist_epa_tandem.msp": {"application": "environmental_monitoring", "confidence": "experimental"},
    "nist_glycan_msms.msp": {"chemical_class": "glycan", "confidence": "experimental"},
    "nist_dart_positive.msp": {"confidence": "experimental"},
    # MassBank — all experimental
    # (massbank_*.msp files all get confidence=experimental, instrument from Instrument_type field)
    # MS-DIAL — mixed
    "msdial_all_positive.msp": {"confidence": "mixed"},
    "msdial_all_negative.msp": {"confidence": "mixed"},
    # EMBL-MCF
    "embl_mcf_positive.msp": {"confidence": "experimental"},
    "embl_mcf_negative.msp": {"confidence": "experimental"},
    # GNPS
    "gnps_library_mixed.msp": {"confidence": "mixed"},
    "gnps_hmdb_mixed.msp": {"confidence": "experimental"},
    "gnps_massbank_mixed.msp": {"confidence": "experimental"},
    "gnps_mona_mixed.msp": {"confidence": "experimental"},
    "gnps_nih-clinical1_mixed.msp": {"application": "pharmaceutical", "confidence": "experimental"},
    "gnps_nih-naturalproducts_mixed.msp": {"chemical_class": "natural_product", "confidence": "experimental"},
}
```

**Instrument 字段映射（从 MSP 已有字段提取）：**

```python
def extract_instrument(instrument_type_raw):
    """Map MSP Instrument_type to normalized instrument tag."""
    if not instrument_type_raw: return ""
    it = instrument_type_raw.lower()
    if "orbitrap" in it or "itft" in it: return "orbitrap"
    if "qtof" in it or "q-tof" in it: return "qtof"
    if "qqq" in it or "triple" in it: return "qqq"
    if "ion trap" in it or "iontrap" in it: return "ion_trap"
    if "tof" in it and "q" not in it: return "tof"
    if "ei" in it: return "ei"
    if "dart" in it: return "dart"
    return ""
```

**Polarity 字段映射：**

```python
def extract_polarity(ion_mode_raw):
    if not ion_mode_raw: return ""
    im = ion_mode_raw.upper()
    if "POS" in im: return "positive"
    if "NEG" in im: return "negative"
    return ""
```

**Chemical_class 从 compound_metadata 查询（Layer 2）：**
用 InChIKey 前 14 位匹配。如果 compound_metadata 有值且谱图没有，填入。

- [ ] **Step 2: 运行标签写入**

```bash
cd ~/spectral_libraries
PYTHONUNBUFFERED=1 /Users/jiajun-agent/pony/ponylabASMS/.venv312/bin/python scripts/fill_tags_msp.py
```

预期输出：每个 MSP 文件的标签填充统计。

- [ ] **Step 3: 验证**

创建 `~/spectral_libraries/scripts/verify_msp_tags.py`：
- 解析所有 MSP 文件
- 统计每个标签维度的覆盖率
- 用 matchms 加载测试确认标签可被正确解析
- 输出报告

```bash
/Users/jiajun-agent/pony/ponylabASMS/.venv312/bin/python scripts/verify_msp_tags.py
```

- [ ] **Step 4: Commit（不 push，MSP 文件不在 git 中）**

---

## Task 2: MetaboFlow TagFilter 模型对齐

**Goal:** 将 MetaboFlow 的 TagFilter 模型字段名与 MFSL v2 的八维标签对齐。

**Files:**
- Modify: `packages/backend/app/models/analysis.py`
- Modify: `packages/engines/annot-worker/app/matchms_engine.py`

- [ ] **Step 1: 更新 TagFilter 模型**

`packages/backend/app/models/analysis.py` 中，将：

```python
class TagFilter(BaseModel):
    """Multi-label filter for selecting spectral libraries."""
    instrument: list[str] = Field(default_factory=list)
    organism: list[str] = Field(default_factory=list)
    compound_class: list[str] = Field(default_factory=list)
    confidence: list[str] = Field(default_factory=lambda: ["high", "medium", "low"])
```

改为：

```python
class TagFilter(BaseModel):
    """8-dimension tag filter for spectral and compound databases."""
    chemical_class: list[str] = Field(default_factory=list)
    application: list[str] = Field(default_factory=list)
    sample: list[str] = Field(default_factory=list)
    confidence: list[str] = Field(default_factory=list)
    instrument: list[str] = Field(default_factory=list)
    polarity: list[str] = Field(default_factory=list)
    reg_lists: list[str] = Field(default_factory=list)
    # source 维度不在 TagFilter 中——由 databases 参数控制
```

- [ ] **Step 2: 更新 annot-worker 过滤逻辑**

`packages/engines/annot-worker/app/matchms_engine.py` 中，更新谱图过滤逻辑以使用新的标签字段名：

```python
def _filter_by_tags(spectra, tag_filter):
    """Filter spectra by 8-dimension tags from MSP metadata."""
    filtered = spectra
    for dim in ["chemical_class", "application", "sample", "confidence", "instrument", "polarity", "reg_lists"]:
        values = getattr(tag_filter, dim, [])
        if values:
            filtered = [s for s in filtered if s.metadata.get(dim, "") in values]
    return filtered
```

- [ ] **Step 3: 更新 AnnotationHit 模型**

在 `AnnotationHit`（如果存在）或结果模型中新增字段：

```python
smiles: str | None = None
chemical_class: str | None = None
application: str | None = None
```

- [ ] **Step 4: Rebuild + test**

```bash
cd ~/pony/MetaboFlow
docker compose build backend celery-worker annot-worker
```

- [ ] **Step 5: Commit**

```bash
git add packages/backend/app/models/analysis.py packages/engines/annot-worker/
git commit -m "feat: TagFilter 对齐 MFSL v2 八维标签体系

- compound_class → chemical_class
- organism → sample
- 新增 application, polarity, reg_lists
- confidence 值域从 high/medium/low 改为 experimental/predicted/mixed
- annot-worker 过滤逻辑更新

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: DATABASE_MANUAL 重构

**Goal:** 重构 DATABASE_MANUAL.md 为完整的架构说明书，包含 v2 架构设计、来源清单（原 registry.csv 内容）、构建过程中遇到的所有问题和设计选择。

**Files:**
- Rewrite: `~/spectral_libraries/DATABASE_MANUAL.md`

- [ ] **Step 1: 重构文档结构**

新的 DATABASE_MANUAL.md 结构：

```markdown
# MFSL 技术说明书 v3.0

## 1. 架构概述
  - 1.1 双库结构（质谱库 + 化合物库）
  - 1.2 八维标签体系
  - 1.3 元数据富集机制
  - 1.4 注释匹配流程

## 2. 质谱库
  - 2.1 MSP 文件格式（含标签字段说明）
  - 2.2 来源清单（原 registry.csv 全部 50 个文件，每个文件的来源、谱图数、默认标签）
  - 2.3 去重机制
  - 2.4 质量评分体系

## 3. 化合物库
  - 3.1 compound_metadata.csv 字段定义
  - 3.2 数据来源（11 个化合物数据库）
  - 3.3 覆盖率统计

## 4. 标签填充方法
  - 4.1 四层填充策略
  - 4.2 每个来源的可用标签字段
  - 4.3 ClassyFire/NPClassifier 自动分类

## 5. 构建脚本清单

## 6. 跨产品使用（MetaboFlow / PonylabASMS）

## 7. 设计演进记录
  - 7.1 v1.0 → v2.0 架构变更时间线
  - 7.2 遇到的问题和决策
    - compound_class/organism 维度混淆
    - 4 个错误标签
    - level3_compounds 缺 SMILES
    - 201K 无 InChIKey 化合物
    - MSP InChIKey 缺失补全
    - InChIKey 14 位 vs 27 位匹配
    - spectral_metadata 与 compound_metadata 交集 35%
    - 标签内嵌 MSP vs 独立 CSV 选型
    - registry.csv 废弃
  - 7.3 数据清洗记录

## 8. 版本历史
```

- [ ] **Step 2: 将 registry.csv 内容写入 §2.2 来源清单**

把 50 个 MSP 文件的信息（来源 URL、原始格式、谱图数、处理流程、默认标签）从 registry.csv 和现有 DATABASE_MANUAL §4 中整合。

- [ ] **Step 3: 写入 §7 设计演进记录**

记录本次 session 中遇到的所有问题、根因和解决方案（详见 spec §8 设计决策记录 + 本 session 讨论记录）。

- [ ] **Step 4: 验证文档完整性**

确保所有 50 个 MSP 文件都在来源清单中，所有设计决策都有记录。

---

## Task 4: 清理废弃文件 + 最终验证

**Goal:** 删除废弃文件，运行全面验证。

**Files:**
- Delete: `~/spectral_libraries/registry.csv`
- Delete: `~/spectral_libraries/registry.db`
- Delete: `~/spectral_libraries/spectral_metadata.csv`

- [ ] **Step 1: 备份并删除**

```bash
cd ~/spectral_libraries
mkdir -p _archived_v1
mv registry.csv _archived_v1/
mv registry.db _archived_v1/ 2>/dev/null
mv spectral_metadata.csv _archived_v1/ 2>/dev/null
```

- [ ] **Step 2: 全面验证**

```python
# 验证脚本检查项：
# 1. 所有 MSP 文件都有标签字段
# 2. matchms 能正确加载和按标签过滤
# 3. compound_metadata.csv 覆盖所有 MSP 的 InChIKey（前 14 位）
# 4. registry.csv 不再被任何代码引用
# 5. compound_metadata 字段与 MetaboFlow AnnotationHit 对齐
```

- [ ] **Step 3: Commit MetaboFlow 代码变更 + push**

```bash
cd ~/pony/MetaboFlow
git add packages/backend/ packages/engines/annot-worker/ docs/
git commit -m "feat: MFSL v2 架构落地——八维标签 + TagFilter 对齐 + DATABASE_MANUAL 重构

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push
```

---

## 执行顺序和依赖

```
Task 1 (MSP 标签写入)  ──── 独立，最大工作量
Task 2 (TagFilter 对齐) ──── 独立
Task 3 (DATABASE_MANUAL) ── 独立
Task 4 (清理 + 验证)   ──── 依赖 Task 1-3 全部完成
```

Task 1/2/3 可以并行执行。Task 4 在最后做。
