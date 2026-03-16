##############################################################################
##  xcms-worker/R/preprocessing.R
##  数据预处理 / Data Preprocessing
##
##  构建mass_dataset对象、KNN缺失值填充、强度过滤和归一化。
##  Builds mass_dataset object, performs KNN imputation, intensity filtering,
##  and normalization.
##  No global variable dependencies — all parameters are explicit.
##############################################################################

## ========================= 构建mass_dataset / Build mass_dataset =========================

## 从Peak表CSV构建massdataset对象
## Build a massdataset object from a peak table CSV
##
## @param peak_table_path  peak_table_for_cleaning.csv的完整路径
##                         full path to peak_table_for_cleaning.csv
## @param sample_info      样本信息data.frame，含列: sample_id, class, group
##                         sample info data.frame with columns: sample_id, class, group
##                         传NULL时自动从列名推断 / pass NULL to auto-infer from column names
## @param polarity         离子化极性（供下游注释使用，此处不做实际过滤）
##                         ionization polarity (used downstream; not filtered here)
##
## @return massdataset class object (massdataset::mass_dataset)
build_mass_dataset <- function(peak_table_path,
                                sample_info = NULL,
                                polarity    = "positive") {
  if (!file.exists(peak_table_path)) {
    stop("Peak表文件不存在/peak_table_path does not exist: ", peak_table_path)
  }

  raw_data <- read.csv(peak_table_path, row.names = 1, header = TRUE)

  ## 提取 variable_info (mz + rt) / Extract variable_info
  variable_info              <- raw_data[, c("mz", "rt")]
  variable_info$variable_id  <- rownames(raw_data)
  variable_info              <- variable_info[, c("variable_id", "mz", "rt")]
  rownames(variable_info)    <- seq_len(nrow(raw_data))

  ## 提取表达数据（去掉mz/rt列）/ Extract expression data (drop mz/rt columns)
  expression_data <- raw_data[, !colnames(raw_data) %in% c("mz", "rt")]

  ## 自动构建样本信息 / Auto-build sample_info if not provided
  if (is.null(sample_info)) {
    sample_info <- data.frame(
      sample_id = colnames(expression_data),
      class     = gsub("[0-9]", "", colnames(expression_data)),
      group     = gsub("[0-9]", "", colnames(expression_data))
    )
  }

  ## 创建mass_dataset对象 / Create mass_dataset object
  massdataset::create_mass_dataset(
    expression_data = expression_data,
    sample_info     = sample_info,
    variable_info   = variable_info
  )
}


## ========================= 填充+过滤+归一化 / Impute + Filter + Normalize =========================

## KNN缺失值填充、强度下限过滤、归一化三步流水线
## Three-step pipeline: KNN imputation → intensity floor filter → normalization
##
## @param object          massdataset::mass_dataset 对象 / mass_dataset object
## @param intensity_floor 强度最低阈值：任一样本低于此值的feature被删除
##                        intensity floor: features with any sample below this value are removed
## @param mv_method       缺失值填充方法（传给massdataset::impute_mv）/ imputation method
##                        passed to massdataset::impute_mv (e.g. "knn", "min", "zero")
## @param norm_method     归一化方法（传给massdataset::normalize_data）
##                        normalization method passed to massdataset::normalize_data
##                        ("median", "mean", "sum", "pqn")
##
## @return 经过填充+过滤+归一化后的 massdataset::mass_dataset 对象
##         processed mass_dataset object after imputation, filtering, and normalization
impute_filter_normalize <- function(object,
                                     intensity_floor = 1000,
                                     mv_method       = "knn",
                                     norm_method     = "median") {
  ## 步骤1：KNN缺失值填充 / Step 1: KNN missing value imputation
  object <- massdataset::impute_mv(object = object, method = mv_method)

  ## 步骤2：强度下限过滤（移除含低强度样本的feature）
  ## Step 2: intensity floor filtering (remove features with any sample below floor)
  keep_ids <- rownames(object@expression_data)[
    apply(object@expression_data, 1, function(row) !any(row < intensity_floor))
  ]
  object <- object %>%
    massdataset::activate_mass_dataset("variable_info") %>%
    dplyr::filter(variable_id %in% keep_ids)

  ## 步骤3：归一化 / Step 3: normalization
  object2 <- massdataset::normalize_data(object, method = norm_method)

  object2
}
