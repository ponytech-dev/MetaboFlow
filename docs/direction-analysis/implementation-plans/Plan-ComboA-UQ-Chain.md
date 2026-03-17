# 组合A — 端到端UQ传播链 详细实施计划

---

## 总体定位

本项目的核心主张：代谢组学全流程中注释不确定性是一阶效应，而非可忽略的系统噪声。现有工具链在三个断点处丢失了这个信号：（1）注释步骤产出硬标签；（2）差异分析等权重处理所有特征；（3）通路分析用特征列表而非概率分布作输入。本框架在三个断点处各自植入一个统计严格的模块，并证明端到端传播产生实质性的生物学结论差异。

---

## 1. 前期准备清单

### 1.1 操作系统与计算环境

- Linux (Ubuntu 22.04 LTS) 或 macOS 14+，禁止 Windows（Snakemake + Docker 兼容性问题）
- CPU：≥16核（Monte Carlo 1000次扰动并行需要）
- RAM：≥64GB（MTBLS214 + ST001050 同时加载时谱图矩阵约30GB）
- GPU：可选，仅用于CCS深度学习模型推断加速（Phase 1 CCS预测，A100可将推断从4h压到20min）
- 存储：≥500GB SSD（原始mzML + 谱图库索引 + 中间文件）
- Python版本：3.11（mapie、nonconformist库对3.12尚不稳定）
- R版本：4.3.x（limma 3.58+，IHW 1.28+）

### 1.2 Python依赖库

**核心算法层：**
```
numpy>=1.26, scipy>=1.12, pandas>=2.1
mapie>=0.8          # conformal prediction主框架
nonconformist>=2.1  # 备用CP实现，用于对比验证
scikit-learn>=1.4
torch>=2.2          # CCS预测模型（若用DeepCCS）
```

**质谱数据处理层：**
```
pyteomics>=4.7      # mzML解析、谱图操作
ms2deepscore>=2.0   # 谱图相似度神经网络评分
matchms>=0.26       # 候选注释检索、cosine matching
spectrum_utils>=0.4 # 谱图可视化
```

**统计与贝叶斯层：**
```
pymc>=5.10          # 贝叶斯通路模型（Phase 3）
arviz>=0.18         # MCMC诊断
statsmodels>=0.14   # 辅助统计
pingouin>=0.5       # 效应量计算
```

**生信数据库访问层：**
```
requests>=2.31
metabolomics-tools  # MetaboAnalyst API客户端
pubchempy>=1.0
```

**可视化层：**
```
matplotlib>=3.8, seaborn>=0.13
plotly>=5.18        # 交互式结果浏览
upsetplot>=0.9      # 多集合交叉可视化
```

### 1.3 R依赖包

```r
# 差异分析核心
limma (>=3.58)
edgeR (>=4.0)       # 负二项可比较基准

# FDR校正
IHW (>=1.28)        # Independent Hypothesis Weighting
qvalue (>=2.34)

# 元数据操作
dplyr, tidyr, ggplot2, patchwork
SummarizedExperiment (>=1.32)

# 通路分析基准
fgsea (>=1.28)      # GSEA基准对比
piano (>=2.6)       # 多基因集统计
```

### 1.4 工作流管理

- Snakemake 8.x：全流程DAG管理，支持断点续跑
- DVC (Data Version Control)：大文件（mzML、谱图库）版本追踪
- Git + GitHub：代码版本控制，分支策略：`main`稳定版、`dev`开发、`exp/{实验名}`各实验分支

### 1.5 数据库与索引基础设施

- SQLite 3.45+：本地候选注释缓存（避免每次重查HMDB API）
- HDF5（h5py）：大型矩阵存储（MS2谱图特征矩阵、CCS预测结果）
- Faiss 1.8+：谱图嵌入向量的近似最近邻检索（ms2deepscore嵌入空间检索）

---

## 2. 数据获取详细方案

### 2.1 NIST标准品数据（CP校准集核心）

**获取方式：**

NIST 20（NIST Mass Spectral Library 2020）是商业数据库，需机构授权购买（约$3,500/机构）。若无授权，有三条替代路径：

路径A（推荐，免费）：使用NIST提供的公开子集 + MassBank North America的NIST整合子集。
- URL：https://massbank.us/MassBank/
- 下载方式：`wget https://github.com/MassIVE/MassIVE-KB/releases/download/latest/massbank_us.msp`
- 格式：MSP（标准纯文本谱图格式）
- 包含约800个代谢物的MS2标准谱图，覆盖NIST20约40%

路径B：HMDB Experimental MS2（免费，覆盖更广）。
- URL：https://hmdb.ca/downloads
- 直接下载链接：https://hmdb.ca/system/downloads/current/hmdb_spectra.zip
- 格式：解压后为XML，需用`hmdb_parser.py`转为MSP/MGF

路径C（最优组合）：MassIVE-KB MS2标准谱图库。
- URL：https://massive.ucsd.edu/ProteoSAFe/static/massive-kb-libraries.jsp
- 文件：GNPS-LIBRARY.mgf（约15万条标准谱图）
- 下载命令：`wget https://gnps-external.ucsd.edu/gnpslibrary/GNPS-LIBRARY.mgf`

**格式化为CP校准集的步骤：**

1. 解析MSP/MGF，提取：precursor_mz、adduct、smiles/inchi、谱图峰列表
2. 用RDKit从SMILES计算精确分子量，验证precursor_mz一致性（过滤误差>5ppm的条目）
3. 按compound class（用ClassyFire API批量分类）分层抽样，构建calibration set（20%）和test set（80%）
4. CCS值从METLIN CCS数据库获取（https://metlin.scripps.edu/，免费注册后下载），或用AllCCS2预测（https://allccs.zhulab.cn/）

**可获得性评估：** 高。GNPS-LIBRARY + HMDB组合可获取约2万条高质量标准谱图，足够CP校准。

### 2.2 ST001050（糖尿病，189样本）

- 数据源：Metabolomics Workbench
- URL：https://www.metabolomicsworkbench.org/data/DRCCStudySummary.php?Mode=SetupStudyDetailsDisplay&studyid=ST001050
- 直接下载mzML：需注册账户，通过网页下载或API
- API下载命令：
  ```bash
  wget "https://www.metabolomicsworkbench.org/data/study_download.php?study_id=ST001050&format=mzML" -O ST001050_mzML.zip
  ```
- 数据格式：LC-MS正离子模式，mzML，约189个样本文件
- 附带元数据：CSV格式，包含糖尿病分组信息（T2D vs NGT vs IGT）
- 特征矩阵：若平台提供预处理结果，可直接使用；否则用MZmine3重新峰检测

**可获得性评估：** 高（Metabolomics Workbench公开数据集，无需申请）。

### 2.3 MTBLS214（结直肠癌，100样本）

- 数据源：MetaboLights EMBL-EBI
- URL：https://www.ebi.ac.uk/metabolights/MTBLS214
- 下载方式：
  ```bash
  # 使用MetaboLights官方下载工具
  pip install metabolights-utils
  mtbls download MTBLS214 --output ./data/MTBLS214/
  # 或FTP直接下载
  wget -r ftp://ftp.ebi.ac.uk/pub/databases/metabolights/studies/public/MTBLS214/
  ```
