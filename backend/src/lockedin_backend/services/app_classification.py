from __future__ import annotations

from dataclasses import dataclass
from types import MappingProxyType
from typing import Final, Mapping

from lockedin_backend.services.usage_time import DEFAULT_CATEGORY


EXCLUDED_SCREEN_TIME_APP_IDS: Final[frozenset[str]] = frozenset(
    {
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.huawei.android.launcher",
        "com.miui.home",
        "com.oneplus.launcher",
        "com.oppo.launcher",
        "com.sec.android.app.launcher",
        "com.vivo.launcher",
    }
)


@dataclass(frozen=True, slots=True)
class AppClassification:
    display_name: str
    category: str


_KNOWN_APPS: Final[Mapping[str, AppClassification]] = MappingProxyType(
    {
        "com.instagram.android": AppClassification(
            "Instagram", "Social & Messaging"
        ),
        "com.whatsapp": AppClassification("WhatsApp", "Social & Messaging"),
        "com.facebook.katana": AppClassification(
            "Facebook", "Social & Messaging"
        ),
        "com.google.android.apps.messaging": AppClassification(
            "Messages", "Social & Messaging"
        ),
        "com.google.android.youtube": AppClassification(
            "YouTube", "Video & Entertainment"
        ),
        "com.youtube.android": AppClassification(
            "YouTube", "Video & Entertainment"
        ),
        "com.zhiliaoapp.musically": AppClassification(
            "TikTok", "Video & Entertainment"
        ),
        "com.spotify.music": AppClassification("Spotify", "Music & Audio"),
        "com.android.chrome": AppClassification("Chrome", "Web & Search"),
        "com.google.android.googlequicksearchbox": AppClassification(
            "Google", "Web & Search"
        ),
        "com.duolingo": AppClassification("Duolingo", "Learning"),
        "com.google.android.apps.maps": AppClassification(
            "Google Maps", "Navigation"
        ),
        "com.google.android.gm": AppClassification(
            "Gmail", "Email & Communication"
        ),
        "com.sec.android.app.launcher": AppClassification(
            "One UI Home", DEFAULT_CATEGORY
        ),
        "com.sec.android.app.clockpackage": AppClassification(
            "Clock", DEFAULT_CATEGORY
        ),
        "com.android.vending": AppClassification(
            "Google Play Store", DEFAULT_CATEGORY
        ),
    }
)


def classify_app(
    app_id: str,
    app_name: str | None,
    category: str | None,
) -> AppClassification:
    normalized_app_id = app_id.strip()
    known_classification = _KNOWN_APPS.get(normalized_app_id.lower())
    if known_classification is not None:
        return known_classification

    supplied_name = app_name.strip() if app_name is not None else ""
    supplied_category = category.strip() if category is not None else ""
    if supplied_category.casefold() == "system & utilities":
        supplied_category = DEFAULT_CATEGORY
    return AppClassification(
        display_name=supplied_name or normalized_app_id,
        category=supplied_category or DEFAULT_CATEGORY,
    )


def is_excluded_from_screen_time(app_id: str) -> bool:
    return app_id.strip().lower() in EXCLUDED_SCREEN_TIME_APP_IDS
