FROM rocker/r-ver:4.4.2

# System dependencies for HDF5, NetCDF, XML, curl (required by xcms / tidymass)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libhdf5-dev \
    libnetcdf-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy R source files and API entrypoints
COPY R/ ./R/
COPY plumber.R ./
COPY entrypoint.R ./

# Install renv for lock-file based reproducibility
RUN Rscript -e "install.packages('renv', repos = 'https://cloud.r-project.org')"

# If renv.lock is present, restore from it; otherwise install packages directly.
# The COPY below will silently no-op if the file doesn't exist when building
# with BuildKit — we handle both cases at runtime with a shell conditional.
COPY renv.lock* ./

RUN if [ -f renv.lock ]; then \
        Rscript -e "renv::restore(prompt = FALSE)"; \
    else \
        echo "No renv.lock found — installing packages directly" && \
        Rscript -e " \
            options(repos = c(CRAN = 'https://cloud.r-project.org')); \
            if (!requireNamespace('BiocManager', quietly = TRUE)) \
                install.packages('BiocManager'); \
            BiocManager::install(version = '3.19', ask = FALSE, update = FALSE); \
            # Plumber HTTP API server
            install.packages('plumber'); \
            # JSON serialization (used by plumber endpoints)
            install.packages('jsonlite'); \
            # Core tidymass ecosystem
            # NOTE: these packages are large; uncomment as needed or use renv.lock
            # install.packages('remotes');
            # remotes::install_github('tidymass/massdataset');
            # remotes::install_github('tidymass/massprocesser');
            # Lightweight CRAN deps that are always safe to install
            install.packages(c('dplyr', 'tibble', 'stringr', 'purrr', 'rlang')); \
        "; \
    fi

# Data volume mount point
VOLUME ["/data"]

EXPOSE 8001

CMD ["Rscript", "entrypoint.R"]
