def test_root_endpoint(client) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {"message": "LockdIn Backend is running"}


def test_health_endpoint(client) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "LockdIn Backend",
        "version": "0.1.0",
    }
