# 单细胞代谢物→通量约束 Y1 实施计划

## 项目概览

**项目代号**：scMFC（Single-cell Metabolite Flux Constraining）

**核心假设**：MALDI成像质谱测量的单细胞代谢物相对强度，可直接用于约束FBA通量方向，其预测精度优于依赖转录组间接推断的现有方法。

**时间线**：M1-M6（POC阶段）→ M7-18（NatMethods升级阶段）

---

## 1. 前期准备清单

### 1.1 FBA框架选择

**主框架：COBRApy 0.29.x**

选择理由：
- Python生态，与scanpy/anndata无缝集成
- 支持FVA（通量变异性分析）——这是通量方向约束的核心工具
- 社区最活跃，Recon3D加载已有成熟案例
- 支持线性规划后端切换（默认GLPK，可升级为Gurobi学术版提速10-50倍）

依赖安装清单：

```
cobrapython==0.29.0
gurobipy==11.x（学术许可，免费申请）
cobra==0.29.0
memote==0.13.x（模型质量检查）
escher==1.7.x（通量可视化）
```

替代方案评估：
- **MATLAB COBRA Toolbox**：放弃，Python流水线与其集成代价过高
- **RAVEN**：MATLAB，放弃
- **openCOBRA / FBA in R**：放弃，scRNA-seq基线METAFlux本身用R，但核心算法用Python更利于后续扩展

**关键技术选择：FVA而非单次FBA**

原因：单次FBA解不唯一，对于"通量方向"这个研究问题，FVA给出每个反应的通量下界和上界，可直接判断方向（下界>0为正向，上界<0为逆向，跨零为可双向）。这与相对浓度约束逻辑完全吻合。

### 1.2 代谢网络模型选择

**主模型：Recon3D（2018版，BIGG ID: Recon3D）**

具体版本：Recon3D 1.01（Brunk et al., Nature Biotechnology 2018）

选择理由：
- 覆盖8000+反应，4000+代谢物，600+通路
- 包含细胞内定位（胞质/线粒体/ER等），代谢物浓度约束可以按隔室加
- 比Recon2.2更新，模型精度更高
- 有详细的代谢物ChEBI/HMDB/PubChem注释，利于与MALDI数据mapping

**备用模型：Human-GEM 1.18.0**（Yang et al., Science Signaling 2020）

Human-GEM在Recon3D基础上进一步整合了基因-反应-蛋白质关联（GPR），如果后续需要与scRNA-seq比较时使用，逻辑更自洽。

**子网络策略（关键决策）**：

由于73个LC-MS验证代谢物覆盖Recon3D 4000+节点的覆盖率极低（约1.8%），不能直接约束全网络。具体子网络选择见第4节。

**模型质量预检步骤**：

```python
# 必须执行的预检
import cobra
model = cobra.io.load_json_model("Recon3D.json")
# 检查1：无约束FBA能否生长（biomass reaction不为零）
# 检查2：memote质量报告
# 检查3：blocked reactions数量（FVA筛掉永远为零的反应）
```

### 1.3 单细胞数据处理工具链

完整工具链（按处理顺序）：

**层次1：原始成像数据处理**
- `SpaceM`（原作者工具）：细胞分割 + 离子图像提取
- `METASPACE`平台：代谢物注释（直接用已注释数据则跳过）
- `pyImagingMSpec` / `ims-transform`：如需从原始.imzML处理

**层次2：单细胞代谢物矩阵处理**
- `anndata` + `scanpy`：存储和基础处理
- `squidpy`：空间代谢组分析（如需空间邻域分析）
- `harmonypy` / `scvi-tools`：批次校正（如多批次数据）

**层次3：统计和FBA接口**
- `scipy.stats`：斯皮尔曼相关、Mann-Whitney U检验
- `numpy` / `pandas`：矩阵运算
- `statsmodels`：多重检验校正（FDR BH）

**层次4：可视化**
- `matplotlib` + `seaborn`：标准统计图
- `escher`：代谢通路通量可视化（嵌入文章图）
- `scanpy.pl`：单细胞相关可视化

### 1.4 METAFlux复现方案

METAFlux（Zheng et al., Nature Communications 2023）使用Elastic Net回归将scRNA-seq表达量映射到FBA通量约束。

复现步骤：

**步骤1：环境搭建**
```
# METAFlux是R包
# R >= 4.2, Bioconductor 3.16
install.packages("METAFlux")
# 依赖：COBRA（R版）, glmnet, Seurat
```

**步骤2：数据准备**
- 需要与HT SpaceM同一细胞系的scRNA-seq数据
- 用基因表达量（非代谢物）做输入
- 用Human-GEM或Recon3D作为代谢网络

**步骤3：运行流程**
```r
library(METAFlux)
# input: normalized scRNA-seq count matrix (cells × genes)
# output: flux matrix (cells × reactions)
flux_result <- metaflux(scRNA_matrix, model="Recon3D")
```

**步骤4：提取可比较输出**
- 从METAFlux的通量矩阵提取与本方法相同的核心通路反应
- 转换为通量方向（sign），用于与bulk验证数据比较

**关键注意**：METAFlux输出的是每个细胞的通量值，需聚合为细胞群体均值或分组均值，才能与bulk数据比较。

---

## 2. 数据获取详细方案

### 2.1 HT SpaceM数据

**文章**：Rappez et al., "HT-SpaceM enables high-throughput single-cell metabolomics in tissue microarrays", Cell 2025（或同年预印本）

