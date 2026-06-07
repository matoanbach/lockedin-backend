from lockedin_backend.core.serialization import APIModel


class RuleStatusResponse(APIModel):
    rule_id: str
    app_id: str
    app_name: str
    usage_date: str
    enabled: bool
    limit_minutes: int
    used_minutes: int
    remaining_minutes: int
    progress_percent: int
    status: str
    is_blocked_now: bool
