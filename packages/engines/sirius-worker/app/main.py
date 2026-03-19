"""sirius-worker: SIRIUS/CSI:FingerID structure prediction service for MetaboFlow."""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException

from app.config import settings
from app.models import PredictRequest, PredictResponse
from app.sirius_cli import get_version, login, predict

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(
    title="MetaboFlow sirius-worker",
    description="SIRIUS/CSI:FingerID molecular structure prediction service",
    version="0.1.0",
)

_sirius_version = "checking..."
_logged_in = False


@app.on_event("startup")
async def startup():
    global _sirius_version, _logged_in
    _sirius_version = get_version()
    logger.info(f"SIRIUS version: {_sirius_version}")

    if settings.sirius_user:
        _logged_in = login()
        logger.info(f"SIRIUS login: {'success' if _logged_in else 'failed'}")
    else:
        logger.warning("No SIRIUS credentials configured — CSI:FingerID disabled")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "sirius-worker",
        "sirius_version": _sirius_version,
        "csi_fingerid_available": _logged_in,
    }


@app.post("/predict", response_model=PredictResponse)
def run_prediction(request: PredictRequest):
    """Run SIRIUS molecular formula + CSI:FingerID structure prediction.

    Requires MS2 fragmentation spectra. Optionally accepts MS1 isotope patterns
    for improved formula scoring.

    CSI:FingerID requires internet access and valid SIRIUS account credentials.
    """
    if not request.spectra:
        raise HTTPException(status_code=400, detail="No spectra provided")

    predictions = predict(
        spectra=request.spectra,
        database=request.database,
        max_candidates=request.max_candidates,
        instrument=request.instrument,
    )

    n_predicted = sum(1 for p in predictions if p.top_formula is not None)

    return PredictResponse(
        predictions=predictions,
        n_input=len(request.spectra),
        n_predicted=n_predicted,
        sirius_version=_sirius_version,
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=settings.host, port=settings.port)