**需要确认的信息**（以下基于已知信息，需验证）：

**主要查找路径（按优先级）**：

路径1 — EMBL-EBI PRIDE/METASPACE：
- METASPACE是MALDI成像数据的主要公共库
- 访问：https://metaspace2020.eu
- 搜索关键词："HT SpaceM" 或 "high-throughput SpaceM" 或 "Rappez 2025"
- METASPACE提供直接下载注释后的.csv（含代谢物、m/z、细胞ID、强度）

路径2 — GEO（如有scRNA-seq配套数据）：
- 访问：https://www.ncbi.nlm.nih.gov/geo/
- 搜索："HT SpaceM" / "spatial metabolomics single cell"
- 预期格式：.h5ad 或 count matrix

路径3 — Zenodo（计算数据集常用）：
- 访问：https://zenodo.org
- 搜索："HT SpaceM" 或 doi引用

路径4 — 文章Data Availability Statement：
- 直接从Cell文章全文获取确切链接
- 访问：https://doi.org/10.1016/j.cell.2025.xxxxx（需查实际DOI）

路径5 — 联系作者：
- 如数据未公开，直接邮件Rappez/Alexandrov实验室
- EMBL Heidelberg，Alexandrov组，通常2周内回复

**预期数据格式**：

METASPACE下载的典型格式：
```
cell_id | metabolite_name | mz | intensity | x_coord | y_coord | cell_type
```
或.h5ad格式（anndata对象）：
```python
adata.X        # cells × metabolites intensity matrix
adata.obs      # cell metadata (type, condition, plate)
adata.var      # metabolite metadata (mz, formula, adduct)
adata.obsm["spatial"]  # XY坐标
```

**140,000+细胞，~100代谢物**：
- 矩阵大小约 140,000 × 100，稀疏，大多数细胞只检测到部分代谢物
- 文件大小预估：h5ad约200-500MB，csv约2-5GB

**预处理步骤**：

步骤1：细胞分割（如从原始数据）
- SpaceM内置细胞分割（基于荧光图像 + MALDI离子图像）
- 若下载的是已分割数据，此步骤跳过
- 工具：`SpaceM` Python包（https://github.com/LewisLabUCSD/SpaceM）

步骤2：代谢物鉴定
- METASPACE已完成代谢物注释（基于数据库匹配）
- 需要筛选FDR < 0.2的注释结果（METASPACE默认阈值）
- 关键：保留有HMDB/ChEBI ID的代谢物，用于后续mapping到Recon3D

步骤3：强度归一化
- 方案A（推荐）：TIC归一化（total ion count），每个细胞的代谢物强度除以该细胞所有检测到的离子总量
- 方案B：基于参考代谢物的归一化（如果有稳定内标）
- 方案C：log1p变换 + 中位数归一化（类似scRNA-seq处理）
- 注意：TIC归一化假设细胞总代谢含量相同，这个假设需要在Discussion中讨论

步骤4：批次效应校正（如数据来自多个实验）
- 视具体数据结构决定，参考HT SpaceM文章的处理方式

步骤5：细胞筛选
- 去除检测到代谢物数<10的低质量细胞
- 去除离群细胞（Mahalanobis距离>3σ）

### 2.2 73个LC-MS/MS验证代谢物

**来源**：HT SpaceM原文的Supplementary数据
- 73个代谢物是文章作者已用LC-MS/MS批量验证的子集
- 格式预期：Supplementary Table，包含代谢物名称、HMDB ID、验证相关性等
- 这73个代谢物是POC的核心，其HMDB/ChEBI ID用于mapping到Recon3D

### 2.3 Recon3D模型下载

**官方来源**：
- BiGG数据库：https://bigg.ucsd.edu/models/Recon3D
- 下载格式：JSON（推荐，COBRApy直接读取）、SBML（.xml）、MAT
- 直接链接：http://bigg.ucsd.edu/static/models/Recon3D.json

**备用：Human-GEM**
- GitHub：https://github.com/SysBioChalmers/Human-GEM
- 下载最新release：https://github.com/SysBioChalmers/Human-GEM/releases
- 格式：.xml（SBML）

**模型基本参数**（Recon3D）：
- 反应数：13,543
- 代谢物数：5,835（含隔室）
- 基因数：3,288
- 通路数：629

### 2.4 Bulk验证数据

**首选方案：使用同文章（HT SpaceM Cell 2025）的配套bulk数据**

HT SpaceM文章通常包含：
- LC-MS/MS测量的细胞群体平均代谢物水平
- 不同处理条件下的bulk代谢组数据

具体获取：检查文章Data Availability和Supplementary，以及PRIDE数据库（LC-MS数据）

**次选方案：外部bulk代谢组数据（同细胞系）**

如果HT SpaceM使用HeLa细胞（常见）：
- HMDB代谢组数据库：https://hmdb.ca（HeLa参考浓度）
- Metabolomics Workbench：https://www.metabolomicsworkbench.org
- 搜索"HeLa glycolysis inhibition" 或 "HeLa 2-DG treatment"

关于"糖酵解抑制实验"的bulk数据：
- 经典实验：2-脱氧葡萄糖（2-DG）处理抑制糖酵解
- 预期通量变化：糖酵解通量下降，线粒体代偿性上升
- 文献验证：Jang et al. Science 2018（U-13C葡萄糖示踪），可用于方向验证

### 2.5 METAFlux所需scRNA-seq数据

