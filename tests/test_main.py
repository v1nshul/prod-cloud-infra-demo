"""
Unit tests for the FastAPI application.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check():
    """Test the health check endpoint returns 200 OK."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert data["service"] == "prod-cloud-infra-demo"


def test_example_endpoint():
    """Test the example API endpoint returns correct data."""
    response = client.get("/api/v1/example")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert data["endpoint"] == "/api/v1/example"
    assert "timestamp" in data


def test_root_endpoint():
    """Test the root endpoint returns service information."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "prod-cloud-infra-demo"
    assert "endpoints" in data

