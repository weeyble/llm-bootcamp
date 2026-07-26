"""Embedding provider factory for document ingest and search."""

import logging
import os
from functools import lru_cache

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_openai import OpenAIEmbeddings


@lru_cache(maxsize=1)
def create_embeddings():
    """Create the configured embedding model.

    Defaults to a local multilingual sentence-transformers model. Set
    EMBEDDING_PROVIDER=openai to use OpenAI embeddings instead.
    """
    provider = os.environ.get("EMBEDDING_PROVIDER", "local").lower()
    logging.getLogger("huggingface_hub").setLevel(logging.ERROR)
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")

    if provider == "openai":
        return OpenAIEmbeddings(
            model=os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
        )

    if provider == "local":
        return HuggingFaceEmbeddings(
            model=os.environ.get(
                "EMBEDDING_MODEL",
                "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
            ),
            encode_kwargs={"normalize_embeddings": True},
            show_progress=False,
        )

    raise ValueError(f"Unsupported EMBEDDING_PROVIDER: {provider}")
