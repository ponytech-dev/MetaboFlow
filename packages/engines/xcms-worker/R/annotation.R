##############################################################################
##  xcms-worker/R/annotation.R
##  代谢物注释 / Metabolite Annotation
##
##  封装多数据库注释流水线：inhouse → HMDB → MassBank → MoNA → Orbitrap。
##  Wraps multi-database annotation pipeline:
##    inhouse → HMDB → MassBank → MoNA → Orbitrap.
##  No global variable dependencies — all parameters are explicit.
##############################################################################

## ========================= 代谢物注释 / Metabolite Annotation =========================

## 对mass_dataset对象运行多数据库注释并返回注释后的对象
## Run multi-database annotation on a mass_dataset object and return the annotated object
##
## 注释顺序（与v1.r一致）/ Annotation order (matches v1.r):
##   1. inhouse_Metabolite.database — 自建库，rt容差严格(6000) / in-house DB, strict RT tol
##   2. hmdb_ms2_merged.rda         — HMDB MS2库 / HMDB MS2 library
##   3. massbank_ms2_merged.rda     — MassBank MS2库 / MassBank MS2 library
##   4. mona_ms2_merged.rda         — MoNA MS2库 / MoNA MS2 library
##   5. orbitrap_database0.0.3.rda  — Orbitrap专用库 / Orbitrap-specific library
##
## @param object   经过预处理的 massdataset::mass_dataset 对象
##                 preprocessed massdataset::mass_dataset object
## @param db_dir   包含所有数据库.rda/.database文件的目录路径
##                 path to directory containing all database .rda/.database files
## @param polarity 离子化极性 / ionization polarity: "positive" or "negative"
## @param ms1_ppm  MS1质量容差(ppm) / MS1 mass tolerance in ppm (default 15)
## @param ms2_ppm  MS2质量容差(ppm)（当前实现未直接使用，为接口预留）
##                 MS2 mass tolerance in ppm (reserved for interface; not directly used)
##
## @return 注释后的 massdataset::mass_dataset 对象
##         annotated massdataset::mass_dataset object
run_annotation <- function(object,
                            db_dir,
                            polarity,
                            ms1_ppm = 15,
                            ms2_ppm = 30) {
  if (!dir.exists(db_dir)) {
    stop("数据库目录不存在/db_dir does not exist: ", db_dir)
  }

  ## 加载数据库文件 / Load database files
  ## 使用local()避免污染调用环境 / Use local() to avoid polluting caller environment
  inhouse_db_path <- file.path(db_dir, "inhouse_Metabolite.database")
  if (!file.exists(inhouse_db_path)) {
    stop("找不到inhouse数据库/inhouse database not found: ", inhouse_db_path)
  }

  db_env <- new.env(parent = emptyenv())

  load(file.path(db_dir, "inhouse_Metabolite.database"), envir = db_env)
  load(file.path(db_dir, "hmdb_ms2_merged.rda"),         envir = db_env)
  load(file.path(db_dir, "massbank_ms2_merged.rda"),     envir = db_env)
  load(file.path(db_dir, "mona_ms2_merged.rda"),         envir = db_env)
  load(file.path(db_dir, "orbitrap_database0.0.3.rda"),  envir = db_env)

  ## 步骤1：inhouse库注释（严格RT容差=6000）
  ## Step 1: in-house database annotation (strict RT tolerance = 6000)
  object1 <- massdataset::annotate_metabolites_mass_dataset(
    object       = object,
    ms1.match.ppm = ms1_ppm,
    rt.match.tol  = 6000,
    polarity      = polarity,
    database      = db_env$inhouse_Metabolite.database
  )

  ## 步骤2-5：公共MS2库注释（宽松RT容差=90000，允许无RT信息的库）
  ## Steps 2-5: public MS2 library annotation (loose RT tolerance = 90000 for RT-free libs)
  ms2_databases <- list(
    db_env$hmdb_ms2,
    db_env$massbank_ms2,
    db_env$mona_ms2,
    db_env$orbitrap_database0.0.3
  )

  for (db in ms2_databases) {
    object1 <- massdataset::annotate_metabolites_mass_dataset(
      object        = object1,
      ms1.match.ppm = ms1_ppm,
      rt.match.tol  = 90000,
      polarity      = polarity,
      database      = db
    )
  }

  object1
}
