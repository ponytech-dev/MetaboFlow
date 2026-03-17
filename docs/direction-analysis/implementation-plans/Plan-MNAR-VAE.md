# MNAR-VAE化学先验缺失值填补：详细实施计划

## 项目概览

**目标期刊**：Analytical Chemistry（ACS，IF ~7.4）  
**完成周期**：8个月（2026年3月 → 2026年11月）  
**核心创新**：CP-MNAR-VAE（Chemical Prior Missing Not At Random Variational Autoencoder）

---

## 1. 前期准备清单

### 1.1 计算环境搭建（第1周）

**操作系统**：Ubuntu 22.04 LTS（推荐）或 macOS 14+  
**硬件要求**：GPU ≥ 16GB VRAM（A100/RTX 4090），RAM ≥ 64GB，存储 ≥ 500GB SSD

**步骤1：Conda环境创建**
```
conda create -n mnar_vae python=3.10
conda activate mnar_vae
```

**步骤2：核心PyTorch生态**
```
conda install pytorch==2.2.0 torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia
pip install torch-geometric==2.5.0
```

**步骤3：科学计算与生物信息学**
```
pip install numpy==1.26.0 pandas==2.2.0 scipy==1.12.0 scikit-learn==1.4.0
pip install statsmodels==0.14.1 pingouin==0.5.4
pip install pyopenms==3.1.0          # 质谱数据解析
pip install ms2ml==0.1.0             # 代谢组学工具
pip install rdkit==2023.9.5          # 化学结构计算
pip install pubchempy==1.0.4         # PubChem API Python封装
pip install requests==2.31.0 aiohttp==3.9.0  # HMDB批量请求
```

**步骤4：深度学习辅助**
```
pip install pytorch-lightning==2.2.0
pip install optuna==3.6.0            # 超参数搜索
pip install wandb==0.16.0            # 实验追踪
pip install einops==0.7.0            # tensor操作
```

**步骤5：可视化**
```
pip install matplotlib==3.8.0 seaborn==0.13.0 plotly==5.19.0
pip install scienceplots==2.1.0      # Nature风格
pip install upsetplot==0.9.0         # 缺失模式可视化
```

**步骤6：统计分析**
```
pip install pydeseq2==0.4.4          # 差异分析（下游验证）
pip install mrmr-selection==0.2.6    # 特征选择
pip install umap-learn==0.5.6
```

**步骤7：基线方法安装**
```
# R环境（QRILC、GSimp需要）
conda install -c conda-forge r-base=4.3.0
Rscript -e "install.packages(c('imputeLCMD', 'missForest', 'VIM', 'GSimp'))"
pip install rpy2==3.5.15             # Python调用R
```

**步骤8：项目结构初始化**
```
mkdir -p cp_mnar_vae/{data/{raw,processed,chemical},models,experiments,scripts,figures,results}
cd cp_mnar_vae && git init
```

**步骤9：配置文件**  
创建 `config/default.yaml`，涵盖数据路径、模型超参数、训练参数、实验参数。

---

### 1.2 文献调研（第1-2周，并行于环境搭建）

**必读核心文献（按优先级）**：

1. MMISVAE：Wang et al. (2024)，*Nature Methods*，理解基线架构
2. QRILC：Lazar et al. (2016)，*Molecular & Cellular Proteomics*，最重要MNAR基线
3. GSimp：Wei et al. (2018)，*PLOS Computational Biology*，Gibbs采样MNAR
4. missForest：Stekhoven & Bühlmann (2012)，*Bioinformatics*
5. VAE原论文：Kingma & Welling (2013)，理解ELBO推导
6. Cross-attention：Vaswani et al. (2017) + Flamingo (2022)，理解cross-modal attention
7. MNAR理论：Little & Rubin (2019)，*Statistical Analysis with Missing Data*，第4版
8. 代谢组学缺失机制：Gromski et al. (2014)，*Analytica Chimica Acta*

**文献管理**：Zotero + Obsidian笔记，建立知识图谱。

---

### 1.3 基线代码复现准备（第2周）

- 下载MMISVAE官方仓库（GitHub: luoyuanlab/MMISVAE），运行其demo，理解输入格式
- 测试QRILC/GSimp R包在标准数据集上的运行
- 验证RDKit能正确计算logP、MW、TPSA（用已知化合物做验证）

---

## 2. 数据获取详细方案

### 2.1 五个数据集

#### 数据集1：MTBLS1（MetaboLights Study 1）

**来源**：MetaboLights数据库（EBI托管）  
**URL**：`https://www.ebi.ac.uk/metabolights/MTBLS1`  
**直接下载**：
```
wget https://www.ebi.ac.uk/metabolights/MTBLS1/files/m_mtbls1_metabolite_profiling_NMR_spectroscopy_v2_mzq.xml
# 或通过FTP
ftp ftp.ebi.ac.uk/pub/databases/metabolights/studies/public/MTBLS1/
```
**文件格式**：ISA-Tab格式（investigation/study/assay .txt文件）+ mzXML原始数据  
**预期大小**：~150MB  
**样本量**：132个人血清样本（健康vs代谢综合征）  
**特征数**：约132个已注释代谢物  
**可获取性**：★★★★★（公开无需申请）  
**注意**：使用已处理的峰面积矩阵（`s_MTBLS1.txt` + `a_MTBLS1_*.txt`），而非原始质谱文件

#### 数据集2：ST000001（Metabolomics Workbench）

**来源**：Metabolomics Workbench  
**URL**：`https://www.metabolomicsworkbench.org/data/DRCCStudySummary.php?Mode=SetupStudyAnalysis&StudyID=ST000001`  
**API下载**：
```python
import requests
url = "https://www.metabolomicsworkbench.org/rest/study/study_id/ST000001/datatable"
response = requests.get(url)
# 返回JSON格式的峰强度矩阵
```
**文件格式**：TSV/CSV，可通过REST API直接获取数值矩阵  
**预期大小**：~5MB（处理后矩阵）  
**样本量**：~34个小鼠肝脏样本  
**特征数**：~188个代谢物  
**可获取性**：★★★★★（REST API完全公开）

#### 数据集3：MTBLS2（MetaboLights）

**URL**：`https://www.ebi.ac.uk/metabolights/MTBLS2`  
**FTP**：`ftp://ftp.ebi.ac.uk/pub/databases/metabolights/studies/public/MTBLS2/`  
**文件格式**：ISA-Tab + mzXML  
**预期大小**：~2GB（含原始文件）；处理后矩阵~10MB  
**样本量**：约60个样本（类风湿关节炎队列）  
**特征数**：~200个代谢物  
**可获取性**：★★★★★（公开）  
**注意**：需要从ISA-Tab中解析峰面积矩阵，建议使用`isatools` Python包

#### 数据集4：Dunn CAMCAP（剑桥癌症队列）

**来源**：Dunn et al. (2011) *Metabolomics*；Cambridge Cancer Cohort  
**原始文献**：DOI 10.1007/s11306-011-0276-5  
**获取方式**：  
- 首选：MetaboLights补充数据，搜索关键词"CAMCAP Dunn"  
- 备选：直接邮件联系作者（Warwick B. Dunn，warwick.dunn@manchester.ac.uk）  
- 备选URL：`https://www.ebi.ac.uk/metabolights/` 搜索"CAMCAP"  
**文件格式**：Excel/CSV，已处理的峰面积矩阵  
**预期大小**：~20MB  
**样本量**：~170个血清样本（前列腺癌）  
**特征数**：~200个HILIC/RPLC特征  
**可获取性**：★★★（可能需要联系作者，或通过MetaboLights找到关联研究）  
**备选方案**：若无法获取，用MTBLS180（类似前列腺癌代谢组队列）替代

