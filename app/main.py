"""
FastAPI application for production-ready DevOps demo.
Provides health check and example API endpoints.
"""
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from datetime import datetime

app = FastAPI(
    title="Production Cloud Infrastructure Demo",
    description="A cost-minimized reference DevOps project",
    version="1.0.0"
)


@app.get("/health")
async def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes.
    Returns 200 OK if the service is healthy.
    """
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "service": "prod-cloud-infra-demo"
        }
    )


@app.get("/api/v1/example")
async def example_endpoint():
    """
    Example API endpoint demonstrating basic functionality.
    """
    return JSONResponse(
        status_code=200,
        content={
            "message": "Hello from production cloud infrastructure demo!",
            "endpoint": "/api/v1/example",
            "timestamp": datetime.utcnow().isoformat()
        }
    )


@app.get("/")
async def root():
    """
    Root endpoint with basic service information.
    """
    return {
        "service": "prod-cloud-infra-demo",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "example": "/api/v1/example"
        }
    }