**问题**：METAFlux需要scRNA-seq，但HT SpaceM是代谢组学数据，两者不能直接配对。

**方案A（推荐）：公开HeLa scRNA-seq**
- 10x Genomics公开HeLa数据：https://www.10xgenomics.com/datasets
- GEO搜索"HeLa single cell RNA-seq"
- 推荐数据集：GSE146771（HeLa scRNA-seq，已发表）

**方案B：伪bulk方案**
- 将scRNA-seq数据聚合为伪bulk，再用METAFlux处理
- 这是公平比较的标准做法

**方案C：直接使用METAFlux论文附带的演示数据**
- 但细胞系可能不同，需注意在论文中说明

**数据可获得性评估汇总**：

| 数据 | 可获得性 | 难度 | 备注 |
|------|---------|------|------|
| HT SpaceM .h5ad | 高 | 低 | METASPACE/Zenodo/作者 |
| 73个LC-MS验证 | 高 | 低 | 文章Supplementary |
| Recon3D模型 | 高 | 低 | BiGG直接下载 |
| Bulk代谢组验证 | 中 | 中 | 需从文章或外部获取 |
| HeLa scRNA-seq | 高 | 低 | GEO公开数据充足 |

---

## 3. 需要编写的全部脚本清单

### 模块0：环境配置（1-2天）
```
00_setup/
  00_install_deps.sh          # conda环境创建，所有依赖安装
  01_test_imports.py          # 验证所有import正常
  02_download_data.py         # 自动下载所有数据集（含URL）
```

### 模块1：数据预处理（M1 Week 1-2）
```
01_preprocessing/
  01_load_spacem_data.py      # 加载.h5ad或csv，标准化为anndata格式
  02_metabolite_qc.py         # 细胞过滤，代谢物过滤（检测率>10%）
  03_intensity_normalization.py  # TIC归一化 + log1p变换
  04_batch_correction.py      # 如有多批次：harmonypy校正
  05_cell_type_annotation.py  # 利用空间信息或已有标注
  06_export_clean_matrix.py   # 输出标准矩阵：clean_adata.h5ad
```

### 模块2：代谢物→Recon3D映射（M1 Week 2-3）
```
02_mapping/
  01_load_recon3d.py          # 加载Recon3D，基础质检（biomass flux）
  02_metabolite_mapping.py    # HMDB/ChEBI ID → Recon3D代谢物ID
  03_unmapped_analysis.py     # 分析未能mapping的代谢物（诊断用）
  04_subnetwork_extraction.py # 提取核心碳代谢子网络（见第4节）
  05_mapping_report.py        # 输出覆盖率报告：多少个代谢物在网络中
```

### 模块3：约束算法核心（M2-M3）
```
03_core_algorithm/
  01_relative_to_direction.py  # 相对强度→通量方向约束（核心公式，见第4节）
  02_constraint_builder.py     # 将方向约束写入COBRApy模型
  03_fva_runner.py             # 对每个细胞（或细胞群）运行FVA
  04_flux_direction_extractor.py  # 从FVA结果提取通量方向
  05_population_aggregator.py  # 单细胞→群体水平聚合
  06_batch_fva.py              # 批量运行（多条件、多细胞群）
```

### 模块4：METAFlux基线（M2，并行）
```
04_baseline/
  01_prepare_rnaseq_input.R   # 准备scRNA-seq输入格式
  02_run_metaflux.R           # 运行METAFlux
  03_extract_metaflux_flux.R  # 提取通量方向
  04_metaflux_to_python.py    # R结果导入Python（csv中转）
```

### 模块5：验证框架（M3-M4）
```
05_validation/
  01_load_bulk_data.py         # 加载bulk验证数据
  02_bulk_flux_direction.py    # 从bulk代谢组推导参考通量方向
  03_correlation_analysis.py   # 计算预测vs验证的斯皮尔曼相关
  04_pathway_comparison.py     # 通路级别对比（本方法 vs METAFlux vs 无约束）
  05_go_nogo_evaluator.py      # M6 Go/No-Go自动评估脚本
```

### 模块6：敏感性分析（M4）
```
06_sensitivity/
  01_threshold_sensitivity.py  # 约束阈值参数扫描
  02_subnetwork_sensitivity.py # 不同子网络选择对结果的影响
  03_normalization_sensitivity.py  # 不同归一化方案对比
  04_bootstrap_analysis.py     # Bootstrap置信区间
```

### 模块7：可视化（M5-M6）
```
07_visualization/
  01_fig1_concept_diagram.py   # 方法概念图（矢量图输出）
  02_fig2_mapping_coverage.py  # 代谢物映射覆盖率分析图
  03_fig3_flux_prediction.py   # 通量预测vs验证散点图
  04_fig4_pathway_comparison.py  # 通路级别对比图（本方法 vs 基线）
  05_fig5_single_cell_heterogeneity.py  # 单细胞异质性展示
  06_escher_maps.py            # Escher代谢通路通量可视化
  07_si_figures.py             # 所有SI图
```

### 模块8：流水线集成（M5）
```
08_pipeline/
  Snakemake/                  # 或Nextflow
    Snakefile                 # 全流水线DAG定义
    config.yaml               # 参数配置文件
    envs/
      scmfc.yaml              # conda环境定义
  run_poc.sh                  # 一键运行POC实验
  run_full.sh                 # 一键运行全流水线
```

