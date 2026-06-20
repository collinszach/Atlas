from app.services.skywatch.apns import ApnsClient

PEM = "-----BEGIN PRIVATE KEY-----\nMIGF...fake...\n-----END PRIVATE KEY-----\n"


def test_resolve_auth_key_accepts_pem_contents():
    assert ApnsClient._resolve_auth_key(PEM) == PEM


def test_resolve_auth_key_reads_from_path(tmp_path):
    p = tmp_path / "AuthKey_TEST.p8"
    p.write_text(PEM)
    assert ApnsClient._resolve_auth_key(str(p)) == PEM


def test_resolve_auth_key_resolves_backend_relative_path(tmp_path, monkeypatch):
    # A path recorded relative to the repo root (e.g. "backend/secrets/Key.p8")
    # still resolves when the process runs from the backend root, via the
    # backend-root + secrets/ fallback keyed off the module's __file__.
    import app.services.skywatch.apns as apns_mod

    (tmp_path / "secrets").mkdir()
    (tmp_path / "secrets" / "AuthKey_REL.p8").write_text(PEM)
    fake_module = tmp_path / "app" / "services" / "skywatch" / "apns.py"
    monkeypatch.setattr(apns_mod, "__file__", str(fake_module))

    assert ApnsClient._resolve_auth_key("backend/secrets/AuthKey_REL.p8") == PEM


def test_resolve_auth_key_passthrough_for_unknown_value():
    # Not a PEM, not an existing file → returned as-is (lets is_configured stay truthy)
    assert ApnsClient._resolve_auth_key("not-a-real-path") == "not-a-real-path"


def test_resolve_auth_key_empty():
    assert ApnsClient._resolve_auth_key("") == ""


def test_unconfigured_client_noops():
    client = ApnsClient(key_id="", team_id="", auth_key="")
    assert client.is_configured is False
