from pathlib import Path
from dashboard.usage import UsageTracker


def test_count_unseen_returns_zero(tmp_path):
    t = UsageTracker(tmp_path / "usage.json")
    assert t.count("foo") == 0


def test_increment_and_count(tmp_path):
    t = UsageTracker(tmp_path / "usage.json")
    t.increment("foo")
    t.increment("foo")
    assert t.count("foo") == 2


def test_persists_across_instances(tmp_path):
    path = tmp_path / "usage.json"
    t1 = UsageTracker(path)
    t1.increment("foo")
    t2 = UsageTracker(path)
    assert t2.count("foo") == 1


def test_missing_file_creates_empty(tmp_path):
    path = tmp_path / "usage.json"
    t = UsageTracker(path)
    assert t.count("anything") == 0
    assert not path.exists()   # file not written until first increment


def test_increment_creates_file(tmp_path):
    path = tmp_path / "usage.json"
    t = UsageTracker(path)
    t.increment("bar")
    assert path.exists()