### 模块9：测试（贯穿全程）
```
09_tests/
  test_mapping.py             # 代谢物mapping单元测试
  test_constraint_builder.py  # 约束构建正确性测试
  test_fva_runner.py          # FVA数值测试（已知答案验证）
  test_correlation.py         # 统计方法测试
  integration_test.py         # 端到端小数据集测试
```

---

## 4. 独创算法设计

### 4.1 降级版通量方向约束：完整数学框架

**标准tFBA的要求**（本文无法满足）：

tFBA（Thermodynamic FBA，Henry et al. 2007）要求：
- 每个代谢物的绝对浓度 c_i（单位：mM）
- 计算吉布斯自由能变化：ΔG'_r = ΔG'°_r + RT·Σ(ν_i·ln(c_i))
- 约束：每个自发反应的ΔG'_r < 0

**降级方案：相对方向约束（Relative Direction Constraint，RDC）**

核心思想：即使没有绝对浓度，我们仍然可以通过比较两种条件（处理 vs 控制）下相对浓度的变化方向，推断通量变化的方向。

**数学框架**：

设代谢物 i 在条件A和条件B下的MALDI强度分别为：

```
I_i^A, I_i^B  (相对强度，单位任意)
```

定义相对变化：
```
Δr_i = (I_i^B - I_i^A) / I_i^A
```

对于反应 r，其产物集合为 P_r，底物集合为 S_r。

定义**代谢物约束分数**（Metabolite Constraint Score，MCS）：
```
MCS_r = Σ_{i∈P_r, i∈M} w_i · Δr_i - Σ_{j∈S_r, j∈M} w_j · Δr_j
```

其中：
- M 是被测量到的代谢物集合（73个代谢物的子集）
- w_i 是权重（默认=1；可按测量置信度加权）

**通量方向约束规则**：
```
if MCS_r > θ_pos:  约束 v_r ≥ 0  (正向通量)
if MCS_r < θ_neg:  约束 v_r ≤ 0  (逆向通量或零)
if θ_neg ≤ MCS_r ≤ θ_pos:  不施加约束 (不确定)
```

其中阈值 θ_pos > 0, θ_neg < 0 是关键超参数（见第7节）。

**与tFBA的关系**：

tFBA的热力学约束等价于：
```
ΔG'_r = ΔG'°_r + RT·Σ_i ν_i·ln(c_i) < 0
```

在两种条件比较时，如果忽略ΔG'°项（在相同温度和细胞类型下相同），变化量为：
```
ΔΔG'_r ≈ RT·Σ_i ν_i·Δln(c_i) ≈ RT·Σ_i ν_i·Δr_i （当Δr_i较小时）
```

因此MCS_r实际上是ΔΔG'_r的一阶近似（去掉了RT和标准自由能项）。

**本文独创声明**：
- 借鉴自tFBA：热力学约束的基本框架，Gibbs自由能与浓度的关系
- 本文独创：将绝对浓度要求降级为相对强度差值；MCS的定义；双阈值方案；将该框架应用于MALDI单细胞数据

### 4.2 从相对强度推导通量方向约束：具体公式

**输入**：
- `X[c, m]`：细胞 c 的代谢物 m 的MALDI强度（TIC归一化后）
- 细胞分组：条件A（控制）和条件B（处理），每组N个细胞

**步骤1：计算群体水平相对变化**

```python
# 对每个代谢物计算中位数（对离群值鲁棒）
median_A = np.median(X[group_A, :], axis=0)  # shape: (n_metabolites,)
median_B = np.median(X[group_B, :], axis=0)

# 相对变化（log fold change，更稳定）
log_fc = np.log2(median_B + epsilon) - np.log2(median_A + epsilon)
# epsilon = 1e-6 防止log(0)
```

**步骤2：代谢物→反应映射**

```python
# S矩阵：反应×代谢物的化学计量矩阵（从Recon3D提取）
# 对于每个反应r，可测量的代谢物子集 M_r
# MCS_r = Σ_i ν_{r,i} · log_fc_i (仅对i∈M_r求和)

S_measured = S[:, measured_metabolites]  # 子化学计量矩阵
MCS = S_measured @ log_fc               # shape: (n_reactions,)
```

**步骤3：计算覆盖率权重**

```python
# 每个反应的覆盖率 = 被测量到的代谢物数 / 总参与代谢物数
coverage = np.sum(S_measured != 0, axis=1) / np.sum(S != 0, axis=1)
# 覆盖率<0.3的反应不施加约束（参数可调）
reliable_reactions = coverage >= min_coverage_threshold  # 默认0.3
```

**步骤4：施加约束**

```python
for r_idx, reaction in enumerate(model.reactions):
    if not reliable_reactions[r_idx]:
        continue
    mcs = MCS[r_idx]
    if mcs > theta_pos:
        reaction.lower_bound = max(reaction.lower_bound, 0)
    elif mcs < theta_neg:
        reaction.upper_bound = min(reaction.upper_bound, 0)
    # 否则：不约束
```

### 4.3 73个代谢物到Recon3D 4000+节点的映射策略

**覆盖率问题量化**：

全网络覆盖率：73 / 4000 ≈ 1.8%（过低，不适合约束全网络）

中央碳代谢子网络覆盖率（估算）：
- 糖酵解：10个关键代谢物（葡萄糖、G6P、F6P、FBP、DHAP、G3P、3PG、2PG、PEP、丙酮酸）→ 73个中至少含6-8个 → 覆盖率60-80%
- TCA循环：8个关键代谢物 → 73个中含5-7个 → 覆盖率60-80%

