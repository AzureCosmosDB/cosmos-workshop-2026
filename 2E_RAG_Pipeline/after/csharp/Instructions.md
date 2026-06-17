# Lab 2E: RAG Pipeline in C#

**Time**: ~30 min  
**Environment**: .NET 10 terminal

In this exercise you will build a Retrieval-Augmented Generation (RAG) pipeline using Cosmos DB vector search and Azure OpenAI.

The lab uses a single project in the `2E_RAG_Pipeline` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed:

```bash
dotnet --version
```

## Setup

1. Open a terminal in the `2E_RAG_Pipeline` directory:

   ```bash
   cd 2E_RAG_Pipeline
   ```

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth. Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

2. Set required environment variables:

   ```bash
   export COSMOS_ENDPOINT="https://YOUR_ACCOUNT.documents.azure.com:443"
   export FOUNDRY_ENDPOINT="https://YOUR_FOUNDRY.openai.azure.com"
   export EMBEDDINGS_ENDPOINT="https://YOUR_EMBEDDINGS.openai.azure.com"
   export EMBEDDINGS_KEY="YOUR_EMBEDDINGS_KEY"
   export COMPLETIONS_MODEL="YOUR_CHAT_DEPLOYMENT_NAME"  # optional
   export EMBEDDINGS_MODEL="YOUR_EMBEDDINGS_DEPLOYMENT_NAME"  # optional
   ```

## RAG Operations

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connection

Set up the Cosmos DB and Azure OpenAI client connections.

### Step 1: Text Chunking and Seed Documents (Prebuilt)

Loads sample documents and chunks them into 512-character segments.

### Step 2: Embed and Store Chunks (STUDENT EXERCISE)

Generate embeddings for each chunk and store them in the Cosmos DB `Docs` container with vector index.

**Expected output**: Chunks stored with their embeddings.

### Step 3: RAG Retrieval (STUDENT EXERCISE)

Query the vector index to retrieve the most relevant document chunks for a given search query.

### Step 4: RAG Generation (STUDENT EXERCISE)

Combine the retrieved context with a chat model to generate a response.

**Expected output**: A generated answer based on the retrieved context.

## Lab Complete!

You have completed the RAG Pipeline exercise. You:
- Chunks documents into segments
- Generates embeddings for each chunk using Azure OpenAI
- Stores chunks with embeddings in Cosmos DB
- Retrieves relevant chunks using vector search
- Combines retrieved context with chat completions for RAG

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
