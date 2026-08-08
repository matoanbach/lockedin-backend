from fastapi import APIRouter, Depends

from lockedin_backend.api.dependencies.principal import (
    get_current_principal,
    get_operator_principal,
)
from lockedin_backend.api.routes.accountability import router as accountability_router
from lockedin_backend.api.routes.analytics import router as analytics_router
from lockedin_backend.api.routes.enforcement import router as enforcement_router
from lockedin_backend.api.routes.health import router as health_router
from lockedin_backend.api.routes.preferences import router as preferences_router
from lockedin_backend.api.routes.rules import router as rules_router
from lockedin_backend.api.routes.usage import operator_router as usage_operator_router
from lockedin_backend.api.routes.usage import router as usage_router


api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health_router)

protected_router = APIRouter(dependencies=[Depends(get_current_principal)])
protected_router.include_router(accountability_router)
protected_router.include_router(analytics_router)
protected_router.include_router(enforcement_router)
protected_router.include_router(preferences_router)
protected_router.include_router(rules_router)
protected_router.include_router(usage_router)
api_router.include_router(protected_router)

operator_router = APIRouter(dependencies=[Depends(get_operator_principal)])
operator_router.include_router(usage_operator_router)
api_router.include_router(operator_router)