**Mapping策略（三级匹配）**：

第一级：直接ID匹配
```python
# HMDB ID → Recon3D代谢物ID
hmdb_to_recon = load_mapping_table("hmdb_recon3d_mapping.csv")
# 来源：Recon3D官方注释文件（BiGG database提供）
direct_mapped = [m for m in metabolites_73 if m.hmdb in hmdb_to_recon]
```

第二级：名称模糊匹配（对未匹配的）
```python
from rapidfuzz import fuzz
# 代谢物常用名→Recon3D代谢物名
# 手动审核相似度>0.85的候选
```

第三级：化学式匹配（对名称匹配失败的）
```python
# 从PubChem获取分子式，与Recon3D分子式精确匹配
# 注意：同一分子式可能对应多个异构体，需人工确认
```

**预期mapping结果**：
- 直接匹配：约50-60个（68-82%）
- 名称/化学式匹配：约5-10个
- 无法匹配：约5-15个（通常是MALDI特异性脂质或未鉴定代谢物）

**未匹配代谢物处理**：
- 不施加约束（安全做法，宁可少约束不约束错误）
- 在Methods中报告最终mapping率

### 4.4 中央碳代谢子网络：具体选择

**子网络选择标准**：
1. 有充足的代谢物被73个LC-MS验证代谢物覆盖（>50%代谢物可测）
2. 在细胞处理实验中有明确的方向性改变（实验可检测）
3. 在Recon3D中有良好的注释和GPR关联

**具体选择5条核心通路**：

通路1：糖酵解/糖异生（Recon3D通路ID：glycolysis_gluconeogenesis）
- 关键代谢物：葡萄糖、葡萄糖-6-磷酸、果糖-6-磷酸、磷酸烯醇丙酮酸、丙酮酸
- 反应数：约20个（筛选后约12个可约束）
- 预期在2-DG处理中方向性变化明显

通路2：TCA循环（citric_acid_cycle）
- 关键代谢物：柠檬酸、异柠檬酸、α-酮戊二酸、琥珀酸、富马酸、苹果酸
- 反应数：约15个
- 这些代谢物在LC-MS/MS中检测稳定

通路3：氧化磷酸化上游（oxidative_phosphorylation）
- 仅选NADH/NAD⁺比值相关的代谢物约束
- 约5-8个反应

通路4：谷氨酸/谷氨酰胺代谢（glutamate_metabolism + glutamine_metabolism）
- 关键代谢物：谷氨酸、谷氨酰胺、天冬氨酸
- 在癌细胞代谢重编程研究中极重要

通路5：核苷酸代谢（purine_metabolism）
- ATP/ADP/AMP是重要代谢状态指标
- 如果73个代谢物中包含这些，可加入

**子网络提取代码逻辑**：
```python
# 从Recon3D提取子网络
target_pathways = [
    "glycolysis", "gluconeogenesis", "citric_acid_cycle",
    "pyruvate_metabolism", "glutamate_metabolism", "glutamine_metabolism"
]
subnetwork_reactions = []
for rxn in model.reactions:
    if any(p in rxn.subsystem.lower() for p in target_pathways):
        subnetwork_reactions.append(rxn.id)
# 预期：约150-200个反应
submodel = model.copy()
reactions_to_remove = [r for r in submodel.reactions if r.id not in subnetwork_reactions]
submodel.remove_reactions(reactions_to_remove, remove_orphans=True)
```

### 4.5 与METAFlux公平比较框架

**核心挑战**：本方法输入是代谢物强度，METAFlux输入是基因表达量，两者不可直接比较。

**公平比较设计**：

**共同输出空间**：
- 两种方法都预测同一套反应（子网络中约150个反应）的通量方向（+1/0/-1）
- 两种方法都用同一个Recon3D子网络（确保可比较性）
- 两种方法都聚合到细胞群体水平再与bulk比较

**共同评估标准**：
```python
# 对每个反应r，定义：
# predicted_direction[r] ∈ {+1, 0, -1}（本方法或METAFlux预测）
# reference_direction[r] ∈ {+1, -1}（来自bulk数据）

# 精确度计算（排除预测为0的反应）
accuracy = sum(pred == ref for pred, ref in zip(predicted, reference)
               if pred != 0) / sum(pred != 0 for pred in predicted)

# 覆盖率计算（有预测的反应比例）
coverage = sum(pred != 0 for pred in predicted) / len(predicted)

# 综合指标：F1-like score
# precision = accuracy
# recall = coverage  
# F1 = 2 * precision * recall / (precision + recall)
```

**通路级别比较（Go/No-Go关键指标）**：
```python
# 对每条通路计算通路内的平均预测准确度
pathway_scores = {}
for pathway in target_pathways:
    rxns = get_pathway_reactions(pathway)
    pathway_scores[pathway] = compute_accuracy(rxns)

# Go条件：≥3条通路中，本方法准确度 > METAFlux准确度
better_pathways = sum(
    pathway_scores_ours[p] > pathway_scores_metaflux[p]
    for p in target_pathways
)
```

**METAFlux输入数据的处理**：
- 使用同一细胞系（HeLa）的公开scRNA-seq数据
- 相同的处理条件（如有配对数据）
- 在论文中明确说明：两种方法的输入来自不同测量模态，比较的是方向预测能力

### 4.6 理论归属声明

