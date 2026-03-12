# -*- coding: utf-8 -*-
############
# Packages #
############
import sys
import os
import json
from pathlib import Path
from typing import Dict, Any, List

from elasticsearch import Elasticsearch
from dotenv import load_dotenv

sys.path.append(str(Path(__file__).parents[2]))
#######################
# Internal Imports #
#######################


#########
# Utils #
#########

def normalize_api_key(raw: str) -> str:
    if raw.startswith("essu_"):
        return raw[5:].strip()
    return raw.strip()


def load_env_values() -> Dict[str, str]:
    project_root = Path(__file__).parents[1]
    env_path = project_root / ".env"
    load_dotenv(dotenv_path=env_path)
    es_url = os.getenv("ES_URL")
    api_key = os.getenv("API_KEY")
    if es_url is None or api_key is None:
        raise RuntimeError("ES_URL or API_KEY missing in .env")
    print(f"ES_URL: {es_url}")
    print(f"API_KEY: {api_key}")
    return {"ES_URL": es_url, "API_KEY": api_key}


def build_bulk_body(lines: List[str]) -> str:
    cleaned = [line.strip() for line in lines if line.strip()]
    rewritten: List[str] = []
    for i in range(0, len(cleaned), 2):
        meta = cleaned[i].replace('"products"', '"temp_tp_matching"')
        doc = cleaned[i + 1]
        rewritten.append(meta)
        rewritten.append(doc)
    return "\n".join(rewritten) + "\n"


def setup_temp_tp_matching() -> None:
    """Create the temp_tp_matching index on a cloud cluster and bulk index sample products."""
    project_root = Path(__file__).parents[1]
    env_values: Dict[str, str] = load_env_values()
    es_url = env_values["ES_URL"].rstrip("/")
    api_key = normalize_api_key(env_values["API_KEY"])

    mapping_path = project_root / "install" / "es_data" / "mapping_products.json"
    mapping_data: Dict[str, Any] = json.loads(mapping_path.read_text(encoding="utf-8"))
    index_body: Dict[str, Any] = {
        "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 0,
        },
        "mappings": mapping_data["mappings"],
    }

    bulk_path = project_root / "install" / "es_data" / "products_bulk.ndjson"
    lines = bulk_path.read_text(encoding="utf-8").splitlines()
    bulk_body = build_bulk_body(lines)

    es = Elasticsearch(
        hosts=[es_url],
        api_key=api_key,
        request_timeout=60,
        max_retries=3,
        retry_on_timeout=True,
    )
    try:
        create_response = es.indices.create(
            index="temp_tp_matching", body=index_body, ignore=400
        )
        print("Create index response:", create_response)

        bulk_response = es.bulk(body=bulk_body)
        print("Bulk errors:", bulk_response.get("errors"))
    finally:
        es.close()


if __name__ == "__main__":
    setup_temp_tp_matching()

# -*- coding: utf-8 -*-
############
# Packages #
############
import sys
from pathlib import Path
from typing import Dict, Any, List

from elasticsearch import Elasticsearch
from dotenv import load_dotenv

sys.path.append(str(Path(__file__).parents[1]))
#######################
# Internal Imports #
#######################
from install.create_temp_index import load_env_values, normalize_api_key


#########
# Utils #
#########

def build_bulk_body(lines: List[str]) -> str:
    """Build a bulk request body for temp_tp_matching from products_bulk.ndjson."""
    cleaned = [line.strip() for line in lines if line.strip()]
    rewritten: List[str] = []
    for i in range(0, len(cleaned), 2):
        meta = cleaned[i].replace('"products"', '"temp_tp_matching"')
        doc = cleaned[i + 1]
        rewritten.append(meta)
        rewritten.append(doc)
    return "\n".join(rewritten) + "\n"


def bulk_temp_tp_matching() -> None:
    """Index the sample products into temp_tp_matching on the cloud cluster."""
    project_root = Path(__file__).parents[1]
    env_values: Dict[str, str] = load_env_values()
    es_url = env_values["ES_URL"].rstrip("/")
    api_key = normalize_api_key(env_values["API_KEY"])

    bulk_path = project_root / "install" / "es_data" / "products_bulk.ndjson"
    lines = bulk_path.read_text(encoding="utf-8").splitlines()
    bulk_body = build_bulk_body(lines)

    es = Elasticsearch(
        hosts=[es_url],
        api_key=api_key,
        request_timeout=60,
        max_retries=3,
        retry_on_timeout=True,
    )
    try:
        response = es.bulk(body=bulk_body)
        print("Bulk errors:", response.get("errors"))
    finally:
        es.close()


if __name__ == "__main__":
    bulk_temp_tp_matching()

