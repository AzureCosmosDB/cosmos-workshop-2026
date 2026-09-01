# Lab 2D: Vector Search in C#

**Time**: ~20 min

**Environment**: .NET 10 terminal

In this exercise you will compare vector, full-text, and hybrid search using Azure Cosmos DB.

The lab uses a single project in the `2D_Vector_Search` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- Azure OpenAI configured with embeddings capability
- Environment variables: `COSMOS_ENDPOINT`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_KEY`, `EMBEDDINGS_MODEL` (optional)

Embeddings go through a separate Azure OpenAI resource with API key auth (the v1 embeddings surface does not yet support Entra ID).

> **Note**: `EMBEDDINGS_MODEL` must be a **1536-dimension** model (e.g. `text-embedding-3-small`) to match the `/embedding` vector policy on the pre-provisioned `Docs` container. A model with different dimensions (e.g. `text-embedding-3-large` at 3072) will fail vector writes and queries.

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

**Expected output**: the top 2 documents most similar to *"finding related information based on concepts instead of exact words"*. The **Vector Search** doc ranks first — matched by **meaning**, even though the query shares almost no keywords with it.

### Step 3: Full-Text Search (STUDENT EXERCISE)

Replace the placeholder `ftsQuery` in `Steps_Vector_Search.cs` Step 3 with a `FullTextContains` query:

```csharp
var ftsQuery = new QueryDefinition(
    "SELECT * FROM c WHERE FullTextContains(c.text, @search) AND c.partitionKey = 'docs'")
    .WithParameter("@search", searchText);
```

**Expected output**: the **Provisioned Throughput** doc — the only one whose `text` literally contains the word `"throughput"`. Contrast this with Step 2: full-text search matches **exact keywords**, while vector search matched by **meaning**.

### Step 4: Hybrid Search (STUDENT EXERCISE)

Replace the placeholder `hybridQuery` in `Steps_Vector_Search.cs` Step 4 with a query that combines full-text relevance and vector similarity using Reciprocal Rank Fusion (`RRF`):

```csharp
var hybridQuery = new QueryDefinition("""
    SELECT TOP 3 c.id, c.title, c.text,
        VectorDistance(c.embedding, @emb) AS vectorDistance
    FROM c
    WHERE c.partitionKey = 'docs'
    ORDER BY RANK RRF(
        FullTextScore(c.text, @search),
        VectorDistance(c.embedding, @emb)
    )
    """)
    .WithParameter("@search", keywordText)
    .WithParameter("@emb", queryVector);
```

Do not add `FullTextContains` to the `WHERE` clause. Filtering by the keyword first would remove semantic-only candidates before RRF can combine the rankings.

**Expected output**: **Provisioned Throughput** and **Vector Search** rank near the top. The first matches the keyword `throughput`; the second matches the semantic meaning of the query.

## Lab Complete!

You have completed the vector search exercise in C#. You:
- Connected to Cosmos DB and Azure OpenAI
- Generated embeddings using Azure OpenAI
- Stored vectorized documents in Cosmos DB
- Performed vector similarity search
- Performed full-text search
- Combined vector and full-text rankings with RRF hybrid search

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