#### 数据集5：ImpLiMet数据集

**来源**：Wei et al. (2018) GSimp论文配套数据，或ImpLiMet工具测试数据  
**URL**：`https://github.com/KechrisLab/MSPrep`（含脂质组学测试数据）  
**或**：`https://github.com/WandeRum/GSimp/tree/master/data`（GSimp GitHub仓库附带）  
**文件格式**：RData / CSV  
**预期大小**：~2MB  
**样本量**：~40个样本（脂质组学，HILIC-MS）  
**特征数**：~150个脂质特征  
**可获取性**：★★★★（GitHub公开或论文补充材料）  
**注意**：此数据集的特点是已知MNAR缺失机制（低浓度截断），适合方法验证

---

### 2.2 化学属性数据获取

#### 2.2.1 HMDB批量获取

**HMDB提供的属性**：分子式、MW、logP（预测）、TPSA、极性、电荷、溶解度

**批量下载XML**：
```bash
# 下载HMDB全量代谢物XML（~8GB解压后）
wget https://hmdb.ca/system/downloads/current/hmdb_metabolites.zip
unzip hmdb_metabolites.zip
```

**Python解析脚本逻辑**（文件 `scripts/parse_hmdb.py`）：
```python
import xml.etree.ElementTree as ET

def parse_hmdb_xml(xml_path):
    """解析HMDB XML，提取化学属性"""
    tree = ET.parse(xml_path)
    root = tree.getroot()
    ns = {'hmdb': 'http://www.hmdb.ca'}
    
    records = []
    for metabolite in root.findall('hmdb:metabolite', ns):
        hmdb_id = metabolite.findtext('hmdb:accession', namespaces=ns)
        name = metabolite.findtext('hmdb:name', namespaces=ns)
        mw = metabolite.findtext('hmdb:average_molecular_weight', namespaces=ns)
        
        # 预测属性在predicted_properties节点
        pred_props = metabolite.find('hmdb:predicted_properties', ns)
        logP = None
        tpsa = None
        if pred_props:
            for prop in pred_props.findall('hmdb:property', ns):
                kind = prop.findtext('hmdb:kind', namespaces=ns)
                value = prop.findtext('hmdb:value', namespaces=ns)
                if kind == 'logP':
                    logP = float(value)
                elif kind == 'polar_surface_area':
                    tpsa = float(value)
        
        records.append({'hmdb_id': hmdb_id, 'name': name, 
                       'MW': float(mw) if mw else None,
                       'logP': logP, 'TPSA': tpsa})
    return records
```

#### 2.2.2 PubChem REST API批量获取

**PubChem提供**：MW、XLogP3（logP）、TPSA、HBD、HBA、形式电荷、旋转键数

**批量查询策略**（避免触发速率限制，max 5 req/s）：
```python
import requests
import time
from concurrent.futures import ThreadPoolExecutor

BASE_URL = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"

def get_properties_by_name(compound_name: str) -> dict:
    """通过化合物名称获取属性"""
    props = "MolecularWeight,XLogP,TPSA,HBondDonorCount,HBondAcceptorCount,Charge,RotatableBondCount"
    url = f"{BASE_URL}/compound/name/{compound_name}/property/{props}/JSON"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            data = r.json()
            return data['PropertyTable']['Properties'][0]
    except Exception:
        return {}

def get_properties_by_cid(cid: int) -> dict:
    """通过CID获取属性（更稳定）"""
    props = "MolecularWeight,XLogP,TPSA,HBondDonorCount,HBondAcceptorCount,FormalCharge"
    url = f"{BASE_URL}/compound/cid/{cid}/property/{props}/JSON"
    r = requests.get(url, timeout=10)
    return r.json()['PropertyTable']['Properties'][0] if r.status_code == 200 else {}

def batch_query_pubchem(compound_list: list, delay=0.2) -> list:
    """批量查询，限速"""
    results = []
    for compound in compound_list:
        result = get_properties_by_name(compound)
        results.append(result)
        time.sleep(delay)  # 5 req/s限制
    return results
```

**SMILES → RDKit计算（用于无PubChem记录的化合物）**：
```python
from rdkit import Chem
from rdkit.Chem import Descriptors, rdMolDescriptors

def calc_properties_rdkit(smiles: str) -> dict:
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return {}
    return {
        'MW': Descriptors.MolWt(mol),
        'logP': Descriptors.MolLogP(mol),
        'TPSA': rdMolDescriptors.CalcTPSA(mol),
        'HBD': rdMolDescriptors.CalcNumHBD(mol),
        'HBA': rdMolDescriptors.CalcNumHBA(mol),
        'RotBonds': rdMolDescriptors.CalcNumRotatableBonds(mol),
        'FormalCharge': Chem.GetFormalCharge(mol)
    }
```

#### 2.2.3 未注释特征的RT代理logP

**原理**：RPLC保留时间（RT）与logP高度相关（Pearson r通常 > 0.85）。用已注释特征的 (RT, logP) 对训练局部回归模型，预测未注释特征的logP。

**具体实现**：
```python
from sklearn.preprocessing import PolynomialFeatures
from sklearn.linear_model import Ridge
from sklearn.pipeline import Pipeline

def rt_to_logp_proxy(annotated_df, unannotated_df):
    """
    annotated_df: 含RT和logP的已注释特征
    unannotated_df: 只有RT的未注释特征
    """
    # 用多项式回归（2阶）拟合RT→logP关系
    X_train = annotated_df[['RT', 'MW']].values  # 加MW改善拟合
    y_train = annotated_df['logP'].values
    
    pipe = Pipeline([
        ('poly', PolynomialFeatures(degree=2)),
        ('ridge', Ridge(alpha=1.0))
    ])
    pipe.fit(X_train, y_train)
    
    X_pred = unannotated_df[['RT', 'MW']].values
    logP_proxy = pipe.predict(X_pred)
    
    # 报告拟合质量
    r2 = pipe.score(X_train, y_train)
    print(f"RT→logP回归 R²={r2:.3f}")
    return logP_proxy, pipe
```

**误差估计**：用5折CV评估RT代理logP的RMSE，在Discussion中报告此近似引入的不确定性。

---

### 2.3 数据预处理流程

**标准化步骤**（每个数据集统一执行）：

1. 过滤：移除>80%样本中缺失的特征；移除>50%特征缺失的样本
2. 对数变换：log2(x + min_positive_value / 2)
3. 中值归一化（跨样本）
4. 标注缺失模式：MCAR（通过Little's MCAR test）vs MNAR（低值截断检验）
5. 记录每个特征的实际缺失率、化学属性完整率

---

## 3. 全部脚本清单

### 3.1 数据处理脚本

**文件**：`scripts/01_download_data.sh`  
**功能**：自动下载5个数据集的原始文件  
**输出**：`data/raw/` 目录下各数据集文件夹  
**预计行数**：80行

**文件**：`scripts/02_parse_metabolights.py`  
**功能**：解析MetaboLights ISA-Tab格式，提取峰面积矩阵  
**输入**：`data/raw/MTBLS*/` 目录  
**输出**：`data/processed/{dataset}_peak_matrix.csv`（样本×特征）  
**预计行数**：200行

**文件**：`scripts/03_parse_workbench.py`  
**功能**：通过Metabolomics Workbench REST API下载并解析ST000001  
**输入**：Study ID列表  
**输出**：`data/processed/ST000001_matrix.csv`  
**预计行数**：120行

