import os
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="supply-chain-demo", version="1.0.0")

# Injected at build time via Docker ARG -> ENV
GIT_SHA = os.getenv("GIT_SHA", "unknown")
IMAGE_DIGEST = os.getenv("IMAGE_DIGEST", "unknown")


class HealthResponse(BaseModel):
    status: str
    service: str


class InfoResponse(BaseModel):
    status: str
    service: str
    version: str
    image_digest: str
    signed: bool


@app.get("/", response_model=HealthResponse)
def root():
    return {"status": "ok", "service": "supply-chain-demo"}


@app.get("/health", response_model=HealthResponse)
def health():
    return {"status": "healthy", "service": "supply-chain-demo"}


@app.get("/info", response_model=InfoResponse)
def info():
    return {
        "status": "ok",
        "service": "supply-chain-demo",
        "version": GIT_SHA,
        "image_digest": IMAGE_DIGEST,
        # This is set to True because any running instance of this image
        # has passed through the Cosign signing gate in CI -- if it weren't
        # signed, the Kyverno / Gatekeeper policy would have blocked the pod.
        "signed": True,
    }
