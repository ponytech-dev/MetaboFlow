# MetaboFlow 图表模板目录

**版本**: v1.0  
**日期**: 2026-03-21  
**范围**: LC-MS 非靶向代谢组学，Nature/Science 系列期刊 2020–2026 高频图表  
**来源期刊**: Nature、Science、Nature Methods、Nature Metabolism、Nature Chemical Biology、Analytical Chemistry、Metabolomics、Journal of Proteome Research

---

## 数据来源分类说明

| 类别 | 定义 |
|------|------|
| **A** | 可从已处理特征矩阵 + 统计结果直接生成（feature intensities, fold change, p-values, annotations） |
| **B** | 需要新管线计算（mfuzz 聚类、OPLS-DA、网络分析等） |
| **C** | 需要原始 mzML/mzXML 数据（EIC 轨迹、MS2 谱图、TIC/BPC 色谱图） |
| **D** | 需要外部 API 或库（KEGG 通路着色、RDKit 结构渲染、GNPS 网络） |

---

## Table 1：20 个基础模板

基础模板定义：在代谢组学论文中出现频率极高（>70% 论文），单一数据维度为主，对应标准统计分析步骤。

| # | 图表名称 | 科学用途 | 数据输入 | 数据来源 | 滤镜敏感性 | R 包 |
|---|----------|---------|---------|---------|-----------|------|
| B01 | **Volcano Plot（火山图）** | 展示组间差异代谢物：x 轴 log2FC，y 轴 -log10(adj.p)，三色分区（上调/下调/非显著） | feature_id, log2_fc, adj_p_value, 可选 compound_name | A | filter-sensitive | EnhancedVolcano, ggplot2 |
| B02 | **PCA Score Plot（主成分分析得分图）** | 无监督样本分群，检验组间分离和批次效应，椭圆标注置信区间 | intensity_matrix（样本×特征） | A | global | ggplot2, ggfortify, factoextra |
| B03 | **Sample Heatmap（样本×特征热图）** | 差异特征的跨样本表达模式，双向层次聚类，行列 dendrogram | 标准化 intensity_matrix，top N 差异特征 | A | filter-sensitive | ComplexHeatmap |
| B04 | **Boxplot / Violin-Box（特征丰度分布图）** | 单个或多个选定代谢物在各组的丰度分布，含显著性标注（Tukey brackets） | 单特征 intensity + group_metadata | A | filter-sensitive | ggplot2, ggpubr, ggbeeswarm |
| B05 | **TIC Chromatogram（总离子流色谱图）** | QC 检查：各样本信号强度随保留时间变化，叠加多条 TIC 曲线 | 原始 mzML，TIC 轨迹 | C | global | Spectra, xcms, ggplot2 |
| B06 | **BPC Chromatogram（基峰色谱图）** | 色谱分离质量评估：各扫描最大离子强度，鉴别峰形异常 | 原始 mzML，BPC 轨迹 | C | global | Spectra, xcms, ggplot2 |
| B07 | **EIC（提取离子色谱图）** | 验证特定化合物：指定 m/z ± ppm 窗口的离子强度随 RT 变化，标注检测峰 | 原始 mzML，target m/z，ppm tolerance | C | filter-sensitive | xcms, Spectra, ggplot2 |
| B08 | **MS2 Mirror Plot（碎片谱镜像比对图）** | 注释验证：实验 MS2 谱（上）vs 参考库谱（下）对称展示，标注匹配碎片 | 实验 MS2 fragments（mz, intensity），参考库 MS2 | C | filter-sensitive | MetaboAnnotatoR, ggplot2, Spectra |
| B09 | **mz-RT Scatter Plot（特征云图）** | 全局特征概览：x 轴 RT，y 轴 m/z，点色/大小编码强度，直观呈现数据密度 | features（mz, rt, max_intensity） | A | global | ggplot2 |
| B10 | **Pathway Enrichment Bar Chart（通路富集条形图）** | 展示显著富集的 KEGG/HMDB 通路，x 轴 enrichment ratio 或 -log10(p)，按 p 值排序 | 差异代谢物列表 → pathway_results（pathway_name, p_value, hit_count, total_count） | D | filter-sensitive | ggplot2, clusterProfiler |
| B11 | **Pathway Bubble Plot（通路富集气泡图）** | 同时展示通路富集度、覆盖率和 p 值：气泡位置=通路，大小=hit 数，色=p 值 | pathway_results（pathway_name, p_value, ratio, count） | D | filter-sensitive | ggplot2 |
| B12 | **PCA Biplot（PCA 双标图）** | 在样本得分图上叠加特征 loading 向量，揭示驱动分离的特征方向 | intensity_matrix + loading vectors | A | global | ggplot2, ggfortify, factoextra |
| B13 | **Sample QC Intensity Boxplot（样本 QC 强度分布图）** | 批次和样本间信号稳定性检查：每个样本的总离子强度/特征数量箱线图，QC 样本高亮 | per-sample total_intensity or feature_count + sample_type | A | global | ggplot2 |
| B14 | **RSD Distribution Plot（相对标准偏差分布图）** | 特征重现性评估：QC 样本的 RSD% 分布直方图或累积分布，20% 阈值线标注 | QC 样本 intensity_matrix → per-feature RSD% | A | global | ggplot2 |
| B15 | **Correlation Heatmap（样本相关性热图）** | 样本间 Pearson/Spearman 相关性矩阵，检测异常样本和批次聚类 | intensity_matrix（样本×特征）→ 相关系数矩阵 | A | global | ComplexHeatmap, corrplot, ggcorrplot |
| B16 | **Feature Intensity Bar Chart（选定代谢物柱状图）** | 论文结果展示：2–8 个关键代谢物跨组平均丰度 + 误差棒 + 星号显著性 | selected feature intensity + group_metadata + contrast stats | A | filter-sensitive | ggplot2, ggpubr |
| B17 | **Hexbin Density Plot（m/z-RT 密度图）** | m/z vs RT 二维密度可视化，通过六边形分箱展示特征分布热点 | features（mz, rt） | A | global | ggplot2 + geom_hex |
| B18 | **UpSet Plot（集合交集图）** | 多组对比中差异代谢物的集合交叉可视化，替代 Venn 图处理 >3 组 | per-contrast differential feature lists（feature_id × contrast） | A | filter-sensitive | UpSetR, ComplexUpset |
| B19 | **Missing Value Heatmap（缺失值分布图）** | 数据质量评估：特征×样本矩阵中 NA 分布模式，识别系统性缺失问题 | raw intensity_matrix（含 NA）+ sample_metadata | A | global | ggplot2, naniar, ComplexHeatmap |
| B20 | **PLS-DA Score Plot（PLS-DA 得分图）** | 监督判别分析得分：有监督样本分群，含 R²X/R²Y/Q² 模型质量指标标注 | intensity_matrix + group_labels → PLS-DA scores | B | global | mixOmics, ropls, ggplot2 |

