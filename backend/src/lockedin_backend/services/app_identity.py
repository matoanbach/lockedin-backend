from __future__ import annotations

APP_ID_CANONICAL_MAP = {
    "com.youtube.android": "com.google.android.youtube",
}


def canonicalize_app_id(app_id: str) -> str:
    stripped_app_id = app_id.strip()
    return APP_ID_CANONICAL_MAP.get(stripped_app_id, stripped_app_id)


def app_id_variants(app_id: str) -> set[str]:
    canonical_app_id = canonicalize_app_id(app_id)
    variants = {app_id.strip(), canonical_app_id}
    variants.update(
        alias_app_id
        for alias_app_id, alias_canonical_app_id in APP_ID_CANONICAL_MAP.items()
        if alias_canonical_app_id == canonical_app_id
    )
    return {variant for variant in variants if variant}