**借鉴自现有理论**：
- tFBA（Henry et al. 2007, Biophysical Journal）：热力学约束FBA的基本框架
- FVA（Mahadevan & Schilling, 2003）：通量变异性分析方法
- METAFlux（Zheng et al. 2023）：单细胞FBA的整体思路
- GEM-based metabolomics integration（Opdam et al., Cell Systems 2017）：代谢物约束COBRA模型

**本文独创**：
1. 将tFBA的绝对浓度要求降级为相对强度差值（RDC框架）
2. MCS（代谢物约束分数）的定义及双阈值方案
3. MALDI相对强度→FBA约束的完整计算管道
4. 在HT SpaceM 14万单细胞数据上的应用
5. 单细胞代谢物直接约束（区别于所有现有方法的转录组间接推断）

---

## 5. 实验设计

### 5.1 POC实验具体步骤

**实验1：基础通量方向预测**（M2-M3，核心POC）

步骤1：从HT SpaceM数据中选择两种条件的细胞群
- 条件A：正常培养HeLa（对照）
- 条件B：处理后HeLa（处理类型依文章而定，如2-DG、oligomycin等）
- 每组选取N≥500个细胞（保证统计稳定性）

步骤2：计算73个代谢物的log fold change（条件B vs 条件A）

步骤3：映射到Recon3D子网络，计算MCS

步骤4：施加通量方向约束，运行FVA

步骤5：提取预测的通量方向向量

步骤6：从bulk验证数据获取参考通量方向

步骤7：计算斯皮尔曼相关 r

**实验2：METAFlux基线建立**（M2-M3，并行）

同上，但使用HeLa scRNA-seq数据运行METAFlux，获得相同处理条件下的通量预测

**实验3：无约束FBA对照**（M2，1天）

不施加任何代谢物约束，仅运行标准FVA，作为"最差基线"

**实验4：单细胞异质性分析**（M4，POC扩展）

- 分析单个细胞之间的通量预测差异
- 展示单细胞代谢异质性（这是文章的独特卖点）
- 与传统bulk方法对比

### 5.2 变量设计

**自变量（3水平）**：
1. 代谢物约束（本文方法，RDC）
2. 转录组约束（METAFlux基线）
3. 无约束（FVA，null模型）

**因变量（主要）**：
- 斯皮尔曼相关 r（预测通量方向 vs bulk参考）
- 通路级别准确度（每条通路内的方向预测准确率）

**因变量（次要）**：
- 预测覆盖率（有明确方向预测的反应比例）
- F1 score（综合精确度和覆盖率）

**控制变量**：
- 相同的代谢网络模型（Recon3D子网络）
- 相同的细胞系（HeLa）
- 相同的FVA参数（fraction_of_optimum = 0.9）

### 5.3 HeLa糖酵解抑制实验验证方案

**实验设置**：
- 处理：2-脱氧葡萄糖（2-DG，10mM）处理HeLa 6小时（经典糖酵解抑制）
- 或：HT SpaceM文章已有的处理条件（如drug perturbation实验）

**预期代谢物变化**（bulk参考方向）：
- 葡萄糖：细胞内↑（摄取减少）
- 葡萄糖-6-磷酸：↓（2-DG竞争）
- 丙酮酸：↓（糖酵解减少）
- 乳酸：↓（糖酵解减少）
- TCA中间体（柠檬酸等）：↑（替代燃料供应）
- 谷氨酸/谷氨酰胺：↑摄取

**预期通量变化方向（参考方向向量）**：

| 反应 | 预期方向 | 依据 |
|------|---------|------|
| 己糖激酶 | ↓ | 2-DG竞争性抑制 |
| 磷酸果糖激酶 | ↓ | 级联效应 |
| 丙酮酸激酶 | ↓ | 级联效应 |
| 乳酸脱氢酶 | ↓ | 丙酮酸减少 |
| 柠檬酸合酶 | ↑ | 补偿性TCA上升 |
| 谷氨酸脱氢酶 | ↑ | 谷氨酸补偿 |

**bulk验证数据获取**：
- 如HT SpaceM文章未提供2-DG实验，使用文献数据（Jang et al. Science 2018提供了U-13C示踪flux数据）
- 或：进行配套湿实验（M4-M5，低成本验证：LC-MS/MS测量处理后HeLa细胞代谢物，外包给代谢组学平台，约3-5万RMB）

### 5.4 Go/No-Go量化标准

**Go条件（M6评估）**：

条件1（必须满足）：
```
r > 0.5 (斯皮尔曼相关)
p < 0.05 (统计显著)
```

条件2（必须满足）：
```
≥3条通路（共5条）中，本方法准确度 > METAFlux准确度
```

条件3（加分项，用于升NatMethods的论证）：
```
在单细胞异质性展示中，发现bulk方法遗漏的代谢异质性
```

**No-Go判断**：
- 若r < 0.3：方法不可行，停止
- 若0.3 ≤ r ≤ 0.5：方法弱可行，但不支持发表，需重新审视数据质量或算法
- 若通路优势 < 2条：与METAFlux无显著区别，需重新设计

**统计检验方案**：
- Wilcoxon符号秩检验：比较本方法 vs METAFlux在相同通路上的准确度
- Bootstrap（n=1000）：所有相关系数的置信区间
- Bonferroni校正：多通路比较的多重检验

---

## 6. 论文结构与图表详细规划

### 6.1 AC版本（初版）：主文图表