---

## Table 2：30 个高级模板

高级模板定义：整合 2 个以上数据维度，或通过多面板组合提供完整科学叙事，常见于 Nature/Science 系列论文主图。

| # | 图表名称 | 科学用途 | 数据输入 | 数据来源 | 滤镜敏感性 | R 包 |
|---|----------|---------|---------|---------|-----------|------|
| A01 | **Enhanced Volcano + Annotation Layer（注释火山图）** | 火山图基础上叠加 Schymanski 置信等级着色和化合物名称标注，直观区分可信注释的显著特征 | contrasts（log2_fc, adj_p_value）+ scored_hits（schymanski_level, compound_name） | A | filter-sensitive | EnhancedVolcano, ggplot2, ggrepel |
| A02 | **OPLS-DA Score + S-Plot 双联图** | OPLS-DA 得分图（组间分离）+ S-plot（协方差 vs 相关系数双轴散点）联合展示，高亮 VIP>1 特征 | intensity_matrix + group_labels → OPLS-DA scores + covariance/correlation | B | filter-sensitive | ropls, ggplot2, patchwork |
| A03 | **VIP Score Lollipop Chart（VIP 棒棒糖图）** | OPLS-DA/PLS-DA 变量重要性排序：top-N 特征按 VIP 值排序的棒棒糖图，用 FC 方向着色 | VIP scores + log2_fc per feature | B | filter-sensitive | ggplot2, ggpubr |
| A04 | **Annotated Heatmap with ClassyFire（化学分类注释热图）** | 热图行侧边加 ClassyFire 超类着色条（amino acids / lipids / etc.），直观展示代谢物化学类别聚类 | intensity_matrix + ClassyFire annotations（superclass, class） | A + D | filter-sensitive | ComplexHeatmap |
| A05 | **Mfuzz Temporal Clustering Plot（时序模糊聚类图）** | 时间序列实验：将代谢物按时序表达模式聚为 N 类，每类内叠线图展示平均趋势 ± SD | time-series intensity_matrix（≥3 时间点）→ mfuzz cluster membership | B | global | Mfuzz, ggplot2, patchwork |
| A06 | **Molecular Network（分子网络图）** | 基于 MS2 谱图余弦相似性构建节点-边网络，相似结构聚类成团，节点色编码化学类别或 log2FC | scored_hits（MS2 fragments）→ cosine similarity matrix | B + D | filter-sensitive | igraph, ggraph, visNetwork, tidygraph |
| A07 | **KEGG Pathway Map Overlay（KEGG 通路图叠加）** | 在 KEGG 通路图上用颜色标注上调/下调代谢物节点，直观呈现受扰代谢通路全景 | differential metabolite list + KEGG compound IDs | D | filter-sensitive | pathview, ggkegg |
| A08 | **Multi-contrast Bubble Heatmap（多对比气泡热图）** | 多组对比（>2）下特征的显著性和方向矩阵：行=特征，列=对比，气泡大小=-log10(p)，色=FC | contrasts matrix（feature_id × contrast_name, log2_fc, adj_p_value） | A | filter-sensitive | ggplot2, ComplexHeatmap |
| A09 | **Scatter Plot with Marginal Distribution（边际分布散点图）** | 两对比组间 log2FC 相关性，边际密度揭示一致性/拮抗代谢模式 | 两个 contrast 的 log2_fc per feature | A | filter-sensitive | ggplot2, ggExtra, patchwork |
| A10 | **Forest Plot（森林图）** | 荟萃分析风格展示多个代谢物的效应量（log2FC）和 95% CI，按超类分组 | contrasts（log2_fc, CI_low, CI_high, adj_p_value, superclass） | A | filter-sensitive | ggplot2, forestplot |
| A11 | **Waterfall Chart（瀑布图）** | 按注释置信度和得分排序的候选代谢物瀑布条形图，色条编码 Schymanski 等级 | scored_hits（allscore, schymanski_level, compound_name） | A | filter-sensitive | ggplot2 |
| A12 | **Isotope Pattern Verification Plot（同位素模式验证图）** | 验证注释：实验同位素模式（M, M+1, M+2）与理论值对比的成对柱状图，显示 mz 和强度 | isotope_features（mz, intensity, formula）→ theoretical pattern | A + B | filter-sensitive | ggplot2, Rdisop |
| A13 | **Chemical Identity Card（化合物身份证）** | 单化合物多维注释摘要：MS1 质量精度、同位素打分、MS2 镜像图、分子结构、置信等级，一图展示全部证据 | scored_hits（单条）+ MS2 fragments + 结构 SMILES | C + D | filter-sensitive | ggplot2, patchwork, rcdk, ChemmineR |
| A14 | **ROC Curve（接收者操作特征曲线）** | 生物标志物诊断能力评估：单代谢物或代谢物 panel 的 ROC 曲线，AUC 标注 | predicted scores + binary outcome labels | A | filter-sensitive | pROC, ggplot2 |
| A15 | **Ridge / Joy Plot（山脊图）** | 多组或多时间点代谢物丰度分布叠加展示，清晰呈现分布偏移模式 | features（intensity per group）or（mz distribution per RT bin） | A | global | ggridges, ggplot2 |
| A16 | **Sankey / Alluvial Diagram（桑基图）** | 注释质量通路：展示从检测特征→DB 匹配→Schymanski 等级分布的数量流向 | pipeline summary（feature counts at each stage） | A | global | ggalluvial, ggsankey |
| A17 | **Parallel Coordinates Plot（平行坐标图）** | 多维打分可视化：候选化合物的各维度打分（MS1 精度、同位素、MS2、RT、加合物）同时展示 | scored_hits（ms1score, isoscore, MS2score, rtscore, adductscore） | A | filter-sensitive | GGally, ggplot2 |
| A18 | **ChemRICH Chemical Enrichment Plot（化学结构富集图）** | 基于化学相似性的富集，气泡按化学超类聚类，不依赖 KEGG 通路数据库 | differential metabolites + chemical class + SMILES | D | filter-sensitive | ChemRICH, ggplot2 |
| A19 | **Treemap by Chemical Class（化学分类树图）** | 注释代谢物的化学类别面积比例可视化：超类→类→子类的嵌套矩形，面积=特征数 | scored_hits（cf_superclass, cf_class, cf_subclass） | A | filter-sensitive | treemap, ggplot2 |
| A20 | **Multi-panel QC Dashboard（质控仪表板）** | 综合质控：TIC 强度箱线图 + RSD 分布 + PCA 样本图 + 缺失值比例的 2×2 或 3×2 组合 | sample intensities + QC labels + intensity_matrix | A (+ C for TIC) | global | patchwork + ggplot2 + ComplexHeatmap |
| A21 | **Dual-Contrast Volcano Comparison（双对比火山图）** | 两个组间对比的火山图并排或镜像显示，比较差异代谢物重叠和差异 | 两个 contrast 的（log2_fc, adj_p_value）各一份 | A | filter-sensitive | ggplot2, patchwork, EnhancedVolcano |
| A22 | **WGCNA Module-Trait Heatmap（共表达模块-表型关联热图）** | 加权共表达网络：代谢物模块（行）与表型变量（列）的相关系数热图，颜色+数字双编码 | intensity_matrix + phenotype_matrix → WGCNA module assignments | B | global | WGCNA, ggplot2, ComplexHeatmap |
| A23 | **Arc Diagram（弧线关系图）** | 多对比中特征跨组差异方向的弧形连接图，揭示特征在不同对比中的协同/拮抗模式 | contrasts（feature_id × contrast, log2_fc） | A | filter-sensitive | ggplot2, geom_curve |
| A24 | **Contour Scatter Plot（等高线散点图）** | mz-RT 空间的特征密度等高线叠加，高亮注释命中区域 | features（mz, rt, annotated flag） | A | global | ggplot2 + stat_density_2d |
| A25 | **Metabolite-Phenotype Correlation Heatmap（代谢物-表型相关热图）** | 关键代谢物与临床/生理指标的相关系数热图，Spearman r 值+显著性标注 | selected feature intensities + clinical_variables matrix | A | filter-sensitive | ComplexHeatmap, corrplot, ggplot2 |
| A26 | **Volcano + Pathway Dual-Panel（差异代谢物+通路富集联合图）** | 火山图（左）+ 通路富集条形/气泡图（右）组合，差异代谢物和功能解读一体化展示 | contrasts（log2_fc, p）+ pathway_results | A + D | filter-sensitive | ggplot2, patchwork, EnhancedVolcano |
| A27 | **Stable Isotope Tracing Flux Plot（稳定同位素示踪通量图）** | 标记实验中 isotopologue 分布（M+0, M+1, ... M+n）堆叠条形图，展示碳骨架代谢流向 | isotopologue intensities（feature × label_number × sample） | B | filter-sensitive | ggplot2 |
| A28 | **Multi-omics Integration Heatmap（多组学整合热图）** | 代谢组与转录组/蛋白组整合：按通路分组的行分块热图，每块对应一个数据层 | metabolite intensities + gene/protein intensities + shared pathway annotation | A + D | filter-sensitive | ComplexHeatmap, patchwork |
| A29 | **Random Forest Feature Importance（随机森林特征重要性图）** | 机器学习分类：对组别区分贡献最大的特征排序，Mean Decrease Accuracy / Gini 双指标 | intensity_matrix + group_labels → RF model | B | filter-sensitive | randomForest, ggplot2 |
| A30 | **Comprehensive Analysis Dashboard（综合分析仪表板）** | 论文主图风格：PCA 得分图 + 火山图 + top-10 差异代谢物热图 + 通路气泡图 四联组合，支持单对比完整故事 | intensity_matrix + contrasts + pathway_results + annotations | A + D | filter-sensitive | patchwork, ggplot2, ComplexHeatmap, EnhancedVolcano |