- 数据格式：mzML，LC-MS/MS，正负离子模式各50样本
- 注意事项：MTBLS214包含结直肠癌与健康对照，需检查ISA-Tab元数据文件确认分组标签

**可获得性评估：** 高（MetaboLights完全公开）。

### 2.4 Dunn CAMCAP（299样本）

- 全称：Cambridge Cancer Cohort (CAMCAP) metabolomics
- 数据源：需查证。Dunn组（Warwick）的CAMCAP数据有部分存放于：
  - MetaboLights（搜索CAMCAP相关研究：MTBLS1572或相关）
  - 若为前列腺癌亚组，原始论文（Dunn et al., Lancet Oncol）可能附有数据获取申请链接
- **风险评估：此数据集可获得性中等**，可能需要通过数据访问申请（DAA）。
- 备选方案：若无法获取，用MTBLS404（肺癌，338样本，完全公开）替代，科学等效性相近。
- 下载尝试命令：
  ```bash
  wget -r ftp://ftp.ebi.ac.uk/pub/databases/metabolights/studies/public/MTBLS1572/
  ```

### 2.5 GNPS谱图库索引建立

```bash
# 下载全部GNPS公开库
wget https://gnps-external.ucsd.edu/gnpslibrary/ALL_GNPS.mgf -O data/libraries/ALL_GNPS.mgf
# 约600MB，150,000条谱图

# 额外下载MassBank Europe
wget https://github.com/MassBank/MassBank-data/releases/latest/download/MassBank_NIST.msp -O data/libraries/massbank.msp

# 建立Faiss索引（用ms2deepscore嵌入）
python scripts/build_spectral_index.py \
    --input data/libraries/ALL_GNPS.mgf \
    --model ms2deepscore_model_v2.pt \
    --output data/libraries/gnps_faiss.index
```

### 2.6 HMDB数据库本地镜像

```bash
# 下载代谢物数据库（精确质量、结构、通路）
wget https://hmdb.ca/system/downloads/current/hmdb_metabolites.zip
unzip hmdb_metabolites.zip

# 下载代谢物-通路映射
wget https://hmdb.ca/system/downloads/current/hmdb_metabolites_xmls.zip  # 含pathway XML

# 解析为SQLite
python scripts/build_hmdb_sqlite.py \
    --xml hmdb_metabolites.xml \
    --output data/databases/hmdb.db
```

---

## 3. 全部脚本清单

### Phase 1脚本（M1-4，CP注释UQ）

**数据预处理层：**

`01_preprocess/convert_to_mzml.py`
- 功能：将原始厂商格式（.raw, .d）转为mzML
- 输入：原始质谱文件目录
- 输出：标准化mzML文件
- 依赖：msconvert（ProteoWizard，需Docker容器）

`01_preprocess/peak_detection.py`
- 功能：调用MZmine3（headless模式）做峰检测、对齐、gap-filling
- 输入：mzML目录 + MZmine3 batch XML配置
- 输出：feature_table.csv（样本×特征矩阵）+ feature_ms2.mgf（MS2谱图）
- 关键参数：mass tolerance 5ppm，RT tolerance 0.05min，最小峰强度1000

`01_preprocess/annotate_candidates.py`
- 功能：对每个特征生成候选注释集（m/z检索HMDB，MS2匹配GNPS库）
- 输入：feature_table.csv，feature_ms2.mgf，hmdb.db，gnps_faiss.index
- 输出：candidates.parquet（每行=一个特征×候选对，含cosine_similarity、delta_mz、candidate_smiles等）
- 策略：先m/z宽窗口检索（±10ppm），再MS2 cosine过滤（>0.3），每个特征保留top-20候选

`01_preprocess/predict_ccs.py`
- 功能：用AllCCS2或DeepCCS预测每个候选的理论CCS值
- 输入：candidates.parquet中的SMILES列
- 输出：candidates_with_ccs.parquet（新增predicted_ccs列）
- 注意：CCS预测在无实测数据时用于贝叶斯更新先验

**CP核心算法层：**

`02_cp/compute_conformity_scores.py`
- 功能：计算每个候选注释的conformity score（详见第4节算法设计）
- 输入：candidates_with_ccs.parquet，校准集标准品标注
- 输出：conformity_scores.parquet（每候选一个α值）
- 关键：这是Phase 1的核心脚本，约500行

`02_cp/calibrate_cp.py`
- 功能：在校准集上估计每个置信水平ε对应的分位数阈值τ(ε)
- 输入：conformity_scores.parquet（校准集子集），目标覆盖率列表[0.7,0.8,0.9,0.95]
- 输出：thresholds.json（{coverage: threshold}映射）

`02_cp/generate_prediction_sets.py`
- 功能：对测试集每个特征，用阈值τ生成prediction set（候选集合）
- 输入：conformity_scores.parquet（测试集），thresholds.json
- 输出：prediction_sets.parquet（每特征：候选列表、各候选概率分布、集合大小）
- 关键输出列：`annotation_set`（候选HMDB ID列表）、`top_annotation_prob`（最高置信候选的边际概率）

`02_cp/validate_coverage.py`
- 功能：验证CP覆盖率保证在独立测试集上是否成立（empirical coverage vs nominal coverage）
- 输入：prediction_sets.parquet，test_set_ground_truth.csv
- 输出：coverage_calibration_plot.pdf + coverage_table.csv

`02_cp/bayesian_ccs_update.py`
- 功能：用实测CCS（若有）做贝叶斯后验更新，修正各候选概率
- 输入：prediction_sets.parquet，measured_ccs.csv（实测CCS，部分特征有）
- 输出：prediction_sets_ccs_updated.parquet
- 注：详见第4节CCS贝叶斯公式

`02_cp/isomer_disambiguation.py`
- 功能：识别prediction set中存在同分异构体候选的模糊节点，构建同分异构体图
- 输入：prediction_sets_ccs_updated.parquet
- 输出：ambiguous_nodes.json（{feature_id: [isomer_candidates]}）

### Phase 2脚本（M4-9，加权差异分析）

`03_da/prepare_weights.py`
- 功能：从prediction_sets生成每个特征的注释概率权重向量
- 输入：prediction_sets_ccs_updated.parquet，β参数（或β学习模块输出）
- 输出：feature_weights.csv（feature_id × compound权重）

`03_da/learn_beta.py`
- 功能：数据驱动学习最优β参数（详见第4节）
- 输入：feature_weights候选序列，cross-validation split
- 输出：optimal_beta.json

`03_da/run_limma_weighted.R`
- 功能：以precision weights注入limma，执行加权线性模型差异分析
- 输入：feature_matrix.csv，feature_weights.csv，metadata.csv，design_matrix.csv
- 输出：limma_results.csv（logFC、t-stat、p-value、weight_used）
- 关键：这是Phase 2的核心R脚本，约300行

`03_da/run_ihw.R`
- 功能：用IHW对limma p值进行FDR校正，注释不确定性作协变量
- 输入：limma_results.csv
- 输出：ihw_results.csv（含adj.p.value、weight_ihw）

