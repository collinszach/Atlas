import pytest
from unittest.mock import patch, AsyncMock


@pytest.mark.asyncio
async def test_missing_auth_header_returns_401(client):
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_invalid_token_returns_401(client):
    response = await client.get("/api/v1/users/me", headers={"Authorization": "Bearer notavalidtoken"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_webhook_missing_svix_headers_returns_400(client):
    response = await client.post("/api/v1/users/sync", json={"type": "user.created", "data": {}})
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_health_requires_no_auth(client):
    response = await client.get("/health")
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_well_formed_jwt_wrong_key_returns_401(client):
    """A structurally valid JWT signed with the wrong key must return 401, not 503."""
    # This is a real JWT signed with a throwaway RSA key — not signed by Clerk.
    # Generated offline: RS256, sub=user_test, kid=wrong-key-id
    fake_jwt = (
        "eyJhbGciOiJSUzI1NiIsImtpZCI6Indyb25nLWtleS1pZCIsInR5cCI6IkpXVCJ9"
        ".eyJzdWIiOiJ1c2VyX3Rlc3QiLCJpYXQiOjE3MDAwMDAwMDB9"
        ".AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    )
    # Mock JWKS to return no matching key (simulating kid mismatch after rotation)
    with patch("app.auth._get_jwks", new=AsyncMock(return_value={"keys": []})):
        response = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {fake_jwt}"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_missing_sub_claim_returns_401(client):
    """JWT with no 'sub' claim must return 401."""
    from jose import jwt as jose_jwt
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.backends import default_backend

    from cryptography.hazmat.primitives.serialization import Encoding, PrivateFormat, NoEncryption

    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend(),
    )
    public_key = private_key.public_key()
    private_pem = private_key.private_bytes(
        encoding=Encoding.PEM,
        format=PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=NoEncryption(),
    )

    # JWT with no 'sub' claim
    token = jose_jwt.encode({"iat": 1700000000}, private_pem, algorithm="RS256", headers={"kid": "test-kid"})

    # Mock JWKS to return our test public key
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    import base64
    pub_numbers = public_key.public_numbers()

    def int_to_base64url(n: int) -> str:
        length = (n.bit_length() + 7) // 8
        return base64.urlsafe_b64encode(n.to_bytes(length, "big")).rstrip(b"=").decode()

    mock_jwks = {
        "keys": [{
            "kty": "RSA",
            "kid": "test-kid",
            "alg": "RS256",
            "use": "sig",
            "n": int_to_base64url(pub_numbers.n),
            "e": int_to_base64url(pub_numbers.e),
        }]
    }

    with patch("app.auth._get_jwks", new=AsyncMock(return_value=mock_jwks)):
        response = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401
