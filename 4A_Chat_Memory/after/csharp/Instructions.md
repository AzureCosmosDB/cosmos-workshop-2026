# Lab 4A: Conversational History / Agent Memory in C#

**Time**: ~60 min
**Environment**: .NET 10 terminal

In this exercise you will build a Retrieval-Augmented Generation (RAG) chat agent that persists every conversation turn to Azure Cosmos DB. The persisted turns carry analytics metadata (model, latency, token usage, RAG hits) so they can be mirrored into Fabric and queried in Lab 4B.

The lab uses a single project in the `4A_Chat_Memory` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed:

```bash
dotnet --version
```

The Cosmos DB account must have the following pre-provisioned:

- Database `Conversations`, container `Messages`, partition key `/sessionId` (chat memory).
- Database `WorkshopData`, container `Docs`, partition key `/partitionKey` with a vector index on `/embedding` (RAG corpus).

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth. Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

## Setup

1. Open a terminal in the `4A_Chat_Memory` directory:

   ```bash
   cd 4A_Chat_Memory
   ```

2. Set required environment variables:

   ```bash
   export COSMOS_ENDPOINT="https://YOUR_ACCOUNT.documents.azure.com:443"
   export FOUNDRY_ENDPOINT="https://YOUR_FOUNDRY.openai.azure.com"
   export EMBEDDINGS_ENDPOINT="https://YOUR_EMBEDDINGS.openai.azure.com"
   export EMBEDDINGS_KEY="YOUR_EMBEDDINGS_KEY"
   export COMPLETIONS_MODEL="YOUR_CHAT_DEPLOYMENT_NAME"
   export EMBEDDINGS_MODEL="YOUR_EMBEDDINGS_DEPLOYMENT_NAME"
   ```

## Running the Lab

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connections

Sets up Cosmos DB clients for both the chat-memory and RAG containers, and Azure OpenAI clients for chat completions (Foundry, Entra ID) and embeddings (Azure OpenAI, API key). Generates a fresh `SessionId` for this run.

### Step 1: Seed the RAG Corpus (Prebuilt)

Loads `rag_seed_docs.json`, embeds each document, and upserts it into `WorkshopData/Docs` with `partitionKey = "rag"`. Upserts are idempotent — re-running the step (or having already run Lab 2C) is safe.

**Expected output**: One `Seeded: <title>` line per document, followed by a total count.

### Step 2: Chat Store Message Schema (STUDENT EXERCISE)

Define the JSON shape used for every chat turn and write a helper that persists turns to `Conversations/Messages`. The `metadata` object carries fields that will be queried in T-SQL in Fabric in Lab 4B (model, latency, token usage, RAG hits, retrieved doc IDs).

**Expected output**: A sample message printed as JSON, followed by confirmation that a user turn and an assistant turn were saved to Cosmos.

### Step 3: Retrieve Recent Messages and Run a Vector Search (STUDENT EXERCISE)

Two reads underpin the chat agent: pulling the last N turns for conversational context, and pulling the top-K RAG hits for grounding.

- `GetRecentMessages` queries `Messages` scoped to a single `sessionId` partition, ordered by `_ts DESC`.
- `RetrieveRelevant` embeds the query text and runs a `VectorDistance` ORDER BY against the seeded RAG partition.

**Expected output**: The recent-message count and contents from Step 2, plus three vector-search hits with their scores.

### Step 4: Build the RAG Chat Agent (STUDENT EXERCISE)

Stitch the pieces together: save the user turn, pull recent history, run vector search for grounding, call the LLM, then save the assistant turn with analytics metadata (model, latency, prompt/completion/total tokens, RAG hits, retrieved doc IDs). These nested fields surface as queryable columns when the container is mirrored into Fabric in Lab 4B.

**Expected output**: A grounded answer to the seed question `"How does vector search work in Cosmos DB?"`.

### Step 5: Chat with Your Agent

Interactive chat loop against the same `SessionId`. Enter questions at the `You:` prompt; submit a blank line, `quit`, or `exit` to end. Each turn is persisted, so follow-ups can rely on earlier context (e.g. *"What is Cosmos DB?"* then *"How does that compare to a relational database?"*). When the loop ends, the full session history is printed back from Cosmos.

## Lab Complete!

You have built a Cosmos DB-backed chat agent with persistent memory and RAG grounding. You:

- Connected to Cosmos DB and Azure OpenAI for chat + embeddings.
- Defined a chat-turn schema and a helper that persists turns with analytics metadata.
- Retrieved recent conversation history scoped to a single session partition.
- Performed vector search against a seeded RAG corpus using `VectorDistance`.
- Composed retrieved context + recent history into a grounded chat completion.
- Captured latency, token usage, and RAG hits per turn for downstream analytics in Lab 4B.

To run the lab again from scratch, run `dotnet run` again. A new `SessionId` is generated each run, so history from previous runs stays isolated in Cosmos.
