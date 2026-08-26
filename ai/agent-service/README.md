# MyAaptha Agent Service

This service is the Milestone 5 foundation for AI capabilities.

## Included in this baseline

- FastAPI application scaffold
- Versioned API routes under /api/v1
- Health endpoints for liveness and readiness
- Configurable runtime settings via environment variables
- Basic automated tests

## Local run

1. Install dependencies:
   - python -m pip install -r requirements.txt
2. Run service:
   - uvicorn ai_service.main:app --app-dir src --host 0.0.0.0 --port 8081
3. Open health endpoint:
   - http://localhost:8081/api/v1/health

## Test

- python -m pytest tests -q

## Environment variables

- AI_ENV (default: local)
- AI_SERVICE_NAME (default: myaaptha-agent)
- AI_API_PREFIX (default: /api/v1)
- AI_LOG_LEVEL (default: INFO)
