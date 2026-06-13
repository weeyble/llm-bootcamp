# ローカル Embedding への切り替え手順

このリポジトリの `doc_search` は現在 OpenAI Embeddings 前提です。ローカルモデルへ切り替える場合は、取り込み側と検索側の両方を同じ Embedding 実装に変更し、Milvus DB を作り直します。

## 方針

- 使用モデル: `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2`
- 実装: `langchain_huggingface.HuggingFaceEmbeddings`
- 出力 DB: 既存と同じ `data/milvus.db`

このモデルは日本語クエリにも対応しやすく、ローカル CPU でも比較的軽いです。精度を上げたい場合は後で `intfloat/multilingual-e5-small` や `BAAI/bge-m3` などに差し替えます。

## 1. 依存関係を追加

```bash
uv add langchain-huggingface sentence-transformers
```

Apple Silicon で PyTorch の導入に失敗する場合は、先に以下を試します。

```bash
uv add torch
uv add langchain-huggingface sentence-transformers
```

## 2. 共通の Embedding 生成関数を作る

新規ファイル `agents/embeddings.py` を追加します。

```python
import os

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_openai import OpenAIEmbeddings


def create_embeddings():
    provider = os.environ.get("EMBEDDING_PROVIDER", "local").lower()

    if provider == "openai":
        return OpenAIEmbeddings(
            model=os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small")
        )

    if provider == "local":
        return HuggingFaceEmbeddings(
            model_name=os.environ.get(
                "EMBEDDING_MODEL",
                "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
            ),
            encode_kwargs={"normalize_embeddings": True},
        )

    raise ValueError(f"Unsupported EMBEDDING_PROVIDER: {provider}")
```

OpenAI へ戻せる余地を残すため、`EMBEDDING_PROVIDER=openai` もサポートしておきます。

## 3. 取り込み側を変更

`scripts/web_ingest.py` の import を変更します。

変更前:

```python
from langchain_openai import OpenAIEmbeddings
```

変更後:

```python
from agents.embeddings import create_embeddings
```

次に、Milvus 保存前の Embedding 初期化を変更します。

変更前:

```python
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
```

変更後:

```python
embeddings = create_embeddings()
```

## 4. 検索側を変更

`agents/langgraph/tools/doc_search.py` の import を変更します。

変更前:

```python
import os
from langchain_openai import OpenAIEmbeddings
```

変更後:

```python
from agents.embeddings import create_embeddings
```

`_get_retriever()` 内の Embedding 初期化を変更します。

変更前:

```python
embeddings = OpenAIEmbeddings(model=os.environ.get("EMBEDDING_MODEL", "text-embedding-3-small"))
```

変更後:

```python
embeddings = create_embeddings()
```

## 5. 環境変数を設定

`.env` またはシェルで以下を設定します。

```bash
EMBEDDING_PROVIDER=local
EMBEDDING_MODEL=sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
```

OpenAI の Embedding を使わないだけなら `OPENAI_API_KEY` は Embedding 用には不要になります。ただし LLM 本体が OpenAI を使う設定のままなら、CLI 実行時には引き続き `OPENAI_API_KEY` が必要です。

## 6. 既存 DB を削除して再取り込み

Embedding モデルを変えるとベクトルの次元や意味空間が変わるため、既存の `data/milvus.db` は再利用しません。

```bash
make clean
make ingest
```

初回実行時は Hugging Face からモデルをダウンロードするため時間がかかります。以降はローカルキャッシュが使われます。

## 7. 動作確認

```bash
make cli
```

CLI で以下のような質問を試します。

```text
MLflowで実験を記録する方法を教えて
```

検索結果が返らない、または Milvus の次元不一致エラーが出る場合は、`make clean` 後に `make ingest` を再実行してください。

## 注意点

- 取り込み時と検索時は必ず同じ `EMBEDDING_PROVIDER` と `EMBEDDING_MODEL` を使います。
- ローカルモデルは OpenAI の `text-embedding-3-small` と検索品質が変わります。
- モデルを変更したら必ず `data/milvus.db` を作り直します。
- `langchain-openai` は LLM 側や OpenAI fallback 用に残しておいて問題ありません。