`03_da/isomer_signal_split.py`
- 功能：对同分异构体模糊节点，按注释概率分配差异信号（详见第4节）
- 输入：limma_results.csv，ambiguous_nodes.json，feature_weights.csv
- 输出：split_da_results.csv（模糊节点拆分后的差异分析结果）

`03_da/benchmark_comparison.R`
- 功能：与等权重limma、基础FDR方法对比，计算AUPR、FDR控制能力
- 输入：ihw_results.csv，baseline_limma_results.csv，ground_truth_labels.csv
- 输出：benchmark_table.csv + roc_curves.pdf

### Phase 3脚本（M9-12，通路贝叶斯传播）

`04_pathway/build_pathway_mapping.py`
- 功能：从HMDB/KEGG建立代谢物-通路概率映射（考虑prediction set的模糊性）
- 输入：prediction_sets_ccs_updated.parquet，hmdb_pathway.db
- 输出：probabilistic_pathway_map.json（{pathway_id: {compound_id: membership_prob}}）

`04_pathway/bayesian_pathway_scoring.py`
- 功能：Phase 3核心算法，Beta先验×差异似然→通路后验（详见第4节）
- 输入：split_da_results.csv，probabilistic_pathway_map.json，beta_prior_params.json
- 输出：pathway_posterior.csv（每通路：posterior_mean、posterior_CI_95、BF）
- 约600行，最复杂脚本

`04_pathway/monte_carlo_sensitivity.py`
- 功能：1000次扰动评估通路结论对注释不确定性的鲁棒性
- 输入：prediction_sets_ccs_updated.parquet，pathway_posterior.csv
- 输出：mc_sensitivity_results.h5（1000次结果的HDF5存储）+ sensitivity_summary.csv
- 注：支持并行（joblib，16核约6小时）

`04_pathway/pathway_visualization.py`
- 功能：通路网络可视化（节点=通路，边=共享代谢物，节点大小=后验概率，颜色=不确定性）
- 输入：pathway_posterior.csv，probabilistic_pathway_map.json
- 输出：pathway_network.html（Plotly交互式）+ pathway_network_static.pdf

### 端到端整合脚本

`05_e2e/run_full_pipeline.py`
- 功能：Snakemake DAG调用入口，端到端执行
- 输入：config.yaml（数据路径、超参数）
- 输出：全部结果文件

`05_e2e/compare_frameworks.py`
- 功能：系统对比本框架 vs MassID vs BAUM vs 传统流程，所有三个数据集上
- 输出：comprehensive_benchmark_table.csv

`05_e2e/reproduce_figures.py`
- 功能：从结果文件重现论文所有图表（Fig 1-7 + Supp）

### Snakemake工作流

`Snakefile`：主流程DAG，定义所有规则的输入输出依赖关系

`config/config.yaml`：超参数中央管理文件

---

## 4. 独创算法设计

### 4.1 Phase 1：Conformity Score计算公式

Conformity score衡量的是"候选注释有多符合观测证据"，高分=高符合=高conformity。对特征i的候选注释c，定义：

```
α(i,c) = w_ms2 · s_cos(i,c) + w_mz · f_mz(Δm/z(i,c)) + w_rt · f_rt(ΔRT(i,c)) + w_ccs · f_ccs(ΔCCS(i,c))
```

各项定义：

**谱图余弦相似度项：**
```
s_cos(i,c) = cos_similarity(MS2_observed_i, MS2_reference_c)
           ∈ [0, 1]
```
用matchms的modified cosine similarity（考虑中性丢失偏移），而非简单dot product。对低质量MS2（碎片数<3），此项设为0.5（保守估计）而非0。

**m/z匹配项：**
```
f_mz(Δm/z) = exp(-Δm/z² / (2·σ_mz²))
```
σ_mz由仪器校准数据估计，典型值=2ppm。Δm/z单位为ppm：
```
Δm/z = |m/z_obs - m/z_theoretical(c)| / m/z_theoretical(c) × 10^6
```

**保留时间项（仅当有RT预测模型时）：**
```
f_rt(ΔRT) = exp(-ΔRT² / (2·σ_rt²))
```
σ_rt由NIST标准品的RT预测误差分布估计。若无RT预测（跨平台数据），此项权重w_rt=0，其余权重归一化。

**CCS项：**
```
f_ccs(ΔCCS) = exp(-ΔCCS² / (2·σ_ccs²))
```
σ_ccs取AllCCS2模型报告的RMSE（实验值vs预测值约2-3%），即：
```
σ_ccs = 0.025 × CCS_predicted(c)
```

**权重设置（本文独创：自适应权重）：**
固定权重方案（基准）：w_ms2=0.5, w_mz=0.3, w_rt=0.1, w_ccs=0.1

独创的数据驱动权重：在校准集上用逻辑回归学习最优权重向量：
```
w* = argmax_{w} Σ_{i∈cal} log P(true_annotation | α(i,·;w))
```
约束：w_j ≥ 0，Σw_j = 1。这是本文独创点之一，将四维证据整合变为可学习问题。

**借鉴部分**：cosine similarity使用matchms（已有工具）；m/z高斯核是标准做法。
**独创部分**：四维证据联合conformity score定义；自适应权重学习；CCS贝叶斯更新（见下文）。

### 4.2 Phase 1：校准集划分策略

**核心问题：** CP的覆盖率保证需要校准集与测试集满足exchangeability。对代谢组学，随机划分会引入以下偏差：
- 同一化合物类可能在校准集和测试集中都有代表
- 导致coverage在测试集上虚高（结构相似的化合物天然conformity score相近）

**策略选择：化学骨架分层划分（Scaffold Split变体）**

1. 对所有标准品化合物，用RDKit的Bemis-Murcko scaffold提取骨架
2. 按骨架分组，组内随机，组间split（80%训练校准，20%测试）
3. 额外约束：每个ClassyFire大类（lipid, amino acid, carbohydrate等）在校准集和测试集中均有代表（最小5个化合物/类）

**为何不用随机split：** 代谢组学实际应用中，测试集（真实样本中的代谢物）不会和校准集（NIST标准品）有已知的化学相似性，scaffold split更接近实际的exchangeability假设。

**CP理论保证：** 在split conformal prediction框架下，coverage保证对任意单个测试点成立，不需要测试集和校准集完全同分布，只需要exchangeable。Scaffold split保守，所以实际coverage会略高于nominal，这对科学应用是可接受的（覆盖率超出比不足更好）。

### 4.3 Phase 1：CCS贝叶斯更新完整公式

当特征i有实测CCS值（来自ion mobility数据，如DTIMS、TIMS-TOF）时，用贝叶斯更新修正各候选的概率权重。

设特征i有K个候选注释 {c_1, ..., c_K}，初始概率为CP给出的边际概率 {p_1^(0), ..., p_K^(0)}（由prediction set成员权重归一化得到）。

**先验：** p_k^(0) 即为先验（CP已整合了MS2+m/z证据）

**似然：** 实测CCS给出候选c_k的似然。设实测CCS为CCS_obs，候选c_k的理论CCS为CCS_pred(c_k)，误差模型：
```
CCS_obs | c_k ~ Normal(CCS_pred(c_k), σ_ccs²)
```
其中σ_ccs = 0.025 × CCS_pred(c_k)（相对误差2.5%，来自AllCCS2验证集）

