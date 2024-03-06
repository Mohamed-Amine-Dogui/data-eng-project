import requests


def test_health(model_endpoint: str) -> None:
    """
    Test health endpoint for a 200.
    The model_endpoint is injected by the pytest parsed, defined in conftest.py at the
    root of tests directory.
    """
    resp = requests.get(f"{model_endpoint}/health")
    assert resp.status_code == 200