**文件**：`scripts/04_fetch_chemical_props.py`  
**功能**：批量查询HMDB + PubChem，收集化学属性；HMDB优先，PubChem补全，RDKit兜底  
**输入**：`data/processed/{dataset}_feature_list.csv`（含化合物名/HMDB ID/InChIKey）  
**输出**：`data/chemical/{dataset}_chem_props.csv`（含logP/MW/TPSA/HBD/HBA/charge）  
**预计行数**：350行

**文件**：`scripts/05_rt_proxy_logP.py`  
**功能**：为未注释特征用RT回归代理logP  
**输入**：`data/chemical/{dataset}_chem_props.csv`（部分特征logP缺失）  
**输出**：同文件，填补logP_proxy列，并报告R²  
**预计行数**：180行

**文件**：`scripts/06_preprocess_matrices.py`  
**功能**：统一预处理流程（过滤、log变换、归一化、缺失模式标注）  
**输入**：`data/processed/{dataset}_peak_matrix.csv`  
**输出**：`data/processed/{dataset}_processed.csv` + `{dataset}_missing_pattern.csv`  
**预计行数**：280行

**文件**：`scripts/07_simulate_mnar.py`  
**功能**：在完整（或几乎完整）数据上人工制造MNAR缺失，供有监督评估  
**输入**：完整度>70%的数据集子集  
**输出**：`data/processed/{dataset}_mnar_simulated.csv` + 真值矩阵  
**预计行数**：320行

**文件**：`scripts/08_build_dataset_splits.py`  
**功能**：生成train/val/test split（按样本，5折CV的fold分配），保存索引  
**输入**：处理后矩阵 + 化学属性  
**输出**：`data/splits/{dataset}_splits.json`  
**预计行数**：150行

### 3.2 模型脚本

**文件**：`models/chemical_encoder.py`  
**功能**：化学属性编码器模块（MLP，将化学向量编码为key/value矩阵）  
**输入**：化学属性向量（logP, MW, TPSA, HBD, HBA, charge）×6维  
**输出**：化学先验的K矩阵和V矩阵（各 d_chem 维）  
**预计行数**：120行

**文件**：`models/cross_attention.py`  
**功能**：多头Cross-Attention模块（代谢物特征 × 化学先验）  
**预计行数**：180行

**文件**：`models/encoder.py`  
**功能**：VAE编码器（含cross-attention化学注入），输出μ和logσ²  
**预计行数**：200行

**文件**：`models/decoder.py`  
**功能**：VAE解码器（含化学先验注入），输出重建强度 + MNAR概率头  
**预计行数**：200行

**文件**：`models/cp_mnar_vae.py`  
**功能**：完整模型封装，forward/encode/decode/impute接口  
**预计行数**：300行

**文件**：`models/loss_functions.py`  
**功能**：ELBO损失 + MNAR惩罚项 + 化学一致性正则化 + 观测似然  
**预计行数**：250行

**文件**：`models/mnar_mechanism.py`  
**功能**：MNAR概率建模模块（sigmoid函数映射 logP/MW → 检出概率）  
**预计行数**：150行

### 3.3 训练脚本

**文件**：`train.py`  
**功能**：主训练脚本，支持命令行参数，集成wandb日志  
**预计行数**：400行

**文件**：`train_baselines.py`  
**功能**：统一调用所有基线方法（kNN/QRILC/GSimp/missForest/MMISVAE），输出填补结果  
**预计行数**：350行

**文件**：`hyperopt.py`  
**功能**：Optuna超参数搜索，定义搜索空间，运行100次trial  
**预计行数**：250行

### 3.4 实验与评估脚本

**文件**：`experiments/eval_imputation.py`  
**功能**：计算NRMSE、MAE、Pearson r、SSIM等填补质量指标  
**输入**：真值矩阵 + 填补矩阵  
**输出**：`results/{exp_name}_metrics.json`  
**预计行数**：300行

**文件**：`experiments/ablation_study.py`  
**功能**：消融实验管理器，系统性移除各模块后重训  
**预计行数**：200行

**文件**：`experiments/downstream_analysis.py`  
**功能**：填补后的下游分析（PCA、差异代谢物、通路富集）  
**输入**：填补后矩阵 + 样本元数据  
**输出**：差异代谢物列表、通路p值、PCA图数据  
**预计行数**：400行

**文件**：`experiments/mnar_characterization.py`  
**功能**：描述每个数据集中MNAR模式与化学属性的关联（相关性分析、logistic回归）  
**预计行数**：280行

**文件**：`experiments/sensitivity_analysis.py`  
**功能**：对化学属性噪声/缺失的鲁棒性测试（逐步降低化学属性完整率）  
**预计行数**：200行

### 3.5 可视化脚本

**文件**：`figures/fig1_mnar_characterization.py` → Fig 1所有panels  
**文件**：`figures/fig2_model_architecture.py` → 架构示意图（matplotlib）  
**文件**：`figures/fig3_main_results.py` → 主实验结果热图+箱线图  
**文件**：`figures/fig4_ablation.py` → 消融实验结果  
**文件**：`figures/fig5_downstream.py` → 下游验证结果  
**文件**：`figures/fig6_case_study.py` → 案例分析  
各约150-250行。

---

## 4. 独创算法设计

### 4.1 CP-MNAR-VAE完整架构

**输入**：
- 代谢物强度矩阵 X ∈ ℝ^(N×M)，N个样本，M个特征
- 缺失掩码矩阵 O ∈ {0,1}^(N×M)，O_ij=1表示观测到
- 化学属性矩阵 C ∈ ℝ^(M×d_c)，d_c=6（logP, MW_norm, TPSA_norm, HBD, HBA, charge）

**架构总览**：

```
Chemical Encoder (per feature)
    C [M × 6] → [M × d_chem=64] (K矩阵) 
               → [M × d_chem=64] (V矩阵)

Encoder:
    X_obs (masked) [N × M] 
    → Feature Embedding [N × M × d_feat=128]
    → Cross-Attention (Q=X_emb, K=Chem_K, V=Chem_V) [N × M × d_feat=128]
    → Residual + LayerNorm [N × M × 128]
    → Flatten+Linear → [N × 512]
    → MLP(512→256→128)
    → μ [N × d_z=64], logσ² [N × d_z=64]

Reparameterization:
    z = μ + ε·exp(0.5·logσ²), ε ~ N(0,I)

Decoder:
    z [N × d_z=64]
    → Linear(64→128→256→512) [N × 512]
    → Reshape → [N × M × d_feat=128]
    → Cross-Attention (Q=z_emb, K=Chem_K, V=Chem_V) [N × M × 128]
    → Linear → X_recon [N × M]  (重建强度)
    → Linear → π [N × M]         (MNAR检出概率，sigmoid)

MNAR Mechanism Module (共享化学编码):
    C → f_mnar([logP, MW]) → p_detect [M]  (per-feature检出概率先验)
```

#### 4.1.1 化学编码器（Chemical Encoder）

**输入**：c ∈ ℝ^6（单个特征的化学属性向量）

**预处理**：
- logP：原始值（范围约-5到10）
- MW：(MW - 300) / 200（中心化，典型代谢物150-600 Da）
- TPSA：TPSA / 100
- HBD、HBA：整数，保持原值（范围0-10）
- charge：-2到+2的整数

**网络结构**：
```
Input: [6]
→ Linear(6, 64) + ReLU + LayerNorm
→ Linear(64, 128) + GELU + Dropout(0.1)
→ 分支1（Key分支）: Linear(128, d_chem=64)  → K
→ 分支2（Value分支）: Linear(128, d_chem=64) → V
```