因此：
```
L(c_k | CCS_obs) = (1/√(2π)σ_k) · exp(-(CCS_obs - CCS_pred(c_k))² / (2σ_k²))
```
其中σ_k = 0.025 × CCS_pred(c_k)

**后验更新（贝叶斯公式）：**
```
p_k^(posterior) = [p_k^(0) · L(c_k | CCS_obs)] / [Σ_j p_j^(0) · L(c_j | CCS_obs)]
```

**边界处理：**
- 若CCS_obs缺失（大多数LC-MS数据），p_k^(posterior) = p_k^(0)，不做更新
- 若某候选无CCS预测（SMILES无效），该候选的CCS似然设为均匀分布（似然=1/range_CCS），退化为不提供信息的弱先验

**独创性：** 将CCS贝叶斯更新作为CP之后的后处理步骤，而非并行证据源，是本文的独创结构。现有工具（如MetFrag、SIRIUS）通常把CCS作为另一个打分维度，但不维持概率归一化。

### 4.4 Phase 2：β参数选择

权重函数 w_i = p_i^β 的β控制权重分配的"激进程度"：
- β=0：所有特征等权重（退化为传统方法）
- β=1：权重线性正比于注释概率
- β>1：高置信特征获得超线性强化，低置信特征被强烈压缩
- β<0：反转（不合理，禁止）

**β的数据驱动选择方案（本文独创的核心设计）：**

用留一法交叉验证在模拟ground truth上选β：

1. 在NIST标准品数据集上，人工构造已知差异代谢物的"spike-in"实验：
   - 取50个高置信注释的标准品（CP score>0.9）
   - 取50个低置信注释的标准品（CP score 0.3-0.5）
   - 每次随机混入5%浓度差异（模拟case/control信号）
2. 对β ∈ {0, 0.5, 1, 1.5, 2, 3}，运行加权limma
3. 评估指标：AUPR（area under precision-recall curve），用已知spike-in特征作ground truth
4. 选AUPR最大的β

**理论指导：** β=1是期望无偏估计（权重=概率），但在finite sample下，β略>1能提高signal-to-noise（类似软阈值效应）。预期最优β在1.0-1.5之间（基于模拟实验预判）。

**额外设计：特征类别自适应β**

进一步，对不同化合物类可以使用不同β：
- 脂质类：CP score分布偏低（大量同分异构体），用更激进的β（~1.5）
- 氨基酸类：CP score分布偏高，用β=1.0
- 这个扩展作为Supplementary方法，主文图中用单一最优β

### 4.5 Phase 2：limma precision weights注入的具体R代码逻辑

```r
# 核心逻辑（约50行关键代码）

# 1. 构建特征权重矩阵
# feature_weights: n_features × 1 向量（每个特征对应其top-1候选的注释概率）
load_annotation_weights <- function(prediction_sets_path, beta) {
  ps <- read_parquet(prediction_sets_path)
  weights <- ps %>%
    group_by(feature_id) %>%
    summarise(top_prob = max(annotation_prob)) %>%
    mutate(w = top_prob^beta)
  return(weights$w)
}

# 2. limma加权线性模型
run_weighted_limma <- function(expr_matrix, design, weights_vec) {
  # expr_matrix: log2-transformed feature intensity matrix (features × samples)
  # design: model.matrix(~group + batch + ...)
  # weights_vec: 长度=n_features，每个特征一个权重
  
  # 关键：limma的weights参数接受两种形式
  # (a) 样本权重：weights矩阵(n_features × n_samples)
  # (b) 特征权重：我们用的形式，通过arrayWeights传入
  
  # 方案：将注释置信度权重作为"prior variance"调节
  # limma的voom等效设计：精度权重注入precision参数
  
  fit <- lmFit(
    object = expr_matrix,
    design = design,
    weights = matrix(
      rep(weights_vec, ncol(expr_matrix)),
      nrow = length(weights_vec),
      ncol = ncol(expr_matrix)
    )
  )
  # weights矩阵含义：第i行第j列=特征i在样本j的权重
  # 对注释置信度：所有样本j的权重相同（=p_i^beta），按行重复
  
  fit2 <- eBayes(fit, trend = TRUE, robust = TRUE)
  # trend=TRUE: 方差趋势建模（对强度依赖的噪声）
  # robust=TRUE: 对离群特征（如低置信注释的假差异）更鲁棒
  
  results <- topTable(fit2, coef = "groupCase", n = Inf, sort.by = "none")
  return(results)
}

# 3. 验证权重确实生效
# 对比有/无权重的t统计量相关性
# 预期：高置信特征的t统计量在加权vs等权中高度相关；低置信特征显著变化
```

**数学原理：** limma的precision weight w_i进入加权最小二乘目标函数：
```
β_hat = (X^T W X)^{-1} X^T W y
```
其中W = diag(w_1, ..., w_n) × I_samples。高权重特征的残差被放大惩罚，本质上是给高置信注释更大的"发言权"。

### 4.6 Phase 2：IHW协变量选择

IHW的核心思想：用独立于p值的协变量给假设分层，不同层使用不同的α阈值，总体上控制全局FDR。

**协变量选择方案（多协变量组合）：**

主协变量：`annotation_confidence = top_annotation_prob`（0-1连续值）
- 理由：高置信注释的假阳性注释概率低，可以用更激进的FDR阈值；低置信注释的假阳性多，需要保守阈值
- 独立性验证：注释置信度来自质谱证据（MS2 conformity），与差异分析p值（来自强度分布）统计独立——这是IHW使用的理论前提

辅助协变量：`feature_intensity_mean`（样本内均值，对数空间）
- 低强度特征通常MS2质量差，注释不确定性高，检验效能低
- 与p值在零假设下独立（功效的独立性）

**实现：**
```r
library(IHW)
ihw_result <- ihw(
  pvalues = limma_results$P.Value,
  covariates = limma_results$annotation_confidence,  # 主协变量
  alpha = 0.05,
  covariate_type = "ordinal",  # 连续→分箱处理，IHW自动选bin数
  nbins = 10  # 分10层，每层约500-2000特征
)
```

**为何IHW优于BH/qvalue：** BH假设所有假设等价（等功效、等先验概率），对代谢组学不成立——高置信注释的先验H_1概率更高，应该用更宽松的阈值。IHW恰好实现了这个直觉的严格统计版本。

### 4.7 Phase 2：同分异构体模糊节点的数学定义和差异信号分配

**数学定义：**

若特征i的prediction set包含至少两个同分异构体（相同分子式，不同结构），定义该特征为模糊节点：
```
IsAmbiguous(i) = |{c ∈ PS(i) : ∃c' ∈ PS(i), MF(c) = MF(c'), c ≠ c'}| ≥ 2
```
其中MF(c)为候选c的分子式，PS(i)为特征i的prediction set。

对模糊节点i，设其同分异构体候选集为 {c_1, ..., c_K}，各候选在prediction set中的条件概率为 {q_1, ..., q_K}（归一化到同分异构体子集）：
```
q_k = p_k / Σ_{j: MF(c_j)=MF(c_k)} p_j
```