---

## 汇总统计

### 数据来源分布

| 来源类别 | 基础模板（B01–B20）| 高级模板（A01–A30）| 合计 |
|---------|-------------------|-------------------|------|
| **A**（处理后特征矩阵）| 14 | 12 | 26 |
| **B**（需新管线计算）| 2 | 7 | 9 |
| **C**（需原始 mzML）| 3 | 1 | 4 |
| **D**（需外部 API/库）| 1 | 1 | 2 |
| **A + B**（双重来源）| 0 | 3 | 3 |
| **A + D**（双重来源）| 0 | 4 | 4 |
| **B + D**（双重来源）| 0 | 1 | 1 |
| **C + D**（双重来源）| 0 | 1 | 1 |

> 注：部分高级模板有双重数据来源依赖，按主要来源统计于合计中。

### 滤镜敏感性分布

| 类型 | 基础模板 | 高级模板 | 合计 |
|------|---------|---------|------|
| **filter-sensitive**（响应 p-value/FC 筛选阈值）| 11 | 23 | 34 |
| **global**（不受特征过滤影响）| 9 | 7 | 16 |

### 关键 R 包汇总

| R 包 | 主要用途 | 覆盖模板 |
|------|---------|---------|
| `ggplot2` | 底层图形语法，几乎所有图表的基础 | 全部 50 个 |
| `ComplexHeatmap` | 注释热图、模块热图 | B03, B15, A04, A22, A25, A28, A20 |
| `EnhancedVolcano` | 出版级火山图 | B01, A01, A21, A26, A30 |
| `patchwork` | 多图拼接组合 | A02, A09, A13, A20, A21, A26, A30 |
| `ggrepel` | 点标签防重叠 | A01, A10 |
| `UpSetR` / `ComplexUpset` | 集合交叉图 | B18 |
| `ggridges` | 山脊密度图 | A15 |
| `mixOmics` / `ropls` | PLS-DA / OPLS-DA | B20, A02, A03 |
| `Mfuzz` | 时序模糊聚类 | A05 |
| `igraph` / `ggraph` / `tidygraph` | 分子网络 | A06 |
| `pathview` / `ggkegg` | KEGG 通路图 | A07 |
| `ggalluvial` | Sankey/Alluvial 图 | A16 |
| `WGCNA` | 共表达网络 | A22 |
| `pROC` | ROC 曲线 | A14 |
| `randomForest` | 机器学习特征重要性 | A29 |
| `treemap` | 树图 | A19 |
| `Spectra` / `xcms` | 原始谱图处理 | B05, B06, B07, B08 |
| `rcdk` / `ChemmineR` | 化学结构渲染 | A13 |
| `clusterProfiler` | 通路富集分析 | B10, B11 |

