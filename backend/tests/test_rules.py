import pytest


def test_rules_crud_flow(client) -> None:
    create_response = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.instagram.android",
            "appName": "Instagram",
            "limitMinutes": 120,
            "enabled": True,
        },
    )

    assert create_response.status_code == 201
    created_rule = create_response.json()
    assert created_rule["appId"] == "com.instagram.android"
    assert created_rule["appName"] == "Instagram"
    assert created_rule["limitMinutes"] == 120
    assert created_rule["enabled"] is True

    list_response = client.get("/api/v1/rules")
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1

    update_response = client.patch(
        f"/api/v1/rules/{created_rule['id']}",
        json={"limitMinutes": 90, "enabled": False},
    )
    assert update_response.status_code == 200
    assert update_response.json()["limitMinutes"] == 90
    assert update_response.json()["enabled"] is False

    delete_response = client.delete(f"/api/v1/rules/{created_rule['id']}")
    assert delete_response.status_code == 204

    final_list_response = client.get("/api/v1/rules")
    assert final_list_response.status_code == 200
    assert final_list_response.json() == []


def test_duplicate_rule_returns_conflict(client) -> None:
    payload = {
        "appId": "com.youtube.android",
        "appName": "YouTube",
        "limitMinutes": 60,
        "enabled": True,
    }

    first_response = client.post("/api/v1/rules", json=payload)
    second_response = client.post("/api/v1/rules", json=payload)

    assert first_response.status_code == 201
    assert second_response.status_code == 409


def test_update_unknown_rule_returns_not_found(client) -> None:
    response = client.patch(
        "/api/v1/rules/missing-rule",
        json={"limitMinutes": 30},
    )

    assert response.status_code == 404


def test_delete_unknown_rule_returns_not_found(client) -> None:
    response = client.delete("/api/v1/rules/missing-rule")

    assert response.status_code == 404


def test_partial_rule_update_preserves_existing_values(client) -> None:
    create_response = client.post(
        "/api/v1/rules",
        json={
            "appId": "com.spotify.music",
            "appName": "Spotify",
            "limitMinutes": 45,
            "enabled": True,
        },
    )

    update_response = client.patch(
        f"/api/v1/rules/{create_response.json()['id']}",
        json={"enabled": False},
    )

    assert update_response.status_code == 200
    assert update_response.json() == {
        "id": create_response.json()["id"],
        "appId": "com.spotify.music",
        "appName": "Spotify",
        "limitMinutes": 45,
        "enabled": False,
    }


@pytest.mark.parametrize(
    ("payload", "expected_field"),
    [
        (
            {"appId": "", "appName": "Instagram", "limitMinutes": 60, "enabled": True},
            "appId",
        ),
        (
            {
                "appId": "com.instagram.android",
                "appName": "",
                "limitMinutes": 60,
                "enabled": True,
            },
            "appName",
        ),
        (
            {
                "appId": "com.instagram.android",
                "appName": "Instagram",
                "limitMinutes": 0,
                "enabled": True,
            },
            "limitMinutes",
        ),
    ],
)
def test_create_rule_validation_errors(client, payload, expected_field) -> None:
    response = client.post("/api/v1/rules", json=payload)

    assert response.status_code == 422
    assert any(error["loc"][-1] == expected_field for error in response.json()["detail"])