**差异信号分配公式：**

特征i的差异分析结果（逻辑FC、t统计量）需要分配给各同分异构体候选。定义"等效差异贡献"：

```
logFC_attributed(c_k | i) = logFC(i) × q_k
```

对t统计量，采用保守方案：
```
t_attributed(c_k | i) = t(i) × √q_k
```
（√q_k而非q_k，因为t统计量的信噪比尺度是标准差而非方差，概率的信息贡献按√比例缩放）

对p值分配，不能直接乘以概率（p值不线性）。改用：
```
p_attributed(c_k | i) = 1 - q_k × (1 - p(i))
```
含义：若q_k=1（确定是c_k），p_attributed=p(i)；若q_k=0，p_attributed=1（无差异信号）。

**后续通路分析使用：** 对通路j包含同分异构体c_k的情况，使用p_attributed(c_k|i)和logFC_attributed(c_k|i)，而非特征i的原始结果。这是本文Phase 2→Phase 3衔接的关键接口。

**典型案例：亮氨酸/异亮氨酸（Leu/Ile）**
分子式均为C6H13NO2，m/z=132.1019（[M+H]+）。LC通常不完全分离。若RT给出分离证据，则CCS不同（AllCCS2预测：Leu~133 Å², Ile~130 Å²）可进一步区分。这个案例将在Fig 5作为具体演示。

**磷脂同分异构体案例：** PC(36:4)的双键位置同分异构体（n-3 vs n-6脂肪酸），MS2可用sn-position特征碎片离子区分，但常规注释不区分。这是脂质组学中最重要的模糊节点类型。

### 4.8 Phase 3：Beta先验参数设定

通路差异分析的贝叶斯模型框架：

设通路j包含代谢物集合 M_j（概率成员关系，见Phase 2输出）。通路j的"活跃程度"θ_j（0=完全不活跃，1=完全活跃）的先验：

```
θ_j ~ Beta(α_j, β_j)
```

**先验参数 α_j, β_j 的设定策略（分层贝叶斯）：**

不设单一固定先验，而是从数据中估计超先验：

```
α_j = μ_j × φ
β_j = (1 - μ_j) × φ
```

其中：
- μ_j：通路j的先验活跃概率（超先验均值）
- φ：精度参数（集中度，φ越大先验越紧）

μ_j的估计来源：
1. 若通路j在之前某数据集（跨队列先验）中显著，μ_j取该数据集的q值转换（μ_j = 1 - q_value）
2. 若无先验信息，均匀先验μ_j = 0.5（弱信息先验）

φ的估计：用Empirical Bayes在当前数据集上估计：
```
φ = argmax_φ Σ_j [log Beta(α_j(φ), β_j(φ)) | data]
```
用L-BFGS优化（scipy.optimize），约10秒收敛。

**差异信号似然（加权）：**

对通路j，其"观测到的差异信号"D_j来自属于该通路的特征的差异分析结果：

```
D_j | θ_j ~ Mixture(
  θ_j × HalfNormal(σ_signal²) + (1-θ_j) × Normal(0, σ_null²)
)
```

其中特征的贡献按注释概率加权：
```
D_j = Σ_{i: compound(i)∈M_j} q_{i→j} × |logFC(i)| / se(i)
```
q_{i→j} = P(feature i属于通路j，考虑同分异构体模糊性)

**后验推断：** 用NUTS采样（PyMC），每通路500次warm-up + 1000次sampling，约200个通路可在3小时内完成（16核并行）。

### 4.9 Phase 3：Monte Carlo Sensitivity的具体扰动策略

**目标：** 验证通路结论对注释不确定性的鲁棒性——哪些通路结论稳定，哪些依赖于特定注释假设？

**1000次扰动设计（三层嵌套扰动）：**

扰动层1（注释重采样，主效应，占700次）：
- 对每个特征i，从其prediction set按概率分布重采样一个注释候选
- 用重采样注释重建特征矩阵→重跑差异分析→重跑通路分析
- 量化：通路j的稳定性 = P(通路j在重采样实验中显著)

扰动层2（β扰动，次效应，占200次）：
- β从最优值β*出发，在±0.5范围内均匀采样
- 评估通路排名在β变化下的Spearman相关性（理想值>0.9）

扰动层3（校准集子集扰动，100次）：
- 随机移除20%校准集化合物，重新运行CP
- 评估coverage guarantee的稳定性（±2%以内可接受）

**扰动结果汇总：**
- 稳定通路（Tier 1）：在>80%扰动下显著，结论置信
- 半稳定通路（Tier 2）：50-80%，需交叉队列验证
- 不稳定通路（Tier 3）：<50%，报告为"注释依赖性结论"

**与现有方法的区别：** BAUM用jackknife敏感性分析，但不重采样注释集。本文的扰动直接模拟注释决策的不确定性，是更直接的sensitivity测试。

### 4.10 借鉴vs独创摘要表

| 组件 | 借鉴来源 | 本文独创点 |
|------|---------|----------|
| Cosine similarity | matchms | 四维证据联合conformity score |
| Split conformal prediction框架 | Venn & Gammerman 2005, Angelopoulos 2023 | 代谢组学适配（scaffold split，化学空间exchangeability分析） |
| CCS预测 | AllCCS2 | CCS贝叶斯后验更新作为CP后处理步骤 |
| limma加权线性模型 | limma包（Smyth 2004） | 注释概率作为precision weight的具体注入方案 |
| IHW FDR校正 | Ignatiadis et al. 2016 | 注释置信度作为IHW协变量（新的协变量选择） |
| Beta先验贝叶斯模型 | 通用贝叶斯框架 | 注释概率加权的通路贡献D_j定义；分层先验的φ估计 |
| Monte Carlo敏感性 | 通用MC方法 | 三层嵌套扰动策略；注释重采样与β扰动解耦 |
| 同分异构体处理 | MetFrag部分设计 | 信号分配公式（t统计量按√q_k缩放） |

---

## 5. 实验设计

### 5.1 全部实验列表

**Phase 1验证实验（M3-4）：**

实验P1-A：CP覆盖率校准验证
- 目标：证明在标准品测试集上，nominal coverage（如90%）≈ empirical coverage（±2%）
- 变量：coverage level（70%,80%,90%,95%），化合物类（脂质/氨基酸/有机酸）
- 数据：NIST标准品（scaffold split后的测试集）
- 输出指标：empirical coverage vs nominal coverage曲线

实验P1-B：Prediction set大小与注释不确定性的关系验证
- 目标：验证预测集大小确实反映真实不确定性（大集合=高不确定性区域）
- 变量：化合物类，特征强度，MS2质量（碎片数）
- 数据：NIST标准品 + ST001050（前100个特征）

实验P1-C：CCS贝叶斯更新效果评估
- 目标：验证加入CCS后prediction set大小缩小比例，和top-1候选准确率提升
- 变量：是否使用CCS，CCS测量噪声水平（σ=1%,2.5%,5%）
- 数据：有CCS实测值的标准品子集（需从METLIN CCS数据库获取，约300-500个代谢物）