对所有M个特征并行计算 → K ∈ ℝ^(M×64)，V ∈ ℝ^(M×64)

#### 4.1.2 特征嵌入层（Feature Embedding）

对观测到的强度值：
```
X_masked [N × M]（缺失位置填0）
→ Linear(1, d_feat=128) 逐特征嵌入（shared weights）
→ + 缺失标记嵌入: embed_mask = Linear(1, d_feat)(O_ij)
→ Feature Embedding E ∈ ℝ^(N×M×128)
```

**关键设计**：将缺失标记作为额外信号注入嵌入层，让模型区分"真零"和"缺失"。

#### 4.1.3 Cross-Attention化学先验注入

**Q/K/V的具体定义**：

在**编码器**中：
- **Q（Query）**：来自代谢物强度嵌入 E ∈ ℝ^(N×M×d_feat)，reshape为 (N·M) × d_feat，即每个样本-特征对作为一个query
- **K（Key）**：化学编码器输出的K矩阵，ℝ^(M×d_chem)，broadcast到 (N·M) × d_chem（按特征维度对齐）
- **V（Value）**：化学编码器输出的V矩阵，ℝ^(M×d_chem)

**数学表达**：
```
Attention(Q, K, V) = softmax(QW_Q · (KW_K)^T / √d_k) · VW_V
```
其中 W_Q ∈ ℝ^(d_feat×d_k)，W_K ∈ ℝ^(d_chem×d_k)，W_V ∈ ℝ^(d_chem×d_v)，d_k=d_v=64

**多头设置**：num_heads=4，每头维度=16

**注意力掩码**：O_ij用于mask缺失位置（编码器中缺失的特征不应贡献attention）

在**解码器**中：
- **Q**：来自解码的latent representation
- **K、V**：同上（化学编码器输出，权重与编码器共享）

**共享化学编码器的理由**：编码和解码过程应使用一致的化学先验表示，减少参数量，增强一致性。

#### 4.1.4 编码器MLP详细规格

```
Feature-wise attention输出: [N × M × 128]
→ Mean pooling over M（注意力加权平均，权重=观测掩码O）: [N × 128]
→ Linear(128, 512) + GELU + Dropout(0.1)
→ BatchNorm(512)
→ Linear(512, 256) + GELU + Dropout(0.1)
→ Linear(256, 128) + GELU
→ 分支: Linear(128, d_z=64) → μ
         Linear(128, d_z=64) → logσ²  (clamp到[-10, 10])
```

#### 4.1.5 解码器详细规格

```
z: [N × d_z=64]
→ Linear(64, 128) + GELU
→ Linear(128, 256) + GELU + Dropout(0.1)
→ Linear(256, 512) + GELU
→ Linear(512, M × d_feat_dec=64): [N × M × 64]
→ Cross-Attention(Q=上述, K=Chem_K, V=Chem_V): [N × M × 64]
→ Residual + LayerNorm

→ 分支1（强度重建头）:
   Linear(64, 32) + GELU → Linear(32, 1) → X_recon [N × M]
   
→ 分支2（MNAR概率头）:
   Linear(64, 16) + GELU → Linear(16, 1) + Sigmoid → π_ij [N × M]
   （π_ij为样本i特征j的检出概率）
```

---

### 4.2 MNAR惩罚项

**物理含义**：化学属性（主要是logP和MW）决定了一个特征在某色谱条件下的检出概率。logP低（亲水性强）的化合物在RPLC中往往先洗脱、保留弱、易丢失；MW大的化合物离子化效率低。

**MNAR概率模型**：

特征j的总体检出概率（先验）：
```
p_detect,j = σ(α_1 · logP_j + α_2 · log(MW_j) + α_3 · TPSA_j + β)
```
其中 σ 为sigmoid函数，α_1, α_2, α_3, β 为可学习参数（通过最大化观测数据的对数似然学习）

**MNAR惩罚项数学公式**：

设模型预测的每个样本-特征对的检出概率为 π_ij（解码器MNAR头输出），则：

```
L_MNAR = -Σ_{i,j} [O_ij · log(π_ij + ε) + (1-O_ij) · log(1 - π_ij + ε)]
        + λ_reg · Σ_j (p_detect,j - π̄_j)²
```

第一项：binary cross-entropy，监督模型正确预测哪些位置应该被观测到  
第二项：使每个特征的平均预测检出率与化学先验 p_detect,j 保持一致  
π̄_j = (1/N) Σ_i π_ij 为该特征在所有样本中的平均预测检出率  
λ_reg = 0.1（默认）

**关键设计决策**：L_MNAR不使用真实填补值（避免circular reasoning），只使用观测模式O和化学属性C。

---

### 4.3 化学一致性正则化

**物理含义**：化学性质相似的代谢物（logP/MW接近），在同一样本中的填补值应有相似的填补误差分布。即，化学相似性在隐空间中应该体现为相似的重建行为。

**特征化学相似度矩阵**：
```
S_jk = exp(-||c_j - c_k||² / (2σ_chem²))
```
其中 c_j = [logP_j_norm, MW_j_norm, TPSA_j_norm]，σ_chem 为带宽参数（用特征化学属性的中位数距离确定）

**化学一致性正则化**：
```
L_chem = (1/M²) Σ_{j,k} S_jk · ||r_j - r_k||²
```
其中 r_j = (1/N) Σ_i (X_ij - X_recon,ij)² 为特征j的平均重建残差  

**含义**：强迫化学相似特征具有相似的重建残差分布，即模型对化学相似物的处理应该一致。

**高效实现**（避免O(M²)存储）：使用稀疏近邻矩阵，只保留每个特征化学空间中最近的K=10个邻居。

---

### 4.4 完整损失函数

```
L_total = L_recon + β·L_KL + λ_mnar·L_MNAR + λ_chem·L_chem
```

**各项定义**：

**L_recon（观测重建损失）**：
```
L_recon = (1/Σ O_ij) · Σ_{i,j} O_ij · (X_ij - X_recon,ij)²
```
只对观测到的位置计算MSE，避免填补值自身监督自身。

**L_KL（KL散度）**：
```
L_KL = -0.5 · Σ_d (1 + logσ²_d - μ_d² - σ²_d)
```
标准VAE的KL项，d索引latent dimension。

**β调度**：采用β-VAE中的KL退火（warm-up）：前20%训练步β从0线性增长到1，之后固定为1。这防止KL collapse。

**λ_mnar = 0.5**：平衡MNAR惩罚，初期设置较小，第30轮后增加到1.0（课程学习思路）。

**λ_chem = 0.1**：化学一致性正则化系数，较小，作为软约束。

**观测似然**：假设对数强度服从条件高斯分布 p(X_ij | z_i, c_j) = N(X_recon,ij, σ²_noise)，其中σ²_noise为可学习标量参数。

---

### 4.5 与MMISVAE的架构对比

| 维度 | MMISVAE | CP-MNAR-VAE | 说明 |
|------|---------|-------------|------|
| 编码器 | 标准MLP编码器 | MLP + Cross-Attention化学注入 | **创新：化学先验注入编码** |
| 缺失机制建模 | 隐式（通过masking） | 显式MNAR概率头 + 化学先验p_detect | **创新：显式MNAR建模** |
| 化学属性利用 | 无 | Cross-Attention + 化学一致性正则化 | **本文核心创新** |
| 多模态融合 | 多组学（代谢+蛋白） | 单组学 + 化学属性先验 | 不同应用场景 |
| 解码器 | 单头（强度） | 双头（强度 + MNAR概率） | **创新：解码器双头** |
| 损失函数 | ELBO | ELBO + L_MNAR + L_chem | **创新：两个额外正则项** |
| 化学一致性 | 无 | 特征化学相似度正则化 | **创新** |
| 归纳偏置 | 无（纯数据驱动） | 化学先验引导 | **创新：领域知识注入** |

