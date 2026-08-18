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
    """Verify the full revision chain: None -> 001 -> ... -> 013"""
    files = [
        "001_core_tables.py",
        "002_views_stubs.py",
        "003_country_polygons.py",
        "004_photos.py",
        "005_transport_accommodations.py",
        "006_bucket_list.py",
        "007_bucket_list_ai_summary.py",
        "008_skywatch.py",
        "009_seed_skywatch.py",
        "010_fix_notable_common_airliners.py",
        "011_flights_only.py",
        "012_repoint_photos.py",
        "013_drop_travel_tables.py",
    ]
    revisions = {}
    for f in files:
        rev = f.split("_", 1)[0]
        mod = _load_migration(f"m{rev}", f"migrations/versions/{f}")
        revisions[mod.revision] = mod.down_revision

    assert revisions["001"] is None
    for prev, cur in zip(
        ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010", "011", "012"],
        ["002", "003", "004", "005", "006", "007", "008", "009", "010", "011", "012", "013"],
    ):
        assert revisions[cur] == prev
