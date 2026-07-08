# Lab 2E: RAG Pipeline in C#

**Time**: ~20 min  
**Environment**: .NET 10 terminal

In this exercise you will build a Retrieval-Augmented Generation (RAG) pipeline using Cosmos DB vector search and Azure OpenAI.

The lab uses a single project in the `2E_RAG_Pipeline` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- Environment variables: `COSMOS_ENDPOINT`, `FOUNDRY_ENDPOINT`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_KEY`, `COMPLETIONS_MODEL` (optional), `EMBEDDINGS_MODEL` (optional)

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth. Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

> **Lab order**: This lab seeds the shared RAG corpus into `WorkshopData/Docs` (partition key `rag`) that **Lab 2F** reads for its evaluation. Complete the labs in order — running them out of sequence can leave the `rag` partition empty or mixed with another lab's documents (Lab 4A also writes to this partition).

> **Pre-provisioned container**: The `Docs` container is created in advance by the workshop Bicep template (`bicep/modules/cosmosdb.bicep`) with a vector embedding policy (`/embedding`, 1536 dimensions, cosine) and a DiskANN vector index. The lab stores and queries vectors without creating or configuring the container (Cosmos DB AAD tokens only authorize data-plane operations).

## Run the lab

```bash
dotnet run
```

The program executes each step in order, pausing for **Enter** between steps.

### Step 0: Initialize Connection

Sets up the Cosmos DB and Azure OpenAI client connections.

### Step 1: Text Chunking and Seed Documents (Prebuilt)

Loads sample documents and splits each one into sentence-aware chunks of ~512 characters. You'll watch the chunk counts print so you can confirm the seed loaded.

### Step 2: Embed and Store Chunks (Prebuilt)

Generates embeddings for each chunk and upserts them into the `Docs` container with a `partitionKey` of `"rag"`. Each upsert prints its RU charge. Watching this step lets you see the cost of indexing the corpus before retrieval starts.

### Step 3: RAG Retrieval (STUDENT EXERCISE)

This is the retrieval half of RAG. The helper `RetrieveRelevant` already embeds the user query, opens the iterator, and gathers results — your job is to write the vector-distance query that finds the closest chunks.

Replace the placeholder `vectorQuery` string in `RetrieveRelevant` with:

```csharp
var vectorQuery = $"SELECT TOP {topK} c.text, c.title, VectorDistance(c.embedding, @emb) AS score " +
                  "FROM c " +
                  "WHERE c.partitionKey = 'rag' " +
                  "ORDER BY VectorDistance(c.embedding, @emb)";
```

**Expected output**: 3 retrieved chunks, ordered most-similar first, with scores.

### Step 4: RAG Generation (STUDENT EXERCISE)

This is the generation half — combine retrieved context with the chat model. The helper `GenerateResponse` already calls `RetrieveRelevant`, joins the chunks into a `context` string, and sends the call to the chat client. Your job is to write the **system prompt** that grounds the model in that context.

Replace the placeholder `systemPrompt` in `GenerateResponse` with:

```csharp
var systemPrompt = $"You are a helpful assistant. Answer the user's question based on the following context:\n\n<context>{context}</context>";
```

**Expected output**: An answer that draws from the retrieved chunks (the placeholder prompt has no `<context>` block, so the model answers from training data only — the difference between the two is the whole point of RAG).

## Lab Complete!

You have completed the RAG Pipeline exercise. You:
- Saw how documents are chunked and embedded for retrieval
- Saw RU costs of embedding the corpus into Cosmos DB
- Wrote the `VectorDistance` query that powers retrieval
- Wrote the system prompt that grounds the chat model in retrieved context

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
