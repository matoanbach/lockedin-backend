from lockedin_backend.app.main import create_app


def test_app_metadata() -> None:
    app = create_app()

    assert app.title == "LockdIn Backend"
    assert app.version == "0.1.0"
