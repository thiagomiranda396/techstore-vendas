import pytest
from fastapi.testclient import TestClient

from techstore_api.config import carregar_config
from techstore_api.main import app


@pytest.fixture(scope="session")
def cliente():
    # base_url local: o TrustedHostMiddleware recusa qualquer outro host.
    with TestClient(app, base_url="http://127.0.0.1", raise_server_exceptions=False) as c:
        yield c


@pytest.fixture(scope="session")
def config():
    return carregar_config()