**Figure 1：概念与数据概述**（两个panel）

Panel A（概念图，手绘/BioRender风格）：
- 左：传统方法路径（细胞→scRNA-seq→基因表达→间接推断→通量）
- 右：本方法路径（细胞→MALDI→代谢物强度→直接约束→通量）
- 突出显示：本方法去除了"转录-代谢"这一不确定步骤
- 颜色：红色为传统路径，蓝色为本方法

Panel B（数据可视化）：
- HT SpaceM数据集概览：140,000个细胞的UMAP，颜色代表细胞类型
- 73个代谢物的检测率热图（代谢物×细胞类型）
- 子图：代谢物mapping到Recon3D子网络的覆盖率桑基图

**Figure 2：方法论证与核心结果**（三个panel）

Panel A（mapping结果）：
- 73个代谢物到Recon3D的mapping结果
- 中央碳代谢子网络的覆盖率可视化（escher地图，将测量到的代谢物高亮）

Panel B（核心验证散点图）：
- X轴：参考通量方向（来自bulk数据）
- Y轴：预测通量方向分数（MCS）
- 每个点为一个反应
- 颜色：所属通路
- 显示：r=0.xx, p=0.xxx
- 三个子图：本方法 / METAFlux / 无约束（并列比较）

Panel C（通路级别比较柱状图）：
- X轴：5条核心通路
- Y轴：通量方向预测准确度（0-1）
- 三组柱子：本方法（蓝）/ METAFlux（橙）/ 无约束（灰）
- 显著性标注（*，**，***）

**Figure 3：单细胞异质性（独特卖点）**（两个panel）

Panel A：
- 单细胞水平的通量方向热图（细胞×反应子集）
- 展示单细胞之间的代谢异质性
- 按细胞亚群分组排序

Panel B：
- 选取一个代谢通路（如糖酵解）
- 展示不同细胞亚群的通量分布（violin图）
- 与bulk预测对比（bulk无法区分亚群）

**Figure 4（如有）：外部验证或方法鲁棒性**

如有第二个数据集或第二种细胞系，展示方法泛化性。

### 6.2 NatMethods升级版：额外内容

升级NatMethods需要增加的内容：

**额外图表1：方法参数鲁棒性分析**（1个完整Figure）
- 阈值θ扫描：展示结果对参数不敏感
- 不同子网络选择：展示核心结果稳定
- 不同归一化方法：TIC vs log-median归一化的比较
- Bootstrap置信区间

**额外图表2：与其余4个竞争方法的全面比较**（1个Figure）
- 不仅vs METAFlux，还vs scFEA、Compass、scFBA（如有公开实现）
- 统一评估框架，公平比较

**额外图表3：方法在第二个数据集的验证**
- 寻找第二个MALDI单细胞数据集（Alexandrov组或其他）
- 或：换细胞系（非HeLa）验证

**额外内容：软件包**
- NatMethods要求方法有可复用的软件实现
- 需要打包为Python包（PyPI发布）
- README + tutorial notebook（复现Figure 2的完整代码）
- GitHub CI/CD + 单元测试

**额外内容：计算复杂度分析**
- 每个细胞的FVA运行时间
- 1000个细胞 / 10000个细胞 / 140000个细胞的耗时
- 与METAFlux的计算开销比较
- 并行化策略说明

### 6.3 Supplementary Information规划

SI Figure 1：数据质量控制
- 细胞过滤前后的代谢物检测分布
- TIC归一化效果验证
- 批次效应（如有）

SI Figure 2：代谢物mapping详细报告
- 所有73个代谢物的mapping状态（匹配/未匹配/部分匹配）
- 三级matching策略各自匹配的数量
- 未匹配代谢物列表及原因分析

SI Figure 3：Recon3D子网络验证
- 无约束FVA结果（验证子网络是否合理）
- Biomass flux与细胞生长率的相关性（如有实验数据）

SI Figure 4：METAFlux复现验证
- 在原文数据上复现METAFlux的发表结果（证明基线实现正确）

SI Figure 5：统计方法详细结果
- 所有通路的完整精确度/覆盖率/F1数据
- Bootstrap置信区间的完整图

SI Figure 6：计算复杂度
- FVA运行时间 vs 细胞数量
- 内存使用

SI Table 1：73个代谢物的完整mapping表
SI Table 2：子网络所有反应列表及预测方向
SI Table 3：通路级别完整统计结果

### 6.4 Discussion论证框架

**段落1：方法创新性定位**
- 明确区分"直接测量"vs"间接推断"
- 强调消除了转录-代谢转换这一不确定步骤的意义
- 与5个竞争方法的清晰区分

**段落2：降级策略的科学合理性**
- 解释为何不需要绝对浓度仍能获得有意义的约束
- 与tFBA理论的数学联系
- 双阈值方案的鲁棒性

**段落3：局限性（必须诚实）**
- 73个代谢物覆盖率有限（坦诚，然后论证足以覆盖中央碳代谢）
- MALDI空间分辨率限制（与LC-MS比较）
- 处理条件依赖性（需要配对数据）
- 目前只适用于有明确代谢改变的实验条件

**段落4：未来方向**
- 更多代谢物（MALDI技术进步→数百个代谢物）
- 绝对浓度标准化（如有内标，可尝试真正tFBA）
- 空间通量异质性分析
- 与proteomics数据联合约束

---

## 7. 关键变量列表

### 7.1 算法参数（需要调参）

