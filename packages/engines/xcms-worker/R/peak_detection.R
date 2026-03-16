##############################################################################
##  xcms-worker/R/peak_detection.R
##  色谱峰提取 / Chromatographic Peak Detection
##
##  封装 massprocesser::process_data() 调用。
##  Wraps massprocesser::process_data() for chromatographic feature extraction.
##  No global variable dependencies — all parameters are explicit.
##############################################################################

## ========================= 色谱峰检测 / Peak Detection =========================

## 运行massprocesser色谱峰提取，返回结果Peak表CSV路径
## Run massprocesser peak detection and return path to the generated peak table CSV
##
## @param work_dir  包含原始mzML/mzXML文件的工作目录路径
##                  path to working directory containing raw mzML/mzXML files
## @param polarity  离子化极性 / ionization polarity: "positive" or "negative"
## @param params    参数列表 / parameter list containing:
##   $ppm           MS1质量容差(ppm) / MS1 mass tolerance in ppm (default 15)
##   $peakwidth     峰宽范围(秒), 长度为2的数值向量 / peak width range (seconds), length-2 vector
##   $snthresh      信噪比阈值 / signal-to-noise threshold (default 5)
##   $noise         噪声水平 / noise level (default 500)
##   $n_threads     并行线程数 / number of parallel threads (default 4)
##   $min_fraction  最小样本检出率(0-1) / minimum sample detection fraction 0-1 (default 0.5)
##
## @return 生成的Peak表CSV文件的完整路径
##         full path to the generated peak table CSV file
run_peak_detection <- function(work_dir,
                                polarity = "positive",
                                params   = list()) {
  ## 参数默认值 / Parameter defaults
  ppm          <- if (!is.null(params$ppm))          params$ppm          else 15
  peakwidth    <- if (!is.null(params$peakwidth))    params$peakwidth    else c(5, 30)
  snthresh     <- if (!is.null(params$snthresh))     params$snthresh     else 5
  noise        <- if (!is.null(params$noise))        params$noise        else 500
  n_threads    <- if (!is.null(params$n_threads))    params$n_threads    else 4
  min_fraction <- if (!is.null(params$min_fraction)) params$min_fraction else 0.5

  ## 验证工作目录 / Validate working directory
  if (!dir.exists(work_dir)) {
    stop("工作目录不存在/work_dir does not exist: ", work_dir)
  }

  ## 运行峰检测（在work_dir路径下生成Result/子目录）
  ## Run peak detection (generates Result/ subdirectory under work_dir)
  massprocesser::process_data(
    path                    = work_dir,
    polarity                = polarity,
    ppm                     = ppm,
    peakwidth               = peakwidth,
    snthresh                = snthresh,
    noise                   = noise,
    threads                 = n_threads,
    output_tic              = FALSE,
    output_bpc              = FALSE,
    output_rt_correction_plot = FALSE,
    min_fraction            = min_fraction,
    fill_peaks              = FALSE
  )

  ## 返回结果CSV路径 / Return path to result CSV
  result_csv <- file.path(work_dir, "Result", "peak_table_for_cleaning.csv")
  if (!file.exists(result_csv)) {
    stop("峰检测未生成预期文件/Peak detection did not produce expected file: ", result_csv)
  }

  result_csv
}
