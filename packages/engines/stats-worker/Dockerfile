FROM rocker/r-ver:4.4.2

# System dependencies for Cairo graphics, XML, curl, harfbuzz/fribidi (required by ggplot2 / ragg)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy R source files
COPY R/ ./R/

RUN Rscript -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org')); \
    if (!requireNamespace('BiocManager', quietly = TRUE)) \
        install.packages('BiocManager'); \
    BiocManager::install(version = '3.19', ask = FALSE, update = FALSE); \
    # Core stats / viz packages
    install.packages(c('ggplot2', 'dplyr', 'tidyr')); \
    # limma from Bioconductor
    BiocManager::install('limma', ask = FALSE, update = FALSE); \
    # MetaboAnalystR — large package, uncomment when ready for production build
    # install.packages('remotes');
    # remotes::install_github('xia-lab/MetaboAnalystR', build = FALSE); \
"

# Data volume mount point
VOLUME ["/data"]

CMD ["Rscript", "-e", "message('stats-worker ready'); Sys.sleep(Inf)"]
