import pytest


def test_accountability_contact_flow(client) -> None:
    create_response = client.post(
        "/api/v1/accountability/contacts",
        json={
            "email": "john@example.com",
            "name": "John Doe",
            "consentConfirmed": False,
        },
    )

    assert create_response.status_code == 201
    created_contact = create_response.json()
    assert created_contact["name"] == "John Doe"
    assert created_contact["email"] == "john@example.com"
    assert created_contact["consentConfirmed"] is False

    list_response = client.get("/api/v1/accountability/contacts")
    assert list_response.status_code == 200
    assert len(list_response.json()) == 1

    delete_response = client.delete(
        f"/api/v1/accountability/contacts/{created_contact['id']}"
    )
    assert delete_response.status_code == 204

    final_list_response = client.get("/api/v1/accountability/contacts")
    assert final_list_response.status_code == 200
    assert final_list_response.json() == []


def test_duplicate_accountability_contact_returns_conflict(client) -> None:
    payload = {
        "email": "friend@example.com",
        "name": "Friend",
        "consentConfirmed": False,
    }

    first_response = client.post("/api/v1/accountability/contacts", json=payload)
    second_response = client.post("/api/v1/accountability/contacts", json=payload)

    assert first_response.status_code == 201
    assert second_response.status_code == 409


def test_accountability_contact_name_defaults_from_email(client) -> None:
    response = client.post(
        "/api/v1/accountability/contacts",
        json={"email": "buddy@example.com", "consentConfirmed": True},
    )

    assert response.status_code == 201
    assert response.json()["name"] == "buddy"
    assert response.json()["consentConfirmed"] is True


def test_accountability_duplicate_email_is_case_insensitive(client) -> None:
    first_response = client.post(
        "/api/v1/accountability/contacts",
        json={"email": "Friend@Example.com", "consentConfirmed": True},
    )
    second_response = client.post(
        "/api/v1/accountability/contacts",
        json={"email": "friend@example.com", "consentConfirmed": False},
    )

    assert first_response.status_code == 201
    assert first_response.json()["email"] == "friend@example.com"
    assert second_response.status_code == 409


def test_delete_unknown_accountability_contact_returns_not_found(client) -> None:
    response = client.delete("/api/v1/accountability/contacts/missing-contact")

    assert response.status_code == 404


@pytest.mark.parametrize(
    ("payload", "expected_field"),
    [
        ({"email": "not-an-email", "consentConfirmed": True}, "email"),
        ({"email": "friend@example.com", "name": "", "consentConfirmed": True}, "name"),
    ],
)
def test_create_accountability_contact_validation_errors(
    client, payload, expected_field
) -> None:
    response = client.post("/api/v1/accountability/contacts", json=payload)

    assert response.status_code == 422
    assert any(error["loc"][-1] == expected_field for error in response.json()["detail"])