**借鉴自MMISVAE**：VAE整体框架、观测掩码处理方式、训练稳定性技巧（KL退火）。

**本文独创**：Cross-Attention化学注入机制、MNAR概率头、化学一致性正则化、RT代理logP近似、损失函数设计。

---

## 5. 实验设计

### 5.1 全部实验列表

#### 主实验1：填补精度基准测试（Benchmark）

**目的**：在模拟MNAR场景下比较CP-MNAR-VAE与所有基线的填补精度

**实验矩阵**：
- 数据集：5个数据集
- 方法：7种（kNN, QRILC, GSimp, missForest, MMISVAE, MinProb, CP-MNAR-VAE）
- 缺失率：20%、40%、60%（人工MNAR）
- 重复：每个设置10次随机种子

**自变量**：填补方法  
**因变量**：NRMSE、MAE、Pearson r（填补值vs真值）  
**控制变量**：缺失率、数据集、随机种子

#### 主实验2：跨数据集泛化测试

**目的**：模型在一个数据集训练后，化学属性知识能否迁移到新数据集

**设计**：用4个数据集训练，在第5个上测试（5种组合）

#### 主实验3：真实MNAR场景测试

**目的**：在真实缺失（非人工模拟）数据上，比较填补后数据集的生物学一致性

**评估指标**：不用真值，用下游分析质量代替（见5.4）

---

#### 消融实验A：Cross-Attention化学注入的贡献

**消融配置**（每个都是完整模型去掉某模块）：
- A1：无化学属性（纯VAE baseline）
- A2：化学属性拼接（concat而非cross-attention）
- A3：有cross-attention但无化学一致性正则（去掉L_chem）
- A4：有cross-attention但无MNAR惩罚（去掉L_MNAR）
- A5：完整CP-MNAR-VAE

**因变量**：NRMSE（主要），化学一致性得分（辅助，低logP特征的填补误差是否一致低于高logP特征）

#### 消融实验B：化学属性维度的贡献

**设计**：逐个移除单个化学属性维度，观察NRMSE变化

**配置**：
- B1：只用logP
- B2：只用MW
- B3：只用TPSA
- B4：logP + MW
- B5：logP + MW + TPSA
- B6：全部6维（完整）

#### 消融实验C：RT代理logP的质量影响

**设计**：将真实logP替换为RT代理logP（仅用于未注释特征），测试性能下降

#### 消融实验D：MNAR惩罚项权重λ_mnar的敏感性

**设计**：λ_mnar ∈ {0, 0.1, 0.5, 1.0, 2.0}，其他超参数固定

#### 消融实验E：隐变量维度d_z的敏感性

**设计**：d_z ∈ {16, 32, 64, 128, 256}

---

#### 下游验证实验F：差异代谢物分析质量

**目的**：填补后的差异分析是否恢复了正确的生物学信号

**操作**：在MTBLS1（健康vs代谢综合征）上，各种填补方法处理后，用t-test/limma进行差异分析，FDR<0.05的代谢物列表与"金标准"（文献已报道的差异代谢物）对比

**金标准构建**：原论文报道的代谢物 + 使用完整子集（缺失<10%）分析的结果

**指标**：Recall（文献已知差异代谢物的找回率）、Precision（新发现中真实差异的比例，用独立队列验证）、FDR控制（名义5% FDR下实际假正率）

#### 下游验证实验G：PCA聚类质量

**指标**：PC1/2解释方差比、轮廓系数（silhouette score，按样本组别）

#### 下游验证实验H：通路富集分析稳定性

**设计**：10次bootstrap重采样，各填补方法在每次重采样后进行通路富集（MSEA），计算富集通路集合的Jaccard相似度（稳定性指标）

---

### 5.2 基线方法实现来源

| 方法 | 来源/包 | 调用方式 |
|------|---------|---------|
| kNN | scikit-learn `KNNImputer` | Python直接调用 |
| MinProb | 自实现（用观测值最小分位数/5填充） | Python |
| QRILC | R包 `imputeLCMD::impute.QRILC()` | rpy2 |
| GSimp | R包（GitHub: WandeRum/GSimp） | rpy2 |
| missForest | R包 `missForest::missForest()` | rpy2 |
| MMISVAE | GitHub: luoyuanlab/MMISVAE | 官方代码，PyTorch |

**rpy2统一接口**（封装在 `scripts/train_baselines.py`）：
```python
import rpy2.robjects as ro
from rpy2.robjects import pandas2ri
pandas2ri.activate()

def run_qrilc(matrix_df):
    ro.r('library(imputeLCMD)')
    ro.globalenv['data_r'] = pandas2ri.py2rpy(matrix_df)
    ro.r('result <- impute.QRILC(data_r)$dataComplete')
    return pandas2ri.rpy2py(ro.globalenv['result'])
```

---

### 5.3 模拟MNAR场景的具体操作

**原理**：用logistic模型模拟低浓度截断的MNAR机制，确保人工缺失的引入方式符合化学先验假设。

**MNAR模拟算法**（`scripts/07_simulate_mnar.py`）：

```python
import numpy as np

def simulate_mnar(X_complete, chem_props, target_missing_rate=0.4, seed=42):
    """
    X_complete: 完整矩阵 [N × M]，对数尺度
    chem_props: 化学属性矩阵 [M × 6]
    target_missing_rate: 目标总体缺失率
    """
    rng = np.random.RandomState(seed)
    N, M = X_complete.shape
    mask = np.ones((N, M), dtype=bool)  # True=观测到
    
    for j in range(M):
        # 每个特征的检出阈值由化学属性决定
        logP_j = chem_props[j, 0]  # 已归一化
        
        # 低logP特征（亲水性强，RPLC中保留弱）→ 更高缺失概率
        # 化学属性决定的基础缺失倾向
        base_missing_prob = 0.2 + 0.3 * (1 / (1 + np.exp(logP_j)))  # logP越低，基础缺失概率越高
        
        # 浓度依赖的MNAR：低浓度样本更容易缺失
        col = X_complete[:, j]
        col_norm = (col - col.min()) / (col.max() - col.min() + 1e-8)  # 归一化到[0,1]
        
        # 检出概率：浓度越低 + logP越低 → 更容易缺失
        detect_prob = (1 - base_missing_prob) * col_norm + base_missing_prob * (1 - col_norm)
        # 等价：detect_prob = base_missing_prob + (1 - 2*base_missing_prob) * col_norm
        # 但更直观写法：
        detect_prob = col_norm * (1 - base_missing_prob) + (1 - col_norm) * 0.05
        
        # 按概率随机设置缺失
        missing_mask = rng.binomial(1, 1 - detect_prob)  # 1=缺失
        mask[:, j] = (missing_mask == 0)
    
    # 调整到目标缺失率
    actual_rate = 1 - mask.mean()
    # 若偏差>5%，用全局阈值调整
    
    X_mnar = X_complete.copy()
    X_mnar[~mask] = np.nan
    
    return X_mnar, mask  # 返回含缺失矩阵和观测掩码
```

