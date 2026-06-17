# Lab 2D: Vector Search in C#

**Time**: ~15 min  
**Environment**: .NET 10 terminal

In this exercise you will explore semantic similarity search using Azure Cosmos DB vector capability.

The lab uses a single project in the `2D_Vector_Search` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed and Azure OpenAI configured with embeddings capability.

```bash
dotnet --version
```

## Setup

1. Open a terminal in the `2D_Vector_Search` directory:

   ```bash
   cd 2D_Vector_Search
   ```

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth. Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

2. Set required environment variables:

   ```bash
   export COSMOS_ENDPOINT="https://YOUR_ACCOUNT.documents.azure.com:443"
   export FOUNDRY_ENDPOINT="https://YOUR_FOUNDRY.openai.azure.com"
   export EMBEDDINGS_ENDPOINT="https://YOUR_EMBEDDINGS.openai.azure.com"
   export EMBEDDINGS_KEY="YOUR_EMBEDDINGS_KEY"
   export EMBEDDINGS_MODEL="text-embedding-3-small"  # optional
   ```

## Vector Search Operations

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connection

Set up the Cosmos client connection and Azure OpenAI embeddings client.

### Step 1: Generate Embeddings (Prebuilt)

Creates 3 sample documents, generates embeddings for them using Azure OpenAI, and stores them in the `WorkshopData/Docs` container.

### Step 2: Vector Search (STUDENT EXERCISE)

Write a vector similarity search query using the `VectorDistance` function.

**Expected output**: Top 2 documents most similar to your search query.

### Step 3: Full-Text Search (STUDENT EXERCISE)

Write a full-text search query using `FullTextContains`.

## Lab Complete!

You have completed the vector search exercise in C#. You:
- Connected to Cosmos DB and Azure OpenAI
- Generated embeddings using Azure OpenAI
- Stored vectorized documents in Cosmos DB
- Performed vector similarity search
- Performed full-text search

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
