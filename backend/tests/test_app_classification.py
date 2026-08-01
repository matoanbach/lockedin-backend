from lockedin_backend.services.app_classification import classify_app


def test_known_package_has_canonical_label_and_category() -> None:
    classification = classify_app(
        "com.whatsapp",
        "com.whatsapp",
        "Other",
    )

    assert classification.display_name == "WhatsApp"
    assert classification.category == "Social & Messaging"


def test_unknown_package_preserves_useful_supplied_metadata() -> None:
    classification = classify_app(
        "com.example.reader",
        "Example Reader",
        "Reading",
    )

    assert classification.display_name == "Example Reader"
    assert classification.category == "Reading"


def test_unknown_package_uses_safe_blank_fallbacks() -> None:
    classification = classify_app("com.example.unknown", "  ", None)

    assert classification.display_name == "com.example.unknown"
    assert classification.category == "Other"


def test_youtube_aliases_have_the_same_classification() -> None:
    google_package = classify_app(
        "com.google.android.youtube", "Package label", "Other"
    )
    alternate_package = classify_app("com.youtube.android", "YouTube", "Video")

    assert google_package == alternate_package
    assert google_package.display_name == "YouTube"
    assert google_package.category == "Video & Entertainment"
