from fastapi import APIRouter

from lockedin_backend.api.routes.accountability import router as accountability_router
from lockedin_backend.api.routes.health import router as health_router
from lockedin_backend.api.routes.preferences import router as preferences_router
from lockedin_backend.api.routes.rules import router as rules_router


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(accountability_router)
api_router.include_router(health_router)
api_router.include_router(preferences_router)
api_router.include_router(rules_router)