| 变量名 | 默认值 | 范围 | 说明 |
|--------|--------|------|------|
| `theta_pos` | 0.3 | 0.1-1.0 | 正向约束阈值 |
| `theta_neg` | -0.3 | -1.0 至 -0.1 | 逆向约束阈值 |
| `min_coverage` | 0.3 | 0.1-0.6 | 每个反应最低代谢物覆盖率 |
| `epsilon` | 1e-6 | 固定 | 防止log(0) |
| `fraction_of_optimum` | 0.9 | 0.8-0.99 | FVA参数 |
| `min_cells_per_group` | 100 | 50-500 | 每组最少细胞数 |
| `log_fc_method` | "log2_ratio" | "log2/log/ratio" | fold change计算方式 |
| `aggregation_method` | "median" | "mean/median/trimmed_mean" | 细胞群体聚合方式 |

### 7.2 子网络选择参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `target_subsystems` | ["glycolysis", "TCA", "glutamate"] | 目标通路名称（匹配Recon3D字段） |
| `max_reactions_in_subnetwork` | 300 | 子网络最大反应数 |
| `include_transport_reactions` | True | 是否包含跨膜转运反应 |
| `compartments` | ["c", "m"] | 包含的细胞隔室（胞质+线粒体） |

### 7.3 验证参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `correlation_method` | "spearman" | 相关性计算方法 |
| `significance_threshold` | 0.05 | p值显著性阈值 |
| `go_nogo_r_threshold` | 0.5 | Go/No-Go相关性下限 |
| `go_nogo_pathway_threshold` | 3 | 必须优于METAFlux的最少通路数 |
| `bootstrap_n` | 1000 | Bootstrap迭代次数 |
| `fdr_method` | "BH" | 多重检验校正方法 |

### 7.4 数据处理参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `min_detection_rate` | 0.1 | 代谢物在细胞中最低检测率 |
| `min_metabolites_per_cell` | 10 | 每个细胞最少检测到的代谢物数 |
| `normalization_method` | "TIC" | 归一化方法 |
| `outlier_threshold` | 3.0 | Mahalanobis距离阈值 |
| `batch_correction` | False | 是否进行批次校正 |

### 7.5 Go/No-Go评估矩阵

| 指标 | 强Go | 弱Go | No-Go |
|------|------|------|-------|
| 斯皮尔曼r | >0.6 | 0.5-0.6 | <0.5 |
| 优于METAFlux通路数 | ≥4 | 3 | <3 |
| 整体准确度 | >0.7 | 0.6-0.7 | <0.6 |
| 单细胞异质性发现 | 有显著差异 | 有弱差异 | 无差异 |

---

## 8. M1-M6时间线详细分配

**M1（前4周）：数据获取与环境搭建**
- W1-2：下载所有数据，搭建Python/R环境，COBRApy + Recon3D加载验证
- W3：HT SpaceM数据预处理（QC + 归一化）
- W4：代谢物→Recon3D mapping（三级策略），产出mapping报告

**M2（W5-W8）：算法原型**
- W5-6：子网络提取 + MCS计算 + 约束施加（脚本01-05 in 模块3）
- W7：FVA批量运行（HeLa对照条件）
- W8：METAFlux基线环境搭建 + HeLa scRNA-seq数据获取

**M3（W9-W12）：首次验证实验**
- W9-10：获取bulk验证数据，构建参考通量方向向量
- W11：首次计算r值（期望第一个有意义的数字出现）
- W12：METAFlux完整运行，首次三方对比

**M4（W13-W16）：迭代优化**
- W13：参数敏感性分析，优化theta和coverage阈值
- W14：单细胞异质性分析
- W15-16：如果r<0.5，诊断原因（mapping错误？归一化问题？子网络选择？）

**M5（W17-W20）：巩固与可视化**
- W17-18：所有图表制作
- W19：方法论文写作（Introduction + Methods）
- W20：内部预审（实验室组会）

**M6（W21-W24）：Go/No-Go评估**
- W21：最终统计分析，Go/No-Go评估
- W22-24：如Go → 写作完整AC稿 + 决策升NatMethods路径

---

## 9. 风险与应对

**风险1：73个代谢物mapping率过低（<40%）**
- 触发条件：直接mapping失败，三级匹配后仍<30个代谢物在子网络中
- 应对：退守核心代谢物子集（仅使用糖酵解+TCA的15-20个代谢物，但这些覆盖率应>60%）

**风险2：HT SpaceM数据未公开**
- 触发条件：文章发表但数据在Data Availability中说"available on reasonable request"
- 应对：M1 W1立即发送邮件给Alexandrov组，同时准备替代数据集（如Rappez et al. Nature Methods 2021的SpaceM原始数据，已公开）

**风险3：r值始终<0.3**
- 触发条件：M3结束后r<0.3，且参数优化无效
- 应对1：检查bulk验证数据质量（参考方向是否可靠？）
- 应对2：退守"方向一致性"指标而非连续相关（只看符号是否相同）
- 应对3：如仍失败，考虑重新定位为方法论文（"分析MALDI单细胞代谢组学数据的框架"，不一定要比METAFlux强）

**风险4：METAFlux配套scRNA-seq数据与SpaceM不匹配**
- 触发条件：找不到与HT SpaceM同条件的HeLa scRNA-seq数据
- 应对：用不同条件的HeLa scRNA-seq，明确说明配对局限性；或退守到跨数据集的通路水平比较