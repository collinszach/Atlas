"""`is_configured` must not report True for a key that cannot sign.

Production ran for months with APNS_AUTH_KEY pointing at a file that did not
exist. The path was returned as if it were PEM, so `is_configured` said True,
startup logged "APNs configured", and push only failed later at send time.
"""
import pytest

from app.services.skywatch.apns import ApnsClient

_FAKE_PEM = (
    "-----BEGIN PRIVATE KEY-----\n"
    "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\n"
    "-----END PRIVATE KEY-----\n"
)


def test_missing_key_file_is_not_configured():
    client = ApnsClient(
        key_id="ABC1234567",
        team_id="TEAM123456",
        auth_key="/nonexistent/AuthKey_NOPE.p8",
    )
    assert client.is_configured is False


def test_missing_key_file_does_not_masquerade_as_pem():
    """The old code returned the path string itself as the signing key."""
    client = ApnsClient(
        key_id="ABC1234567",
        team_id="TEAM123456",
        auth_key="/nonexistent/AuthKey_NOPE.p8",
    )
    assert "/nonexistent" not in client._auth_key


def test_inline_pem_is_configured():
    client = ApnsClient(key_id="ABC1234567", team_id="TEAM123456", auth_key=_FAKE_PEM)
    assert client.is_configured is True


def test_key_file_is_read_from_disk(tmp_path):
    key = tmp_path / "AuthKey_ABC1234567.p8"
    key.write_text(_FAKE_PEM)
    client = ApnsClient(key_id="ABC1234567", team_id="TEAM123456", auth_key=str(key))
    assert client.is_configured is True
    assert "PRIVATE KEY" in client._auth_key


def test_blank_credentials_are_not_configured():
    client = ApnsClient(key_id="", team_id="", auth_key="")
    assert client.is_configured is False


@pytest.mark.asyncio
async def test_send_no_ops_when_unconfigured():
    client = ApnsClient(
        key_id="ABC1234567", team_id="TEAM123456", auth_key="/nonexistent/x.p8"
    )
    # Must not raise, and must not attempt a request.
    await client.send("devicetoken", {"aps": {"alert": "hi"}})
