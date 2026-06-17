# Lab 2C: Completions + Embeddings

## Objective
Learn Azure OpenAI chat completions, streaming, and embeddings generation. Practice cosine similarity calculations with generated vectors.

## Prerequisites
- Cosmos DB account endpoint
- Azure AI Foundry endpoint (chat completions, Entra ID auth)
- Azure OpenAI endpoint + key for embeddings (the v1 embeddings surface does not yet support Entra ID)
- Environment variables: `COSMOS_ENDPOINT`, `FOUNDRY_ENDPOINT`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_KEY`, `COMPLETIONS_MODEL` (optional), `EMBEDDINGS_MODEL` (optional)

## Steps

### Step 0: Init (Connection)
Initialize Cosmos DB and Azure OpenAI clients.

### Step 1: Chat Completions (STUDENT EXERCISE)
Make a chat completion call with custom options (temperature, max tokens).

### Step 2: Streaming Response (STUDENT EXERCISE)
Generate a streaming chat completion response using `CompleteChatStreamingAsync`.

### Step 3: Generate Embeddings and Compare (STUDENT EXERCISE)
Generate embeddings for multiple texts and calculate cosine similarity between vectors.

## Run the lab

Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

```bash
dotnet run
```

## Expected Output
- Step 0: Connection confirmation
- Step 1: Chat response about Cosmos DB partitioning
- Step 2: Streaming text output about consistency levels
- Step 3: Embedding dimensions and cosine similarity score
