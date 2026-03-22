FROM rocker/r-ver:4.4.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev libxml2-dev libcurl4-openssl-dev libssl-dev \
    libsodium-dev libfontconfig1-dev wget pandoc && \
    ARCH=$(dpkg --print-architecture) && \
    wget -qO /tmp/quarto.deb "https://github.com/quarto-dev/quarto-cli/releases/download/v1.6.40/quarto-1.6.40-linux-${ARCH}.deb" && \
    dpkg -i /tmp/quarto.deb && rm /tmp/quarto.deb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY R/ ./R/
COPY templates/ ./templates/
COPY plumber.R entrypoint.R ./

RUN Rscript -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org')); \
    if (!requireNamespace('BiocManager', quietly = TRUE)) \
        install.packages('BiocManager'); \
    BiocManager::install(version = '3.19', ask = FALSE, update = FALSE); \
    install.packages(c('plumber', 'jsonlite', 'officer', 'flextable', 'knitr', 'rmarkdown')); \
    BiocManager::install('rhdf5', ask = FALSE, update = FALSE); \
"

VOLUME ["/data"]
EXPOSE 8009
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD Rscript -e "con <- url('http://localhost:8009/health'); r <- readLines(con, warn=FALSE); close(con); if(length(r)==0) quit(status=1)"
CMD ["Rscript", "entrypoint.R"]