**验证模拟质量**：计算Kolmogorov-Smirnov检验，确认缺失值的浓度分布显著低于观测值分布（p<0.05）——这是MNAR的必要条件。

---

### 5.4 评价指标完整列表

**填补精度指标（需要真值）**：

```
NRMSE = sqrt(MSE(X_true, X_imputed)) / std(X_true)
         只对人工制造的缺失位置计算

MAE = mean(|X_true - X_imputed|)
       同上

Pearson_r = correlation(X_true.flatten(), X_imputed.flatten())
             只在缺失位置

SSIM（结构相似性）：将矩阵作为图像计算SSIM，评估填补的结构一致性
```

**化学一致性指标（无需真值）**：

```
Chem_Consistency = 1 - cor(|X_true - X_imputed|_j, logP_j)
对于低logP特征（化学先验认为更难检出），填补误差应系统性更大
好的模型：此相关性接近0（无偏）；差的模型：此相关性显著
```

**下游分析指标**：

```
DR_Recall = |{金标准差异代谢物} ∩ {方法发现}| / |{金标准}|
DR_FDR = 1 - DR_Precision = 1 - |{方法发现 ∩ 金标准}| / |{方法发现}|
PCA_Variance = PC1解释方差（越高越好，填补越充分）
Silhouette = 样本聚类轮廓系数（越高，生物学分组越清晰）
Pathway_Stability = Jaccard(bootstrap1_pathways, bootstrap2_pathways)均值
```

---

## 6. 论文结构与图表详细规划

### Fig 1：MNAR模式的化学先验表征

**总体目的**：建立"代谢组学中MNAR缺失由化学属性驱动"这一核心论点

**Panel布局**：2行3列（共6个panels）

**(a) MNAR普遍性热图**  
- 图表类型：热图（heatmap）  
- X轴：5个数据集名称  
- Y轴：缺失率分组（0-20%、20-40%、40-60%、60-80%、80-100%）  
- 颜色：特征数量（蓝色渐变）  
- 说明：展示所有数据集中高缺失率特征的绝对数量

**(b) 缺失率 vs. logP散点图**  
- 图表类型：散点图 + 局部加权回归曲线（LOWESS）  
- X轴：特征logP值（-2到8）  
- Y轴：该特征的缺失率（0到1）  
- 每个点=一个代谢物特征，5个数据集不同颜色  
- 核心发现：低logP特征缺失率显著更高（Pearson r约-0.5 to -0.7）

**(c) 缺失率 vs. MW散点图**  
- 同(b)，X轴替换为MW（50-600 Da）  
- 用大MW也与高缺失率相关

**(d) MNAR vs. MCAR的浓度分布对比**  
- 图表类型：核密度估计（KDE）双图  
- 上半部分：观测值浓度分布（实线）  
- 下半部分：填补值应在的浓度分布（基于MNAR假设）  
- 与随机缺失（MCAR）的对应分布叠加（虚线）  
- 核心：MNAR缺失值对应低浓度，MCAR缺失值应与观测值同分布

**(e) Little's MCAR Test结果**  
- 图表类型：条形图  
- X轴：5个数据集  
- Y轴：Little's MCAR Test p值（-log10尺度）  
- 红色虚线：p=0.05  
- 说明：所有数据集均显著拒绝MCAR（p<0.001），证实MNAR存在

**(f) 化学属性logistic回归系数**  
- 图表类型：系数图（coefficient plot）含95% CI  
- X轴：回归系数值（OR方向）  
- Y轴：预测变量（logP, MW, TPSA, HBD, HBA, charge）  
- 说明：用logistic回归预测缺失/观测，各化学属性的贡献大小和方向

---

### Fig 2：CP-MNAR-VAE模型架构

**总体目的**：直观展示模型设计，使读者理解各模块的物理意义

**Panel布局**：1大图 + 2个放大插图

**(a) 整体架构流程图（主图，占60%面积）**  
- 图表类型：定制化架构示意图（matplotlib patches + arrows）  
- 从左到右：输入层（强度矩阵X + 掩码O）→ 化学编码器（右侧平行，输出K/V）→ Cross-Attention模块（中央，红色高亮）→ 编码器MLP → 隐空间z → 解码器MLP → 双头输出（强度重建头 + MNAR概率头）  
- 颜色编码：化学相关模块=橙色，VAE标准模块=蓝色，输出=绿色  
- 关键箭头标注维度转换

**(b) Cross-Attention机制放大图（右上角插图）**  
- 详细展示Q/K/V的来源（Q来自强度嵌入，K/V来自化学编码器）  
- 展示注意力权重矩阵（代谢物特征 × 化学特征维度）  
- 用颜色深浅表示注意力权重大小

**(c) MNAR概率头原理图（右下角插图）**  
- 展示化学属性如何通过sigmoid函数映射到p_detect  
- X轴：logP值  
- Y轴：p_detect概率  
- 显示3条曲线（不同MW水平）  
- 说明检出概率与化学属性的单调关系

---

### Fig 3：主实验结果——填补精度综合比较

**总体目的**：证明CP-MNAR-VAE在所有设置下优于基线

**Panel布局**：2行3列

**(a) NRMSE综合比较（主图，2×2大图位置）**  
- 图表类型：分组箱线图  
- X轴：7种方法（kNN, MinProb, QRILC, GSimp, missForest, MMISVAE, CP-MNAR-VAE）  
- Y轴：NRMSE（所有数据集、所有缺失率、10次重复的合并）  
- 颜色：按方法类别（传统/深度学习/本文）  
- 统计显著性标注：CP-MNAR-VAE vs. 最佳基线的Wilcoxon检验p值（*p<0.05, **p<0.01, ***p<0.001）

**(b) 按缺失率的性能曲线**  
- 图表类型：折线图  
- X轴：缺失率（20%, 40%, 60%）  
- Y轴：NRMSE均值 ± 标准差  
- 7条线，不同颜色/线型  
- 核心：高缺失率下CP-MNAR-VAE优势最明显

**(c) 按数据集分层比较**  
- 图表类型：热图  
- X轴：5个数据集  
- Y轴：7种方法  
- 颜色：NRMSE（越蓝越好）  
- 最右列：各方法的平均排名

**(d) MAE比较**  
- 同(a)，但Y轴为MAE  
- 补充（a）以证明结论不依赖单一指标

**(e) Pearson r比较**  
- 同(a)，Y轴为填补值与真值的Pearson相关系数

**(f) 化学一致性得分**  
- 图表类型：条形图  
- X轴：7种方法  
- Y轴：Chem_Consistency得分（越高=填补误差与化学属性的相关性越小=越公平）  
- 核心：CP-MNAR-VAE的化学一致性最好（对低logP特征不产生系统性偏差）

---

### Fig 4：消融实验结果

**总体目的**：验证每个模块的必要性

**Panel布局**：1行2列 + 1个补充

**(a) 模块消融（主要消融A）**  
- 图表类型：水平条形图（lollipop chart）  
- Y轴：5种消融配置（A1-A5）  
- X轴：NRMSE（相对于完整模型的变化百分比）  
- 红色虚线：完整模型  
- 每个bar末端有95% CI（跨数据集和重复）

**(b) 化学属性维度消融（消融B）**  
- 图表类型：雷达图 或 条形图  
- 展示逐个加入化学属性维度后NRMSE的改变  
- X轴：化学属性组合（B1-B6）  
- Y轴：NRMSE  
- 核心：logP贡献最大，其次MW和TPSA