**Phase 2验证实验（M6-8）：**

实验P2-A：β选择实验（核心）
- 目标：用spike-in数据确定最优β
- 变量：β ∈ {0, 0.5, 1, 1.5, 2, 3}
- 数据：NIST标准品（人工spike-in差异）
- 输出：AUPR vs β曲线，确定β*

实验P2-B：与传统方法FDR控制对比
- 目标：在已知ground truth下，比较加权框架vs等权重框架的FDR控制（不能虚胖）
- 变量：样本量（50,100,189），差异倍数（FC=1.5,2,3）
- 基准：等权重limma+BH，等权重limma+qvalue，IHW（无注释权重）
- 输出：FDR控制误差（nominal vs actual FDR），真阳性数量

实验P2-C：ST001050真实差异分析
- 目标：在糖尿病队列上比较加权vs等权重发现的差异代谢物列表
- 变量：分析方法（本框架, MassID, 传统limma+BH）
- 输出：Venn图（三方法各自独有发现 + 共有发现），关注"本框架独有高置信发现"

实验P2-D：同分异构体信号分配案例研究
- 目标：展示Leu/Ile模糊节点的差异信号分配效果
- 案例化合物：至少3对同分异构体（Leu/Ile，PC同分异构体，HexCer同分异构体）
- 验证方式：与有真实分离能力的数据集（IM-MS数据）对比分配结果

**Phase 3验证实验（M10-11）：**

实验P3-A：通路后验vs传统通路富集对比（ST001050）
- 目标：展示本框架改变通路排名，关注"排名改变显著的通路"
- 输出：散点图（传统GSEA p值 vs 贝叶斯后验概率），标注发生排名翻转的通路

实验P3-B：Monte Carlo稳定性分类
- 目标：将全部通路分为Tier1/2/3，评估Tier1通路的跨队列一致性
- 跨队列验证：Tier1通路在ST001050中显著 → 检验在MTBLS214中是否一致
- 输出：一致性率（Tier1预期>70%，Tier3预期<40%）

实验P3-C：结直肠癌MTBLS214通路分析 + Dunn CAMCAP验证
- 目标：独立验证Phase 3框架的通路结论可重复性
- 变量：两个数据集独立运行，比较通路后验排名的Kendall τ

**端到端整合实验（M11-12）：**

实验E2E-A：端到端 vs 分段对比
- 目标：验证三阶段UQ传播确实比仅传播Phase1或仅传播Phase2更好
- 设计：4条pipeline（Full UQ传播，仅P1+P3无P2，仅P2+P3无P1，无任何UQ的baseline）
- 评估：通路后验的跨队列Kendall τ

实验E2E-B：与MassID、BAUM、传统流程的综合对比
- 数据：所有三个真实数据集
- 指标：Top-10通路重叠率（Jaccard），差异代谢物AUPR（若有GT），运行时间

### 5.2 Ground Truth构建策略

**策略一：NIST标准品真实注释（Phase 1 GT）**
- NIST标准品有确定的化学结构（CAS号），作为注释ground truth
- 要求：标准品的LC-MS实测数据，人工确认注释正确性（MSI Level 1）
- 用途：评估prediction set是否包含正确注释（coverage），以及错误注释的概率

**策略二：Spike-in模拟差异（Phase 2 GT）**
- 在同一样本中人工添加已知浓度的标准品混合物（模拟case/control差异）
- 若无湿实验条件，用计算spike-in：在feature matrix中对已知注释特征人工添加log(FC)~N(1,0.3)的随机差异
- 已知差异特征=1，未差异特征=0，作为标签评估AUPR

**策略三：跨队列一致性（Phase 3 GT）**
- 没有通路差异分析的绝对GT，用跨独立队列一致性作为代理GT
- 逻辑：若某通路在两个独立糖尿病队列（ST001050 + CAMCAP）中均显著，则认为是真实生物学信号
- 用Tier1稳定通路 vs Tier3不稳定通路在跨队列一致性上的差异来验证MC稳定性分类的有效性

**策略四：文献已知通路（Phase 3 正向验证）**
- 糖尿病T2D：文献已知糖酵解、TCA循环、支链氨基酸代谢通路显著差异
- 结直肠癌：文献已知色氨酸代谢、胆碱磷脂代谢通路
- 要求本框架必须捕获这些文献共识通路（否则方法有问题），同时报告额外发现

### 5.3 同分异构体案例选择理由

**案例一：亮氨酸/异亮氨酸（氨基酸类）**
- 分子式C6H13NO2，完全同质量
- 代谢意义不同：Ile与支链氨基酸代谢（糖尿病相关），Leu与mTOR信号传导
- 把两者当一个特征处理 → 通路分析中给mTOR通路和支链氨基酸通路同时赋予半个信号
- 本框架通过RT差异（Leu和Ile在大多数LC柱上有0.1-0.3min分离）提高分辨概率

**案例二：PC(18:2/18:2) vs PC(18:1/18:3)（脂质类）**
- 总碳链完全相同，仅双键位置不同
- 常规注释均报告为PC(36:4)，无法区分
- 代谢意义：18:2是亚油酸（n-6），18:3是α-亚麻酸（n-3），参与不同炎症通路
- 用MS2的特征碎片离子差异（sn1/sn2 位置碎片）提供概率区分

**案例三：HexCer(d18:1/24:1) vs HexCer(d18:2/24:0)（鞘脂类）**
- 较难区分，演示本框架"诚实地报告不确定性"（prediction set保留两者）
- 展示MC扰动结果：依赖此注释的通路进入Tier3（不稳定）

---

## 6. 论文结构与图表详细规划

### 6.1 Main Text图表（Fig 1-7）

**Fig 1：概念图与框架概述（全页，双栏）**

Panel 1A（左上，流程图）：
- 传统流程 vs 本框架的对比示意图
- 左侧：硬注释→等权差异分析→特征列表→传统富集分析
- 右侧：CP预测集→加权差异分析→概率差异结果→贝叶斯通路分析
- 三个断点用红色X标记，三个修复点用绿色对号标记
- 风格：Biorender级别，清晰专业

Panel 1B（右上，数据分布图）：
- 真实数据中conformity score分布（用ST001050中所有特征的top-1候选CP score）
- 显示：约30%的特征CP score<0.5，说明"不确定性是普遍现象而非例外"
- x轴：CP score（0-1），y轴：特征密度

Panel 1C（左下，散点图）：
- x轴：CP score（注释置信度），y轴：差异分析logFC的绝对变化量（加权vs等权）
- 显示：低置信特征的logFC被显著压缩，高置信特征基本不变
- 说明：加权框架对不确定注释做了有意义的校正

Panel 1D（右下，通路排名图）：
- 展示3个通路在传统方法 vs 本框架中的排名变化（上升/下降各一个，稳定一个）
- 预告主要结论

**Fig 2：Phase 1 CP注释UQ（双栏）**

Panel 2A：CP校准曲线
- 8个化合物类（脂质、氨基酸、有机酸、核苷酸等）的单独校准曲线
- x轴：nominal coverage（0.7-0.99），y轴：empirical coverage
- 对角线=完美校准，本框架曲线应紧贴对角线（±2%以内）
- 与基准方法（简单阈值法、等权ranking）对比

