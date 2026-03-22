FROM rocker/r-ver:4.4.2

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
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY R/ ./R/
COPY templates/ ./templates/
COPY interpretations/ ./interpretations/
COPY registry.json plumber.R entrypoint.R ./

RUN Rscript -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org')); \
    if (!requireNamespace('BiocManager', quietly = TRUE)) \
        install.packages('BiocManager'); \
    BiocManager::install(version = '3.19', ask = FALSE, update = FALSE); \
    install.packages(c( \
        'plumber', 'jsonlite', 'ggplot2', 'dplyr', 'tidyr', \
        'ggrepel', 'patchwork', 'svglite', 'Cairo', 'scales', \
        'RColorBrewer', 'viridis', 'pheatmap', 'ggridges', \
        'ggbeeswarm', 'corrplot', 'VennDiagram', 'UpSetR', \
        'ggforce', 'ggsci', 'ggpubr', 'factoextra' \
    )); \
    BiocManager::install( \
        c('ComplexHeatmap', 'EnhancedVolcano', 'rhdf5'), \
        ask = FALSE, update = FALSE \
    ); \
"

VOLUME ["/data"]
EXPOSE 8008

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD Rscript -e "con <- url('http://localhost:8008/health'); r <- readLines(con, warn=FALSE); close(con); if(length(r)==0) quit(status=1)"

CMD ["Rscript", "entrypoint.R"]
