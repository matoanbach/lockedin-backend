import json
from datetime import date

from sqlalchemy.orm import Session

from lockedin_backend.models import EnforcementEvent


class EnforcementEventRepository:
    def create(
        self,
        db: Session,
        *,
        profile_id: str,
        rule_id: str | None,
        app_id: str,
        event_type: str,
        usage_date: date,
        used_minutes: int,
        limit_minutes: int,
        metadata: dict | None,
    ) -> EnforcementEvent:
        enforcement_event = EnforcementEvent(
            profile_id=profile_id,
            rule_id=rule_id,
            app_id=app_id,
            event_type=event_type,
            usage_date=usage_date,
            used_minutes=used_minutes,
            limit_minutes=limit_minutes,
            metadata_json=json.dumps(metadata or {}),
        )
        db.add(enforcement_event)
        db.flush()
        return enforcement_event
