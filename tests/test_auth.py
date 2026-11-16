import pytest

from webapp.app import create_app, db
from webapp.app.models import Book, User


@pytest.fixture
def app(tmp_path):
    app = create_app({
        "TESTING": True,
        "SQLALCHEMY_DATABASE_URI": f"sqlite:///{tmp_path / 'test.db'}",
        "WTF_CSRF_ENABLED": False,
        "SECRET_KEY": "test-secret",
    })
    with app.app_context():
        db.create_all()
    yield app
    with app.app_context():
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


def register(client, **overrides):
    data = {"name": "Maro User", "email": "maro@example.com", "password": "password123", "password_confirmation": "password123"}
    data.update(overrides)
    return client.post("/register", data=data, follow_redirects=True)


def test_register_hashes_password_and_logs_in(app, client):
    response = register(client)
    assert response.status_code == 200
    with app.app_context():
        user = User.query.one()
        assert user.email == "maro@example.com"
        assert user.password_hash != "password123"
        assert user.check_password("password123")
    assert b"Welcome, Maro User" in response.data


def test_duplicate_email_is_case_insensitive(app, client):
    register(client)
    client.post("/logout")
    response = register(client, email="MARO@EXAMPLE.COM")
    assert b"already exists" in response.data
    with app.app_context():
        assert User.query.count() == 1


@pytest.mark.parametrize("overrides", [
    {"email": "bad"},
    {"password": "short", "password_confirmation": "short"},
    {"password_confirmation": "different"},
])
def test_invalid_registration_rejected(app, client, overrides):
    response = register(client, **overrides)
    assert response.status_code == 200
    with app.app_context():
        assert User.query.count() == 0


def test_invalid_login_message_is_generic(client):
    register(client)
    client.post("/logout")
    wrong = client.post("/login", data={"email": "maro@example.com", "password": "wrongpass"}, follow_redirects=True)
    unknown = client.post("/login", data={"email": "nobody@example.com", "password": "wrongpass"}, follow_redirects=True)
    assert b"Invalid email or password" in wrong.data
    assert b"Invalid email or password" in unknown.data


def test_login_and_logout(client):
    register(client)
    client.post("/logout")
    response = client.post("/login", data={"email": "MARO@example.com", "password": "password123"}, follow_redirects=True)
    assert b"Welcome, Maro User" in response.data
    response = client.post("/logout", follow_redirects=True)
    assert b"You have been logged out" in response.data


def test_external_next_is_ignored(client):
    register(client)
    client.post("/logout")
    response = client.post("/login?next=https://evil.example", data={"email": "maro@example.com", "password": "password123"})
    assert response.status_code == 302
    assert response.headers["Location"] == "/"


def test_csrf_rejects_post(tmp_path):
    app = create_app({"TESTING": True, "SQLALCHEMY_DATABASE_URI": f"sqlite:///{tmp_path / 'csrf.db'}", "SECRET_KEY": "test-secret"})
    response = app.test_client().post("/login", data={"email": "a@example.com", "password": "password123"})
    assert response.status_code == 400


def test_homepage_displays_book_catalogue(app, client):
    with app.app_context():
        db.session.add(Book(
            title="Test Book",
            author="Test Author",
            category="Fiction",
            cover_image="test.svg",
            price="12.50",
            total_quantity=3,
            available_quantity=2,
        ))
        db.session.commit()
    response = client.get("/")
    assert b"Test Book" in response.data
    assert b"Test Author" in response.data
    assert b"2 of 3 available" in response.data
    assert b"Available to borrow" in response.data
