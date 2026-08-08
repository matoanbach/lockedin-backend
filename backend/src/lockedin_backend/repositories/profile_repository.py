from sqlalchemy import select
from sqlalchemy.orm import Session

from lockedin_backend.models import Profile


class ProfileRepository:
    def get_by_slug(self, db: Session, slug: str) -> Profile | None:
        return db.execute(select(Profile).where(Profile.slug == slug)).scalar_one_or_none()

    def create(
        self,
        db: Session,
        *,
        slug: str,
        name: str,
        is_demo: bool = False,
        is_active: bool = True,
    ) -> Profile:
        profile = Profile(
            slug=slug,
            name=name,
            is_demo=is_demo,
            is_active=is_active,
        )
        db.add(profile)
        db.flush()
        return profile