Panel 2B：Prediction set大小分布
- 不同coverage水平（80%,90%,95%）下prediction set大小的箱线图
- 按化合物类分组
- 说明：不确定性高的化合物类（脂质）平均需要更大的prediction set

Panel 2C：CCS贝叶斯更新效果
- 散点图：有/无CCS更新的top-1准确率
- x轴：无CCS时的正确排名，y轴：有CCS后的正确排名
- 对角线以上的点=CCS更新改善了排名，关注从错误排名移到正确的案例

Panel 2D：四维conformity score权重的消融实验
- 4×2格子：移除每个维度（MS2/m/z/RT/CCS）后的coverage偏差
- 显示MS2是最重要维度，CCS在有实测值时贡献显著

**Fig 3：Phase 2 加权差异分析（双栏）**

Panel 3A：β选择实验结果
- x轴：β值，y轴：AUPR
- 曲线：三个数据集的β-AUPR曲线叠加
- 标记最优β*的位置（预期1.0-1.5）

Panel 3B：FDR控制对比
- 多方法（本框架，MassID，传统BH，qvalue）在不同样本量下的实际FDR
- 水平参考线：nominal FDR=5%
- 本框架应在nominal FDR下或接近，不能虚胖

Panel 3C：ST001050差异代谢物的Venn图
- 三个圆：本框架，MassID，传统limma+BH
- 标注各区域特征数量
- 重点讨论"本框架独有"区域的代谢物是否有生物学意义

Panel 3D：IHW协变量效应验证
- x轴：IHW中注释置信度层（低→高），y轴：每层使用的α阈值
- 显示高置信层获得更宽松阈值，低置信层更保守
- 验证IHW正确学习了注释置信度的信息价值

Panel 3E：同分异构体信号分配案例（Leu/Ile）
- 展示信号分配前后的差异：
  - 左：原始特征（Leu+Ile合并），logFC和p值
  - 右：分配后，Leu的部分信号（标注通路：mTOR），Ile的部分信号（标注通路：BCAA）

**Fig 4：Phase 3 通路贝叶斯传播（双栏）**

Panel 4A：传统GSEA p值 vs 贝叶斯后验概率散点图
- 每个点=一个通路（ST001050，约200个通路）
- 颜色：MC稳定性（Tier1/2/3）
- 框选排名发生翻转的通路（四个象限分别讨论）

Panel 4B：Beta先验vs后验的演示（选3个通路）
- 每行一个通路：先验分布（Beta曲线）+ 似然（差异信号直方图）+ 后验（更新后Beta曲线）
- 选有意义的三个：先验弱/后验强（数据驱动发现），先验强/后验维持（证实文献），先验弱/后验弱（排除噪声通路）

Panel 4C：Monte Carlo稳定性分布
- x轴：1000次扰动中通路显著的比例（0-100%）
- y轴：通路数量直方图
- 三个区域（<50%,50-80%,>80%）对应Tier3/2/1
- 显示生物学意义通路（糖酵解、TCA等）集中在Tier1

Panel 4D：Tier1通路跨队列一致性
- 热图：行=通路，列=数据集（ST001050, MTBLS214, CAMCAP）
- 颜色=后验概率（红/蓝=活跃/不活跃）
- Tier1通路应呈现高度一致的颜色模式

**Fig 5：同分异构体案例深入分析（单栏）**

Panel 5A：LC-MS特征图（Leu/Ile区域）
- 真实LC-MS色谱峰，显示两个共洗脱或部分分离的峰
- 标注prediction set成员（Leu: 65%概率，Ile: 35%概率）

Panel 5B：脂质同分异构体（PC(36:4)子集）
- MS2谱图：观测谱vs两个候选的理论谱
- 展示如何通过碎片离子区分n-3 vs n-6

Panel 5C：信号分配对通路的影响量化
- 条形图：不处理同分异构体 vs 处理后，mTOR通路和BCAA通路的后验概率变化
- 量化：信号分配带来多大通路推断差异

**Fig 6：端到端整合评估（双栏）**

Panel 6A：四条pipeline对比（消融实验）
- 雷达图或多维条形图：6个指标维度（覆盖率, FDR控制, AUPR, 跨队列一致性, 稳定通路数, 运行时间）
- 4条pipeline：Full UQ, 无P2, 无P1, 无任何UQ

Panel 6B：与竞争方法全面对比表
- 方法（行）×数据集+指标（列）的热图
- 行：本框架, MassID, BAUM, arXiv2026竞争者, 传统流程
- 每格颜色=在该指标上的排名

Panel 6C：计算效率分析
- 三个数据集（100,189,299样本）在不同并行核数下的运行时间
- 显示Phase 3的MC是主要瓶颈，但在16核下可接受

Panel 6D（可选）：软件包可用性展示
- 代码截图+GitHub star数+安装命令
- 展示易用性（3行代码运行完整pipeline）

**Fig 7：生物学发现（双栏，重量级图）**

这张图的定位是"展示框架能带来新的生物学洞见"，是Nature Methods论文的生物学价值证明。

Panel 7A：糖尿病T2D — 本框架发现的独特代谢重编程通路
- 通路网络图：节点=通路，边=共享代谢物，颜色=后验概率，大小=通路内代谢物数量
- 标注文献未报告但本框架Tier1稳定发现的通路（这是论文的核心生物学贡献）

Panel 7B：结直肠癌MTBLS214 — 比较本框架发现的通路和文献报告的差异
- 水平条形图：各通路的后验概率 vs 传统GSEA -log10(p)
- 颜色：是否在文献中有独立验证

Panel 7C：跨肿瘤 vs 糖尿病的通路对比（探索性）
- 展示框架的通用性：同样的代码，两个疾病，各自识别出疾病特异性通路模式

Panel 7D：框架发现的"不确定性高但生物学显著"的通路
- 这些通路在传统方法中因为注释不确定性被过滤或忽略
- 本框架通过概率处理"拯救"了这些通路
- 这是对"UQ传播有实质价值"最直接的论证

### 6.2 Supplementary Information规划

**方法补充（约15页）：**

Supp Methods S1：Conformal Prediction理论背景
- 覆盖率保证的完整数学证明（引用Angelopoulos 2023综述）
- Exchangeability假设在代谢组学中的适用性讨论

Supp Methods S2：四维conformity score的完整推导
- 包括自适应权重学习算法的完整伪代码
- 各维度权重的敏感性分析

Supp Methods S3：limma加权线性模型的精度权重数学推导
- 与普通limma的对比，证明在零假设下FDR控制仍有效

Supp Methods S4：IHW协变量选择的理论依据
- 注释置信度与差异p值的独立性验证（QQ图，相关系数）

Supp Methods S5：Beta先验参数的Empirical Bayes估计
- L-BFGS优化过程，收敛性验证

Supp Methods S6：Monte Carlo扰动协议的完整规范

**补充图表（约20张）：**

Supp Fig S1-S3：三个数据集的QC报告（PCA、batch effect评估、CV分布）

Supp Fig S4：NIST标准品校准集的化学多样性评估（化合物类分布，分子量分布）

