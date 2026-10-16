"""Executa a API só em endereço local: python -m techstore_api (dentro de api/)."""

import logging

import uvicorn

from .config import carregar_config


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    config = carregar_config()  # recusa TECHSTORE_API_HOST que não seja local
    uvicorn.run(
        "techstore_api.main:app",
        host=config.api_host,
        port=config.api_porta,
        proxy_headers=False,
        server_header=False,
        access_log=True,
    )


if __name__ == "__main__":
    main()