---

## 与 PonylabASMS CHART_REGISTRY 对比

MetaboFlow 目录与 PonylabASMS 的 29 个蛋白质组学图表有以下主要差异：

| 维度 | PonylabASMS（蛋白质组） | MetaboFlow（代谢组） |
|------|----------------------|---------------------|
| 谱图验证 | MS2 mirror（评分驱动）| MS2 mirror + EIC + TIC/BPC |
| 注释可视化 | Identity card + waterfall | + Chemical class treemap + ChemRICH |
| 通路分析 | 无 | KEGG overlay + pathway bubble/bar |
| 时序分析 | 无 | Mfuzz temporal clustering |
| 多组学整合 | 无 | Multi-omics heatmap |
| 质控图表 | 有限 | 完整 QC dashboard（TIC + RSD + PCA + NA） |
| 网络分析 | Molecular network（GNPS 风格）| 同 + WGCNA + ChemRICH |
| 化学结构 | ID card 内嵌 | Dedicated isotope + structure panels |

---

## 实施优先级建议

### Phase 1（高优先级，立即可实施，数据来源 A）
实施成本低，覆盖高频使用场景：
B01 火山图、B02 PCA、B03 热图、B04 箱线/小提琴图、B09 特征云图、B13 QC 强度图、B14 RSD 分布、B15 相关热图、B16 柱状图、B17 hexbin、B18 UpSet 图