Supp Fig S5：prediction set大小与信号强度、MS2碎片数的相关性

Supp Fig S6：β-AUPR曲线（各化合物类分层结果）

Supp Fig S7：IHW层级效应（每层实际FDR vs 分配α）

Supp Fig S8-S9：完整同分异构体案例（所有识别的模糊节点列表）

Supp Fig S10：MCMC诊断图（Rhat、有效样本数、trace plot）

Supp Fig S11：Monte Carlo敏感性的收敛性（100,500,1000次扰动的结果稳定性）

Supp Fig S12-S14：三数据集各自的完整通路后验概率表（Top-50通路）

Supp Fig S15：计算时间的详细分解（各脚本耗时）

Supp Fig S16：与arXiv 2026竞争者的具体差异（Phase 1层面的对比）

Supp Fig S17：软件包的安装和使用文档截图

**补充表格：**

Supp Table S1：三个数据集的基本统计信息

Supp Table S2：全部超参数列表和默认值

Supp Table S3：校准集化合物列表（HMDB ID，化合物类，conformity score分布）

Supp Table S4：ST001050差异代谢物完整表（本框架结果）

Supp Table S5：三数据集通路后验结果完整表（Tier分类）

Supp Table S6：竞争方法对比的完整数值结果

### 6.3 Discussion论证角度（回应Reviewer质疑）

**预期质疑1："CP覆盖率保证需要exchangeability，但真实代谢物与标准品不exchangeable。"**
回应策略：承认局限，给出量化评估。展示Supp Fig：在已知标准品的独立测试集（未参与校准）上，实际覆盖率偏差。讨论scaffold split如何最大化校准集和测试集的exchangeability。补充：CP在轻度exchangeability违反下仍然robustly控制coverage（引用Barber et al. 2023关于covariate shift下的CP）。

**预期质疑2："β的选择依赖于spike-in实验，而真实生物学中没有spike-in GT。"**
回应策略：直接承认，并论证：（1）β在[1.0,1.5]范围内对最终结论不敏感（展示sensitivity分析），（2）跨数据集最优β的一致性（所有三个数据集最优β都落在相同区间），（3）理论上β=1是无偏期望值，任何接近1的选择都是合理的。

**预期质疑3："贝叶斯通路模型需要MCMC，计算开销无法接受。"**
回应策略：给出精确计时（16核，200通路，3小时）。提供快速近似选项（变分推断，结果差异<5%，速度快10倍）。强调完整MCMC结果用于Figure，变分推断作为实用选项。

**预期质疑4："与BAUM的区别只是加了Phase 2？"**
回应策略：这是最重要的差异化论证。BAUM没有Phase 2（差异分析仍等权重），而差异分析是通路分析的上游，Phase 2的改变会propagate。用Fig 6A的消融实验直接回答：仅加Phase 2（无Phase 1）已经改变结果，但完整框架更好。端到端传播的价值超过各部分之和（非线性效应）。

**预期质疑5："你们没有用真实的IMS数据验证CCS贝叶斯更新。"**
回应策略：承认局限。NIST20有部分化合物有CCS实测值，用这个子集验证（Supp Fig）。对无实测CCS的数据，CCS更新退化为弱信息先验，不引入偏差（分析和展示）。未来工作：TIMS-TOF数据集的完整验证。

---

## 7. 关键变量与超参数列表

**Phase 1超参数：**

| 参数 | 默认值 | 范围/说明 |
|------|--------|---------|
| coverage_levels | [0.7, 0.8, 0.9, 0.95] | CP预测集的目标覆盖率 |
| max_candidates_per_feature | 20 | 每个特征保留的最大候选数 |
| min_cosine_similarity | 0.3 | MS2预筛选阈值 |
| mz_tolerance_ppm | 5 | 质量误差（ppm） |
| min_ms2_fragments | 3 | 最小碎片数（低于此值cosine设为0.5） |
| sigma_mz | 2 (ppm) | m/z高斯核宽度，由校准数据估计 |
| sigma_rt | 0.05 (min) | RT高斯核宽度，由标准品估计 |
| sigma_ccs_relative | 0.025 | CCS相对误差，由AllCCS2验证集确定 |
| scaffold_split_test_ratio | 0.2 | 标准品测试集比例 |
| w_ms2, w_mz, w_rt, w_ccs | [0.5, 0.3, 0.1, 0.1] | conformity score权重（自适应学习后可能更新） |

**Phase 2超参数：**

| 参数 | 默认值 | 范围/说明 |
|------|--------|---------|
| beta | 1.0 (初始) | 权重函数指数，由spike-in实验确定 |
| beta_search_grid | [0, 0.5, 1, 1.5, 2, 3] | β选择实验的搜索格点 |
| limma_trend | TRUE | 强度依赖方差趋势 |
| limma_robust | TRUE | 鲁棒eBayes |
| ihw_alpha | 0.05 | IHW全局FDR阈值 |
| ihw_nbins | 10 | IHW分层数（注释置信度层数） |
| min_confidence_for_analysis | 0.1 | 低于此注释置信度的特征排除 |

**Phase 3超参数：**

| 参数 | 默认值 | 范围/说明 |
|------|--------|---------|
| prior_precision_phi | 由EB估计 | Beta先验精度参数 |
| default_prior_mean | 0.5 | 无先验信息时的默认先验均值 |
| mcmc_warmup | 500 | NUTS热身步数 |
| mcmc_samples | 1000 | NUTS采样步数 |
| mcmc_chains | 4 | 并行链数 |
| n_mc_perturbations | 1000 | Monte Carlo扰动次数（层1:700, 层2:200, 层3:100） |
| tier1_threshold | 0.8 | MC稳定性Tier1阈值 |
| tier2_threshold | 0.5 | MC稳定性Tier2/3分界 |
| min_pathway_size | 3 | 最小通路代谢物数（过滤太小通路） |
| max_pathway_size | 200 | 最大通路代谢物数（过滤太大非特异通路） |

**全局系统参数：**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| n_parallel_jobs | 16 | 并行线程数（MC扰动） |
| random_seed | 42 | 所有随机过程的种子 |
| log_transform | log2 | 强度变换 |
| normalization_method | PQN | Probabilistic Quotient Normalization |
| batch_correction_method | ComBat | 若有批次效应 |
| mz_database_ppm_window | 10 | 数据库检索窗口（比conformity score更宽，候选生成阶段） |

---

**里程碑时间线总结：**

M1-2（1-2月）：环境搭建，数据获取，谱图库索引建立，峰检测（运行MZmine3）

M3-4（3-4月）：Phase 1算法实现，conformity score调试，CP校准，P1-A/B/C实验完成

M5-6（5-6月）：Phase 2核心实现（limma权重注入 + IHW），β选择实验，同分异构体图构建

M7-8（7-8月）：Phase 2完整验证（P2-A至P2-D），与MassID对比，代码重构和文档化

M9-10（9-10月）：Phase 3实现（贝叶斯通路模型 + MC sensitivity），P3-A/B实验

M11（11月）：端到端整合实验，E2E-A/B，与BAUM对比，图表草稿

M12（12月）：论文写作，审稿人预演（内部讨论），代码开源准备，提交