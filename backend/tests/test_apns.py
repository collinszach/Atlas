from app.services.skywatch.apns import ApnsClient

PEM = "-----BEGIN PRIVATE KEY-----\nMIGF...fake...\n-----END PRIVATE KEY-----\n"


def test_resolve_auth_key_accepts_pem_contents():
    assert ApnsClient._resolve_auth_key(PEM) == PEM


def test_resolve_auth_key_reads_from_path(tmp_path):
    p = tmp_path / "AuthKey_TEST.p8"
    p.write_text(PEM)
    assert ApnsClient._resolve_auth_key(str(p)) == PEM


def test_resolve_auth_key_passthrough_for_unknown_value():
    # Not a PEM, not an existing file → returned as-is (lets is_configured stay truthy)
    assert ApnsClient._resolve_auth_key("not-a-real-path") == "not-a-real-path"


def test_resolve_auth_key_empty():
    assert ApnsClient._resolve_auth_key("") == ""


def test_unconfigured_client_noops():
    client = ApnsClient(key_id="", team_id="", auth_key="")
    assert client.is_configured is False
