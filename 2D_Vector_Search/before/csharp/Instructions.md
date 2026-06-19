# Lab 2D: Vector Search in C#

**Time**: ~15 min  
**Environment**: .NET 10 terminal

In this exercise you will explore semantic similarity search using Azure Cosmos DB vector capability.

The lab uses a single project in the `2D_Vector_Search` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- Azure OpenAI configured with embeddings capability
- Environment variables: `COSMOS_ENDPOINT`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_KEY`, `EMBEDDINGS_MODEL` (optional)

Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

## Run the lab

```bash
dotnet run
```

The program executes each step in order, pausing for **Enter** between steps.

### Step 0: Initialize Connection

Set up the Cosmos client connection and Azure OpenAI embeddings client.

### Step 1: Generate Embeddings (Prebuilt)

Creates 3 sample documents, generates embeddings for them using Azure OpenAI, and stores them in the `WorkshopData/Docs` container.

### Step 2: Vector Search (STUDENT EXERCISE)

Replace the placeholder `vectorQuery` string in `Steps_Vector_Search.cs` Step 2 with a `VectorDistance` query that returns the top 2 most-similar docs:

```csharp
var vectorQuery = """
    SELECT TOP 2 c.id, c.title, c.text, VectorDistance(c.embedding, @emb) AS score
    FROM c
    WHERE c.partitionKey = 'docs'
    ORDER BY VectorDistance(c.embedding, @emb)
    """;
```

**Expected output**: Top 2 documents most similar to "cosmos db vector search" with their scores.

### Step 3: Full-Text Search (STUDENT EXERCISE)

Replace the placeholder `ftsQuery` in `Steps_Vector_Search.cs` Step 3 with a `FullTextContains` query:

```csharp
var ftsQuery = new QueryDefinition(
    "SELECT * FROM c WHERE FullTextContains(c.text, @search) AND c.partitionKey = 'docs'")
    .WithParameter("@search", searchText);
```

**Expected output**: Documents whose `text` matches `"cosmos db"`.

## Lab Complete!

You have completed the vector search exercise in C#. You:
- Connected to Cosmos DB and Azure OpenAI
- Generated embeddings using Azure OpenAI
- Stored vectorized documents in Cosmos DB
- Performed vector similarity search
- Performed full-text search

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
