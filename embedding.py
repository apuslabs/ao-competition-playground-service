# usgin fastapi to build a server on port 8080
# provide three api: createDataset, updateDataset, retrieveData 

import json
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from haystack import Pipeline
from haystack.dataclasses import Document
from haystack.components.writers import DocumentWriter
# Note: the following requires a "pip install sentence-transformers"
from haystack.components.embedders import SentenceTransformersDocumentEmbedder,SentenceTransformersTextEmbedder
from haystack.dataclasses import Document
from haystack_integrations.document_stores.chroma import ChromaDocumentStore
from haystack_integrations.components.retrievers.chroma import ChromaEmbeddingRetriever

app = FastAPI()

indexing_pool = {}

def get_indexing_pool(user_address):
    if user_address not in indexing_pool:
        indexing = Pipeline()
        document_store = ChromaDocumentStore(collection_name=user_address, persist_path=f"./chroma/{user_address}")
        indexing.add_component("embedder", SentenceTransformersDocumentEmbedder())
        indexing.add_component("writer", DocumentWriter(document_store))
        indexing.connect("embedder.documents", "writer.documents")
        indexing_pool[user_address] = indexing
    return indexing_pool[user_address]

querying_pool = {}

def get_querying_pool(user_address):
    if user_address not in querying_pool:
        querying = Pipeline()
        document_store = ChromaDocumentStore(collection_name=user_address, persist_path=f"./chroma/{user_address}")
        querying.add_component("query_embedder", SentenceTransformersTextEmbedder())
        querying.add_component("retriever", ChromaEmbeddingRetriever(document_store))
        querying.connect("query_embedder.embedding", "retriever.query_embedding")
        querying_pool[user_address] = querying
    return querying_pool[user_address]

# meta may be dict or string or None
class DocumentInput(BaseModel):
    content: str
    # meta: dict = None

class Dataset(BaseModel):
    dataset_id: str
    documents: List[DocumentInput]

class CreateDatasetInput(BaseModel):
    list: List[Dataset]

class PromptSearch(BaseModel):
    prompt: str
    reference: str

class DatasetPromptSearch(BaseModel):
    dataset_id: str
    prompts: List[PromptSearch]

class RetrieveInput(BaseModel):
    list: List[DatasetPromptSearch]

@app.post("/create-dataset")
async def create_dataset(input_data: CreateDatasetInput):
    try:
        count = 0
        for dataset in input_data.list:
            indexed_docs = [
                Document(content=doc.content) for doc in dataset.documents
            ]
            indexing = get_indexing_pool(dataset.dataset_id)
            indexing.run({"embedder": {"documents": indexed_docs}})
            count += len(indexed_docs)
        return {"message": "Dataset embedded successfully", "count": count}
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/retrieve-data")
async def retrieve_data(input_data: RetrieveInput):
    try:
        prompt_results = []
        for dataset in input_data.list:
            querying = get_querying_pool(dataset.dataset_id)
            for prompt in dataset.prompts:
                results = querying.run({"query_embedder": {"text": prompt.prompt}})
                documents = results["retriever"]["documents"]
                context_text = ""
                for d in documents[:3]:
                    context_text += d.content + "\n"
                prompt_results.append({
                    "reference": prompt.reference, "result": context_text
                })
        return prompt_results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8082)