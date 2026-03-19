"""annot-worker: MS2 spectral matching annotation service for MetaboFlow."""

from __future__ import annotations

import logging
import time

import matchms
from fastapi import FastAPI

from app.config import settings
from app.matchms_engine import annotate, load_libraries
from app.models import AnnotateRequest, AnnotateResponse, LibraryInfo
from app.registry_client import list_all_libraries, list_tag_values, select_libraries

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(
    title="MetaboFlow annot-worker",
    description="MS2 spectral matching annotation service",
    version="0.1.0",
)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "annot-worker",
        "matchms_version": matchms.__version__,
        "library_dir": settings.library_dir,
        "registry_db": settings.registry_db,
    }


@app.get("/registry", response_model=list[LibraryInfo])
def get_registry():
    """List all registered spectral libraries with their tags."""
    return list_all_libraries()


@app.get("/registry/tags")
def get_tags() -> dict[str, list[str]]:
    """List all available tag dimensions and their values."""
    return list_tag_values()


@app.post("/annotate", response_model=AnnotateResponse)
def run_annotation(request: AnnotateRequest):
    """Run MS2 spectral matching against filtered reference libraries.

    The tag_filter selects which spectral libraries to use.
    Within a dimension (e.g. instrument), values are OR'd.
    Across dimensions, filters are AND'd.
    Empty filter = no filtering on that dimension.
    """
    t0 = time.time()

    # Select libraries based on tags
    lib_paths = select_libraries(request.tag_filter, polarity=request.polarity)
    if not lib_paths:
        return AnnotateResponse(
            hits=[],
            n_query_spectra=len(request.spectra),
            n_matched=0,
            n_reference_spectra=0,
            libraries_used=[],
        )

    logger.info(f"Selected {len(lib_paths)} libraries for annotation")

    # Load reference spectra (cached per library file)
    ref_spectra = load_libraries(lib_paths)
    logger.info(f"Loaded {len(ref_spectra)} reference spectra")

    # Extract source names from paths
    sources = [p.split("/")[-1].split("_")[0] for p in lib_paths]

    # Run matching
    hits = annotate(request, ref_spectra, sources)

    elapsed = time.time() - t0
    logger.info(
        f"Annotation complete: {len(hits)}/{len(request.spectra)} matched "
        f"in {elapsed:.1f}s ({len(ref_spectra)} refs)"
    )

    return AnnotateResponse(
        hits=hits,
        n_query_spectra=len(request.spectra),
        n_matched=len(hits),
        n_reference_spectra=len(ref_spectra),
        libraries_used=lib_paths,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=settings.host, port=settings.port)