### Phase 2（中优先级，需管线计算，数据来源 B）
需要额外分析步骤但价值高：
B20 PLS-DA、A02 OPLS-DA 双联图、A03 VIP 棒棒糖、A05 mfuzz 时序图、A06 分子网络、A22 WGCNA

### Phase 3（高优先级，需原始数据，数据来源 C）
需要 mzML 访问权限，LC-MS 核心图表：
B05 TIC、B06 BPC、B07 EIC、B08 MS2 mirror、A13 化合物身份证

### Phase 4（依赖外部服务，数据来源 D）
依赖 KEGG/HMDB API 或 RDKit，需网络访问：
B10 通路条形图、B11 通路气泡图、A07 KEGG 通路图、A18 ChemRICH、A19 化学类别树图

---

## 参考文献

1. [Effective data visualization strategies in untargeted metabolomics (2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11610048/) — Natural Product Reports，全面综述代谢组学可视化策略
2. [MetaboAnalystR 4.0: a unified LC-MS workflow (2024)](https://www.nature.com/articles/s41467-024-48009-6) — Nature Communications，LC-MS 完整工作流
3. [Best practices and tools in R and Python for lipidomics and metabolomics (2025)](https://www.nature.com/articles/s41467-025-63751-1) — Nature Communications，R/Python 最佳实践
4. [Comprehensive investigation of pathway enrichment methods for LC-MS metabolomics](https://pmc.ncbi.nlm.nih.gov/articles/PMC9851290/) — Briefings in Bioinformatics，通路富集方法比较
5. [Ion identity molecular networking in GNPS (2021)](https://www.nature.com/articles/s41467-021-23953-9) — Nature Communications，分子网络方法
6. [QComics: Quality Control of Metabolomics Data (2024)](https://pubs.acs.org/doi/10.1021/acs.analchem.3c03660) — Analytical Chemistry，代谢组学质控规范
7. [xcms in Peak Form (2025)](https://pubs.acs.org/doi/10.1021/acs.analchem.5c04338) — Analytical Chemistry，xcms 生态系统完整描述
8. [MAW: Metabolome Annotation Workflow (2023)](https://jcheminf.biomedcentral.com/articles/10.1186/s13321-023-00695-y) — J. Cheminformatics，注释工作流