**(c) 超参数敏感性（λ_mnar和d_z）**  
- 图表类型：2D热图  
- X轴：λ_mnar ∈ {0, 0.1, 0.5, 1.0, 2.0}  
- Y轴：d_z ∈ {16, 32, 64, 128, 256}  
- 颜色：NRMSE（越蓝越好）  
- 白色标注：最优超参数位置

---

### Fig 5：下游验证

**总体目的**：填补质量不只看还原精度，生物学下游任务更重要

**Panel布局**：2行2列

**(a) 差异代谢物分析——Recall vs. FDR散点图**  
- X轴：FDR（假发现率）  
- Y轴：Recall（金标准差异代谢物找回率）  
- 7个点（7种方法），右上角最佳  
- 理想点：高Recall + 低FDR  
- CP-MNAR-VAE标注为红色星形

**(b) PCA轮廓系数比较**  
- 图表类型：箱线图（跨5个数据集的重复）  
- X轴：7种方法  
- Y轴：样本聚类轮廓系数  
- 补充：PC1解释方差量  

**(c) MTBLS1病例对照PCA散点图（案例研究）**  
- 图表类型：2D PCA散点图（2×3子图：3种填补方法的对比）  
- 左：QRILC填补后的PCA；中：MMISVAE；右：CP-MNAR-VAE  
- 颜色：健康（蓝）vs. 代谢综合征（红）  
- 直观展示本文方法的分组分离最清晰

**(d) 通路富集稳定性**  
- 图表类型：小提琴图  
- X轴：7种方法  
- Y轴：bootstrap Jaccard相似度  
- 核心：本文方法的通路富集最稳定

---

### Fig 6：化学先验的机制分析与跨数据集泛化

**总体目的**：解释为什么化学先验有效，以及模型的泛化能力

**Panel布局**：1行3列

**(a) Attention权重可视化**  
- 图表类型：热图  
- X轴：化学属性维度（logP, MW, TPSA, HBD, HBA, charge）  
- Y轴：代谢物特征（按logP排序）  
- 颜色：平均attention权重  
- 核心：低logP特征对logP维度的attention权重更高（模型学到了正确的化学关联）

**(b) 跨数据集泛化曲线**  
- 图表类型：折线图  
- X轴：训练数据集（5种）  
- Y轴：在held-out测试集上的NRMSE  
- 每条线：一个测试数据集  
- 与无化学先验的VAE对比：化学先验显著改善跨数据集泛化

**(c) RT代理logP的性能影响**  
- 图表类型：条形图（对比3种条件）  
- 条件1：真实logP（实验测量值）  
- 条件2：HMDB预测logP  
- 条件3：RT代理logP  
- Y轴：NRMSE  
- 核心：即使使用RT代理，性能损失<5%，证明方法对化学属性测量质量鲁棒

---

### 表格规划

**Table 1：数据集汇总**

| 列 | 内容 |
|----|------|
| Dataset | 数据集名称 |
| Source | 数据库/文献 |
| Platform | 质谱平台（RPLC/HILIC/GC-MS） |
| N_samples | 样本量 |
| N_features | 特征数（总计/已注释） |
| Annotated% | 注释率 |
| Missing% | 真实缺失率 |
| MCAR_pval | Little's MCAR test p值 |
| Chem_props% | 化学属性完整率 |

**Table 2：主实验精度汇总**

| 列 | 内容 |
|----|------|
| Method | 方法名称 |
| NRMSE (20%) | 20%缺失率的NRMSE（mean ± std） |
| NRMSE (40%) | |
| NRMSE (60%) | |
| MAE (avg) | 平均MAE |
| Pearson r (avg) | 平均相关系数 |
| Rank | 平均排名 |
| p-value | vs. 最佳基线的Wilcoxon检验p值 |

---

### Supplementary Information规划

**Supplementary Methods（文字部分）**：
- S1：数据预处理详细步骤（过滤标准、归一化方法）
- S2：化学属性获取完整流程（HMDB解析→PubChem查询→RDKit计算→RT代理的四层回退策略）
- S3：MNAR模拟的数学推导
- S4：CP-MNAR-VAE所有层的完整维度规格
- S5：超参数搜索空间和Optuna配置
- S6：基线方法的调用参数

**Supplementary Figures**：

- **Fig S1**：每个数据集的缺失模式UpSet图（展示不同特征子集的缺失模式重叠）
- **Fig S2(a-e)**：5个数据集各自的"缺失率 vs. logP/MW/TPSA"散点图（主文Fig 1(b)(c)的分数据集版本）
- **Fig S3**：HMDB vs. PubChem vs. RDKit计算logP的相关性验证（用100个已知化合物）
- **Fig S4**：RT代理logP的拟合质量（每个数据集的R²、RMSE，散点图）
- **Fig S5**：MNAR模拟验证（KS检验结果，观测值vs缺失值浓度分布）
- **Fig S6**：训练损失曲线（L_total, L_recon, L_KL, L_MNAR, L_chem各分量）
- **Fig S7**：KL退火曲线和KL值变化
- **Fig S8**：5折CV稳定性（每折的NRMSE，展示模型不过拟合）
- **Fig S9**：消融B（化学属性维度）的完整结果（5个数据集分开展示）
- **Fig S10**：超参数敏感性（λ_chem的单独分析，λ_mnar的完整分析）
- **Fig S11**：MMISVAE的再现性验证（确认基线实现与原论文一致）
- **Fig S12**：化学属性噪声鲁棒性（逐步加入噪声后NRMSE变化）
- **Fig S13**：对无化学注释特征（纯RT代理）的单独评估
- **Fig S14**：隐空间可视化（t-SNE/UMAP，按化学属性logP着色）

**Supplementary Tables**：

- **Table S1**：5个数据集中所有特征的化学属性汇总（HMDB ID/PubChem CID/logP/MW/TPSA/来源）
- **Table S2**：超参数搜索完整结果（100次Optuna trial的参数-性能记录）
- **Table S3**：消融实验完整数值结果（每个数据集、每种消融配置）
- **Table S4**：下游差异代谢物列表（各方法发现的差异代谢物，与金标准对比）
- **Table S5**：通路富集分析结果汇总（各填补方法）
- **Table S6**：跨数据集泛化完整结果矩阵

---

### Discussion应该讨论的问题

**第一段：为什么化学先验有效——机制解释**  
从化学角度论证：RPLC中保留时间与logP的物理化学关系（van't Hoff方程）→ 低logP特征更早洗脱、信号更弱 → MNAR从化学机制上是可预测的。Cross-Attention学习到了这种关联（Fig 6a验证）。

**第二段：与现有方法的本质区别**  
对比QRILC（假设MNAR服从截断正态）：QRILC的参数固定、与数据集无关、不利用化学知识；对比MMISVAE：数据驱动但无化学先验；本文方法：数据驱动 + 化学先验融合。强调"prior知识注入"在数据稀少场景的优势。

**第三段：局限性的诚实讨论**  
(1) 化学属性来源的不确定性：RT代理logP引入~15%误差（Fig S4），影响定量化但不改变定性结论；(2) 训练数据量的要求：小样本数据集（N<20）性能下降，建议配合transfer learning；(3) 混合MNAR/MCAR的处理：本文假设缺失均为MNAR，但实际可能混合，未来可引入latent missingness indicator；(4) 仪器平台特异性：模型在RPLC数据上训练，在HILIC或GC-MS上可能需要重新校准化学属性-RT关系。

**第四段：应用场景与推广建议**  
(1) 多中心研究：化学先验与批次无关，填补可在批次校正前进行；(2) 靶向代谢组学：已知化学属性精确，此方法表现最佳；(3) 脂质组学的可迁移性：脂质logP/MW范围宽，TPSA差异大，方法应同样适用（需验证）；(4) 开源工具：提供PyPI包和Hugging Face模型，降低使用门槛。

