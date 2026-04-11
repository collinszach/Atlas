import importlib.util
import os


def _load_migration(name: str, relative_path: str):
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    full_path = os.path.join(base, relative_path)
    spec = importlib.util.spec_from_file_location(name, full_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_migration_001_imports():
    module = _load_migration("migration_001", "migrations/versions/001_core_tables.py")
    assert module.revision == "001"
    assert module.down_revision is None


def test_migration_002_imports():
    module = _load_migration("migration_002", "migrations/versions/002_views_stubs.py")
    assert module.revision == "002"
    assert module.down_revision == "001"


def test_migration_003_imports():
    module = _load_migration("migration_003", "migrations/versions/003_country_polygons.py")
    assert module.revision == "003"
    assert module.down_revision == "002"


def test_migration_chain_is_sequential():
    """Verify the revision chain: None -> 001 -> 002 -> 003"""
    revisions = {}
    for name, path in [
        ("001", "migrations/versions/001_core_tables.py"),
        ("002", "migrations/versions/002_views_stubs.py"),
        ("003", "migrations/versions/003_country_polygons.py"),
    ]:
        mod = _load_migration(f"m{name}", path)
        revisions[mod.revision] = mod.down_revision

    assert revisions["001"] is None
    assert revisions["002"] == "001"
    assert revisions["003"] == "002"
