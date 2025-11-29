import json
import pytest
from unittest.mock import patch, MagicMock

from app.app import app, get_connection


@pytest.fixture
def client():
    app.testing = True
    return app.test_client()


# -----------------------
# GET /users
# -----------------------
def test_get_users(client):
    fake_users = [
        {"id": 1, "name": "Ana", "email": "ana@example.com"},
        {"id": 2, "name": "Joao", "email": "joao@example.com"},
    ]

    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = fake_users

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.get("/users")

    assert response.status_code == 200
    assert response.get_json() == fake_users


# -----------------------
# POST /users
# -----------------------
def test_add_user(client):
    payload = {"name": "Ana", "email": "ana@example.com"}

    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.post("/users", json=payload)

    assert response.status_code == 200
    assert response.get_json()["message"] == "User added successfully"


# -----------------------
# PUT /users/<id>
# -----------------------
def test_update_user(client):
    payload = {"name": "Novo Nome", "email": "novo@example.com"}

    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.put("/users/1", json=payload)

    assert response.status_code == 200
    assert response.get_json()["message"] == "User updated successfully"


# -----------------------
# DELETE /users/<id>
# -----------------------
def test_delete_user(client):
    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.delete("/users/1")

    assert response.status_code == 200
    assert response.get_json()["message"] == "User deleted successfully"
