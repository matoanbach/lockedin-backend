import pytest


def test_get_preferences_returns_seeded_defaults(client) -> None:
    response = client.get("/api/v1/me/preferences")

    assert response.status_code == 200
    assert response.json() == {
        "hasCompletedOnboarding": False,
        "defaultDailyLimitMinutes": 180,
        "notificationTone": "professional",
        "accessibility": {
            "textSizePercent": 100,
            "highContrast": False,
            "largeTapTargets": False,
        },
    }


def test_update_preferences_persists_changes(client) -> None:
    response = client.put(
        "/api/v1/me/preferences",
        json={
            "hasCompletedOnboarding": True,
            "defaultDailyLimitMinutes": 120,
            "notificationTone": "edgy",
            "textSizePercent": 125,
            "highContrast": True,
            "largeTapTargets": True,
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "hasCompletedOnboarding": True,
        "defaultDailyLimitMinutes": 120,
        "notificationTone": "edgy",
        "accessibility": {
            "textSizePercent": 125,
            "highContrast": True,
            "largeTapTargets": True,
        },
    }


def test_update_preferences_partial_update_preserves_existing_values(client) -> None:
    response = client.put(
        "/api/v1/me/preferences",
        json={
            "notificationTone": "fun",
            "highContrast": True,
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "hasCompletedOnboarding": False,
        "defaultDailyLimitMinutes": 180,
        "notificationTone": "fun",
        "accessibility": {
            "textSizePercent": 100,
            "highContrast": True,
            "largeTapTargets": False,
        },
    }


@pytest.mark.parametrize(
    ("payload", "expected_field"),
    [
        ({"defaultDailyLimitMinutes": 0}, "defaultDailyLimitMinutes"),
        ({"textSizePercent": 74}, "textSizePercent"),
        ({"textSizePercent": 151}, "textSizePercent"),
        ({"notificationTone": "loud"}, "notificationTone"),
    ],
)
def test_update_preferences_validation_errors(client, payload, expected_field) -> None:
    response = client.put("/api/v1/me/preferences", json=payload)

    assert response.status_code == 422
    assert any(error["loc"][-1] == expected_field for error in response.json()["detail"])