**第五段：未来方向**  
(1) 将化学先验扩展到三维分子结构（GNN编码分子图）；(2) 与批次效应校正联合优化；(3) 迁移到蛋白质组学（基于序列属性的类似先验）；(4) 主动学习：模型识别高不确定性填补，提示实验者重新测量。

---

## 7. 关键变量与超参数

### 7.1 超参数完整列表

**模型结构超参数**：

| 超参数 | 默认值 | 搜索范围 | 是否需要调 |
|--------|--------|---------|-----------|
| d_z（隐变量维度） | 64 | {16, 32, 64, 128, 256} | 需要调 |
| d_feat（特征嵌入维度） | 128 | {64, 128, 256} | 需要调 |
| d_chem（化学编码维度） | 64 | {32, 64, 128} | 需要调 |
| num_heads（注意力头数） | 4 | {2, 4, 8} | 次要，不优先调 |
| encoder_layers（MLP层数） | 3 | {2, 3, 4} | 不优先调 |
| decoder_layers | 3 | {2, 3, 4} | 不优先调 |
| dropout | 0.1 | {0.0, 0.1, 0.2, 0.3} | 需要调 |

**损失函数超参数**：

| 超参数 | 默认值 | 搜索范围 | 是否需要调 |
|--------|--------|---------|-----------|
| β（KL权重） | 1.0 | 固定，KL退火处理 | 不需要（由退火控制） |
| λ_mnar | 0.5 | {0.1, 0.5, 1.0, 2.0} | **最重要，必须调** |
| λ_chem | 0.1 | {0.01, 0.1, 0.5} | 次要 |
| λ_reg（MNAR概率校准） | 0.1 | {0.01, 0.1, 1.0} | 次要 |
| σ_noise（观测噪声） | 可学习 | 初始化0.5 | 不需要调（可学习） |

**训练超参数**：

| 超参数 | 默认值 | 搜索范围 | 是否需要调 |
|--------|--------|---------|-----------|
| 学习率 | 1e-3 | {1e-4, 5e-4, 1e-3, 3e-3} | **必须调** |
| 批量大小 | 32 | {16, 32, 64} | 次要 |
| 最大轮数 | 200 | 固定 | 不需要调（早停控制） |
| 早停patience | 20 | 固定 | 不需要调 |
| KL退火步数 | epoch_total * 0.2 | 固定 | 不需要调 |
| 权重衰减（L2） | 1e-5 | {1e-6, 1e-5, 1e-4} | 次要 |
| 梯度裁剪 | 1.0 | 固定 | 不需要调 |

**化学属性超参数**：

| 超参数 | 默认值 | 备注 |
|--------|--------|------|
| σ_chem（化学相似度带宽） | 中位数距离 | 数据自适应，不需要调 |
| K_neighbors（稀疏化学相似度邻居数） | 10 | 固定 |
| RT代理回归度数 | 2（多项式） | 固定 |

---

### 7.2 需要调的参数 vs. 不需要调的参数

**必须调（关键影响模型性能，Optuna优先搜索）**：
- 学习率（对收敛速度和最终性能影响最大）
- λ_mnar（决定MNAR惩罚强度，直接影响填补偏差）
- d_z（隐变量维度决定模型容量）
- dropout（影响泛化，数据集小时尤其重要）

**建议调（影响中等，可在必须调的参数固定后调）**：
- d_feat、d_chem（嵌入维度）
- λ_chem

**不需要调（固定或自适应）**：
- num_heads（4是transformer的经典选择，对性能不敏感）
- encoder/decoder层数（3层已足够，更深收益递减）
- 最大轮数（早停自动控制）
- KL退火比例（20%是文献经验值）
- σ_chem（自适应计算）
- 梯度裁剪阈值（防止梯度爆炸，1.0是安全值）
- 批量大小（32在代谢组学数据规模下已够）

---

### 7.3 超参数搜索策略

**工具**：Optuna 3.6（TPE采样 + 中位数剪枝）

**搜索空间**（4个主要参数）：
```python
def objective(trial):
    lr = trial.suggest_float('lr', 1e-4, 3e-3, log=True)
    lambda_mnar = trial.suggest_float('lambda_mnar', 0.1, 2.0)
    d_z = trial.suggest_categorical('d_z', [32, 64, 128])
    dropout = trial.suggest_float('dropout', 0.0, 0.3)
    
    # 训练模型并返回验证集NRMSE
    model = CPMNAR_VAE(d_z=d_z, dropout=dropout)
    val_nrmse = train_and_eval(model, lr=lr, lambda_mnar=lambda_mnar)
    return val_nrmse
```

**搜索策略**：
1. 先用100次随机搜索覆盖搜索空间（warm-up）
2. 后200次用TPE（Tree-structured Parzen Estimator）集中搜索最优区域
3. 中位数剪枝：若trial前10轮的NRMSE高于同轮所有trial的中位数，提前终止
4. 在一个中等数据集（MTBLS1）上搜索，避免计算过度

**最终超参数确定**：
- 用搜索到的最优超参数在所有5个数据集上重新训练
- 报告5折CV的结果（避免超参数过拟合到单次train/test split）

**计算成本估算**：单次训练MTBLS1约3分钟（A100 GPU），300次trial约15小时，可设置并行（`n_jobs=4`，4个GPU并行）

---

### 7.4 训练稳定性保障措施

1. **KL collapse防护**：KL退火 + 监控每个维度的KL贡献，若某维度KL<0.01则记录警告
2. **梯度监控**：每10个batch记录梯度范数，异常放大时触发早停
3. **重复实验**：每个配置重复5次不同随机种子，报告均值±标准差
4. **模型保存**：基于验证集NRMSE的checkpoint，每个epoch保存最优权重
5. **混合精度训练**：FP16加速（`torch.cuda.amp`），节省显存

---

## 8. 时间线规划（8个月）

| 月份 | 主要任务 | 里程碑 |
|------|---------|--------|
| M1（3月） | 环境搭建、文献调研、数据下载与预处理脚本 | 所有数据集获取完毕，化学属性查询完成 |
| M2（4月） | 模型核心代码实现、loss函数、基础训练流程 | CP-MNAR-VAE在一个数据集上收敛 |
| M3（5月） | 超参数搜索、基线方法集成、初步实验 | 所有基线结果完成，超参数确定 |
| M4（6月） | 主实验全量运行（5数据集×7方法×3缺失率×10重复） | 主实验结果完整 |
| M5（7月） | 消融实验、下游验证实验、敏感性分析 | 所有实验完成 |
| M6（8月） | 论文写作（Methods + Results） | 初稿Methods/Results完成 |
| M7（9月） | Introduction + Discussion + 图表精修 | 完整初稿 |
| M8（10月-11月） | 内部审稿、修改、提交 | 投稿至Analytical Chemistry |

---

## 总结

本实施计划共规划了：
- **27个脚本文件**，总代码量约6500行
- **6张主图**（共22个panels）+ **14张补充图** + **6张补充表**
- **主实验 + 5类消融 + 3类下游验证**
- 核心创新点集中在 Cross-Attention化学先验注入 + 显式MNAR概率头 + 化学一致性正则化三个相互配合的模块

计划的最大风险点：Dunn CAMCAP数据集获取可能需要联系作者（建议第1个月即开始联系）；MMISVAE基线复现可能遇到依赖版本问题（建议在独立conda环境中安装）。