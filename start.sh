#!/bin/bash

# Quick start script for MicroHack Infrastructure

set -e

echo "======================================"
echo "MicroHack Infrastructure Quick Start"
echo "======================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "Error: Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

echo "✓ Docker is available"
echo "✓ Docker Compose is available"
echo ""

# Start services
echo "Starting all services..."
docker compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 30

# Check service status
echo ""
echo "Service Status:"
docker compose ps

echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "API Endpoints:"
echo "  - Base URL: http://localhost:8080"
echo "  - Customers: http://localhost:8080/api/customers"
echo "  - Orders: http://localhost:8080/api/orders"
echo "  - OpenAPI: http://localhost:8080/openapi/v1.json"
echo ""
echo "Database Connections:"
echo "  - SQL Server 1 (CustomerDB): localhost:1433"
echo "  - SQL Server 2 (OrderDB): localhost:1434"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop services: docker compose down"
echo ""
