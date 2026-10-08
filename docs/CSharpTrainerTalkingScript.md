---
title: C# Workshop Trainer Talking Script
description: Presenter-ready technical narration and live support cues for all Azure Cosmos DB workshop labs
author: Microsoft
ms.date: 2026-10-08
ms.topic: guide
keywords:
  - Azure Cosmos DB
  - C#
  - workshop
  - trainer
  - RAG
estimated_reading_time: 30
---

## How to use this script

Use the quoted text as your spoken narrative. Each lab includes:

* A 60- to 90-second opening
* The C# concepts to emphasize
* The output that proves success
* Fast troubleshooting guidance
* A transition to the next lab

Students should work in each lab's `before/csharp` folder and run:

```powershell
dotnet run
```

The console pauses between steps. Ask students to complete only the marked
`STUDENT EXERCISE` sections. The `after/csharp` folder is the recovery reference,
not the starting point.

## Opening the workshop

> Today we will build one connected application journey. We start with the
> Cosmos DB resource model and the .NET SDK, then measure query and indexing
> costs, design documents around access patterns, add embeddings and search,
> build and evaluate a RAG pipeline, persist conversational memory, and finally
> analyze that operational data through Fabric.
>
> The recurring engineering question is not only, "Does it work?" We will also
> ask, "What did it cost in request units, how does it scale, where is state
> stored, and how do we prove the answer is grounded?"

### Pre-flight message

> Before Lab 1B, confirm that you ran `az login`, `SetEnv.ps1`, and
> `1B_Account_Access.ps1`. Open a fresh PowerShell window after `SetEnv.ps1`.
> Environment variables are copied into a process when that process starts, so
> an already-open terminal will not automatically receive new user-scoped
> values.

Check these values:

```powershell
$env:COSMOS_ENDPOINT
$env:COSMOS_ENDPOINT_PROVISIONED
$env:FOUNDRY_ENDPOINT
$env:EMBEDDINGS_ENDPOINT
$env:COMPLETIONS_MODEL
$env:EMBEDDINGS_MODEL
```

## Lab 1B: SDK CRUD

### Say this

> This lab establishes the lowest-level application contract with Cosmos DB.
> A Cosmos item is identified by two values together: its `id` and its logical
> partition-key value. That is why reads and deletes take both values.
>
> We authenticate with Microsoft Entra ID through `DefaultAzureCredential`.
> We are not placing account keys in source code. The client targets one
> database and one container, then performs create, point read, upsert, and
> delete operations asynchronously.
>
> Watch the difference between operations. Create and upsert send the full
> document. Point read and delete use the item ID plus partition key. A point
> read is the most efficient retrieval path because Cosmos can route directly
> to one logical partition and one item.

### Coach the C# exercise

Students complete four SDK calls:

```csharp
await container.CreateItemAsync<CatalogItem>(
    item,
    new PartitionKey("workshop"));

await container.ReadItemAsync<CatalogItem>(
    itemId,
    new PartitionKey("workshop"));

await container.UpsertItemAsync<CatalogItem>(
    item,
    new PartitionKey("workshop"));

await container.DeleteItemAsync<CatalogItem>(
    itemId,
    new PartitionKey("workshop"));
```

Point out:

* `CreateItemAsync` fails with HTTP 409 if the item already exists
* `UpsertItemAsync` creates or replaces based on the ID and partition key
* The same partition-key value must be supplied on every point operation
* HTTP 204 on delete is success and intentionally has no response body

### Proof of success

The console shows:

* The created GUID
* The full item JSON
* The price changing from `42.0` to `55.0`
* `NoContent` after deletion

### If a student is blocked

* A 403 mentioning a missing data action usually means Cosmos data-plane RBAC
  has not propagated. Rerun `1B_Account_Access.ps1`, wait, and restart the app.
* A 403 saying the request came from an IP through the public internet is not an
  RBAC problem. It means the Cosmos hostname resolved publicly instead of
  through the private endpoint. Flush DNS and escalate the lab environment.
* A 409 on create means an earlier run left the item behind. Complete the delete
  step or remove that item before rerunning.

### Transition

> CRUD gives us correctness. Next we examine how retrieval shape changes cost.

## Lab 1D1: Query Language

### Say this

> Cosmos DB for NoSQL uses a SQL-like query language over JSON, but it is not
> T-SQL. The alias, property paths, array functions, and partition scope all
> matter.
>
> The most important comparison is point read versus query. If we know both the
> ID and partition key, `ReadItemAsync` avoids query planning and index lookup.
> A query can still be efficient, but it solves a broader problem and therefore
> costs more request units.
>
> We parameterize values with `QueryDefinition`. Parameters keep values separate
> from query text and avoid hand-built string escaping. For result sets, the SDK
> uses `FeedIterator<T>` because results may span multiple pages.

### Coach the C# exercise

Use this mental model for every query:

1. Define the projection and filters.
2. Bind parameters.
3. Decide whether the request can be scoped to one partition.
4. Iterate while `HasMoreResults`.
5. Inspect `RequestCharge` on each page.

Call out these syntax examples:

```csharp
new QueryDefinition("SELECT * FROM c WHERE c.category = @cat")
    .WithParameter("@cat", category);
```

```sql
SELECT c.name,
       CONCAT(c.category, ' category') AS category,
       c.nutrition.calories
FROM c
WHERE ARRAY_CONTAINS(c.tags, 'organic')
  AND c.nutrition.calories < 100
```

Explain that the nested-array subquery runs within each item:

```sql
(SELECT VALUE COUNT(1) FROM v IN c.nutrition.vitamins)
```

### Proof of success

Students should see:

* Apples, Bananas, and Dates for the fruit filter
* A lower RU charge for the point read than the equivalent query
* Three products ordered by descending price
* Apples, Broccoli, and Carrots for the JSON and array filter
* A vitamin count for each item

### If a student is blocked

* Check exact JSON property casing.
* Check that every property reference uses the `c.` alias.
* If the query returns no rows, confirm Step 1 seeded the items.
* If iteration returns only one page, that can be correct for this small data
  set. The iterator pattern still matters for production-sized results.

### Transition

> Queries consume the index. The next lab shows that indexing is not free,
> especially on writes.

## Lab 1D2: Indexing Policy

### Say this

> Cosmos DB indexes every property by default. That gives excellent query
> flexibility, but each write pays to maintain those index entries.
>
> We compare two containers containing the same document. The default container
> indexes everything. The custom container excludes a large scalar value with
> `/largeBlob/?` and an entire nested subtree with `/metadata/*`.
>
> The distinction is precise: `?` excludes the value at that path, while `*`
> excludes all descendants under a path. The application payload is unchanged.
> Only the index maintenance work changes.

### Coach the C# exercise

Students inspect the deployed policy through:

```csharp
var properties = await container.ReadContainerAsync();
var excluded = properties.Resource.IndexingPolicy.ExcludedPaths
    .Select(path => path.Path)
    .ToList();
```

Ask them to compare `RequestCharge` from writes to both containers. Emphasize
that this is a write-cost experiment, not a data-size experiment.

### Proof of success

The custom container reports both excluded paths, and writes to it consume fewer
RUs than equivalent writes to the default-index container.

### If a student is blocked

* These containers are pre-provisioned. Entra data-plane tokens cannot create or
  alter containers, so the lab only reads the policies.
* Policy changes are asynchronous. If demonstrating a manual change, allow time
  for transformation to complete.
* Do not exclude a path that a production query needs to filter or order by.

### Transition

> Indexing optimizes storage for known queries. Data modeling goes deeper: it
> shapes the documents themselves around those access patterns.

## Lab 1E: Data Modeling and Partition Keys

### Say this

> Relational modeling minimizes duplication. Cosmos DB modeling minimizes the
> cost and latency of the application's important access patterns.
>
> First, we assemble one order from a normalized model. Because Cosmos queries
> do not join across containers, each reference becomes another network
> round-trip and another RU charge. Then we read the embedded order with one
> point read.
>
> Embedding is not universally better. It moves complexity to writes. If a
> customer's address changes, historical order snapshots may intentionally stay
> unchanged, or a change-feed processor may fan the update out to affected
> documents.
>
> The second half addresses distribution. A date-only partition key sends all
> of today's writes to one logical partition. A synthetic key such as
> `customerId#orderDate` adds cardinality and distributes writes.

### Coach the C# exercise

The three student decisions are:

```csharp
var response = await orders.ReadItemAsync<OrderDocument>(
    targetOrderId,
    partitionKey);
```

```csharp
new QueryDefinition(
    "SELECT * FROM c " +
    "WHERE c.docType = 'order' AND c.customerName = @name")
    .WithParameter("@name", customerName);
```

```csharp
var partitionKey = $"{customerId}#{today}";
```

Frame the design discussion around:

* Which objects are read together?
* Which fields change independently?
* Which values have enough cardinality to spread writes?
* Which queries can supply a partition-key value?
* Is duplicated data a snapshot or synchronized state?

### Proof of success

Students should observe:

* Seven or more round-trips for the reference model
* One point read for the embedded order
* Two orders returned for Alice Anderson
* One distinct date partition versus about 50 synthetic partitions

### If a student is blocked

* Steps 0 through 4 use `COSMOS_ENDPOINT`.
* Steps 5 through 7 use `COSMOS_ENDPOINT_PROVISIONED`.
* A small workshop data set remains on one physical partition. The distinct
  logical partition values prove the distribution strategy even when the portal
  heat map is not visually dramatic.

### Transition

> We now have operational data and efficient access patterns. The next stage
> adds model inference and converts text into vectors.

## Lab 2C: Completions and Embeddings

### Say this

> Chat completion and embedding are different model operations. Chat completion
> generates tokens from a sequence of messages. An embedding maps text to a
> fixed-length numeric vector so that mathematical distance represents semantic
> similarity.
>
> The system message defines behavior, the user message supplies intent, and
> completion options control generation. Streaming does not change the model's
> answer. It changes delivery latency by exposing incremental content updates.
>
> The embedding model returns 1,536 dimensions in this workshop. That dimension
> count must match the Cosmos container's vector policy.

### Coach the C# exercise

Point out the three SDK patterns:

```csharp
await chatClient.CompleteChatAsync(messages, options);
```

```csharp
await foreach (var update in chatClient.CompleteChatStreamingAsync(messages))
{
    foreach (var part in update.ContentUpdate)
    {
        Console.Write(part.Text);
    }
}
```

```csharp
var embeddingClient = openAIClient.GetEmbeddingClient(embeddingModel);
var embedding = embeddingClient.GenerateEmbedding(text);
float[] vector = embedding.Value.ToFloats().ToArray();
```

Explain cosine similarity as the normalized angle between two vectors. Larger
similarity means closer meaning, not necessarily shared keywords.

### Proof of success

Students should see:

* A partitioning answer plus token usage
* A streamed response arriving in chunks
* Non-zero embedding values
* Higher similarity for semantically related text

### If a student is blocked

* A 404 usually means the deployment name in `COMPLETIONS_MODEL` or
  `EMBEDDINGS_MODEL` is stale.
* A 401 on embeddings means the endpoint or key is wrong.
* If the vectors contain only zeros, the exercise placeholder remains.
* A 429 is capacity throttling. Pause briefly, then retry rather than creating a
  tight retry loop.

### Transition

> We have vectors. Next we store them beside the documents and compare semantic,
> lexical, and hybrid retrieval.

## Lab 2D: Vector, Full-Text, and Hybrid Search

### Say this

> This lab separates three retrieval signals.
>
> Vector search answers, "Which documents are closest in meaning?" Full-text
> search answers, "Which documents contain this term?" Hybrid search combines
> both ranked lists with reciprocal rank fusion, or RRF.
>
> The container is already configured with a 1,536-dimension vector policy on
> `/embedding`, a DiskANN vector index, full-text policies for the searchable
> text, and account-level vector and full-text capabilities.
>
> The hybrid query must not use `FullTextContains` as a pre-filter. Doing that
> would remove semantic-only candidates before RRF could combine the rankings.

### Coach the C# exercise

Vector retrieval:

```sql
SELECT TOP 2 c.id,
             c.title,
             c.text,
             VectorDistance(c.embedding, @emb) AS score
FROM c
WHERE c.partitionKey = 'docs'
ORDER BY VectorDistance(c.embedding, @emb)
```

Full-text retrieval:

```sql
SELECT *
FROM c
WHERE FullTextContains(c.text, @search)
  AND c.partitionKey = 'docs'
```

Hybrid ranking:

```sql
SELECT TOP 3 c.id,
             c.title,
             c.text,
             VectorDistance(c.embedding, @emb) AS vectorDistance
FROM c
WHERE c.partitionKey = 'docs'
ORDER BY RANK RRF(
    FullTextScore(c.text, @search),
    VectorDistance(c.embedding, @emb)
)
```

`TOP 3` means one `ReadNextAsync()` call may contain the complete result, but a
`FeedIterator<T>` loop remains the general production pattern.

### Proof of success

Students should see:

* The Vector Search document ranked first by semantic meaning
* The Provisioned Throughput document returned by the exact keyword
* Both signals represented near the top of the hybrid result

### If a student is blocked

* A vector dimension error means the model output and container policy differ.
* No full-text output can mean the account capability, full-text policy, or
  full-text index is missing.
* A 403 mentioning a public source IP means private DNS is wrong. It is not
  caused by the RRF query.
* Confirm the query uses partition key `docs`, not `rag`.

### Transition

> Search returns evidence. RAG turns that evidence into grounded generation.

## Lab 2E: RAG Pipeline

### Say this

> A RAG pipeline has two phases. Ingestion chunks documents, embeds each chunk,
> and stores the vector with its source text. Inference embeds the question,
> retrieves the nearest chunks, and places those chunks into the model prompt.
>
> Retrieval quality sets an upper bound on answer quality. The model cannot
> ground itself in evidence that retrieval did not return.
>
> Chunk size is a tradeoff. Large chunks preserve context but add noise and
> consume more tokens. Small chunks are precise but can separate facts from
> their explanation. This lab uses sentence-aware chunks of about 512
> characters to make the mechanics visible.

### Coach the C# exercise

Students implement the retrieval query:

```sql
SELECT TOP {topK} c.text,
                  c.title,
                  VectorDistance(c.embedding, @emb) AS score
FROM c
WHERE c.partitionKey = 'rag'
ORDER BY VectorDistance(c.embedding, @emb)
```

They then ground the model with a system prompt:

```csharp
var systemPrompt =
    $"You are a helpful assistant. Answer the user's question based on " +
    $"the following context:\n\n<context>{context}</context>";
```

Explain the boundary clearly:

* Cosmos performs retrieval.
* Application code assembles context.
* The chat model generates the answer.
* Source IDs should be retained for attribution and evaluation.

### Proof of success

The console prints:

* Chunk counts
* RU charges while indexing the corpus
* Three retrieved chunks ordered by similarity
* An answer grounded in those chunks

### If a student is blocked

* Empty retrieval usually means Step 2 did not store embeddings in the `rag`
  partition.
* Query `SELECT VALUE COUNT(1) FROM c WHERE IS_ARRAY(c.embedding)` to verify
  vectorized documents exist.
* Lab 2F depends on this lab's `rag` data, so do not skip ingestion.

### Transition

> A grounded-looking answer is not proof of quality. Next we measure the
> pipeline against expected answers.

## Lab 2F: RAG Evaluation

### Say this

> Evaluation converts subjective impressions into a repeatable loop. We define a
> fixed set of questions and ground-truth answers, run the RAG pipeline, then ask
> a judge model to score relevance from one to five.
>
> The judge prompt is an API contract. If we require one digit, the parser can
> validate the output deterministically. A vague request for feedback would
> produce prose that is harder to aggregate.
>
> LLM-as-judge is useful, but it is not objective truth. Production evaluation
> should combine automated scoring, representative data, regression thresholds,
> and human review.

### Coach the C# exercise

The scoring prompt includes:

* The question
* The generated answer
* The ground truth
* A strict one-digit output contract

The parser accepts only scores from 1 through 5. The placeholder asks for `0`,
so a parse failure is intentional evidence that the student step is incomplete.

### Proof of success

Students see one valid score per test case and an average mapped to a
recommendation.

### If a student is blocked

* Confirm Lab 2E populated `WorkshopData/Docs` with `partitionKey = 'rag'`.
* If every score is unparseable, inspect the judge prompt and model response.
* If scores vary between runs, explain that model-based evaluation is
  probabilistic. Compare trends and thresholds rather than one isolated number.

### Transition

> We can now retrieve, generate, and evaluate. The next lab adds durable
> conversational state and operational telemetry.

## Lab 4A: Chat Memory and RAG Agent

### Say this

> A chat model is stateless between requests. Conversation memory exists only
> because the application stores previous turns and sends selected history back
> with the next request.
>
> We store each user and assistant turn as a separate Cosmos item, partitioned
> by `sessionId`. That co-locates one conversation for efficient ordered reads
> and isolates concurrent sessions.
>
> The agent combines two contexts: recent conversation history for continuity
> and vector-retrieved documents for factual grounding. It also stores latency,
> token usage, RAG hits, and retrieved document IDs with assistant messages.
> Those fields become the analytical contract for Lab 4B.

### Coach the C# exercise

Students retrieve recent turns within one session partition:

```sql
SELECT *
FROM c
WHERE c.sessionId = @sessionId
ORDER BY c._ts DESC
OFFSET 0 LIMIT {count}
```

They compose the system message from:

```csharp
var systemContent =
    $"{baseSystemPrompt}\n\n" +
    $"Use the following retrieved context to ground your answer:\n" +
    $"{contextText}\n\n" +
    $"Chat history:\n{history}";
```

Discuss why:

* `sessionId` is both the filter and partition-key value
* `_ts` provides server-maintained ordering
* A bounded history window controls prompt cost
* User and assistant turns remain independently queryable
* Metadata enables latency, token, and retrieval analysis

### Proof of success

Students should see:

* Seed documents upserted safely
* A sample user and assistant message saved
* Recent turns returned in order
* Three vector-search hits
* A grounded answer
* Follow-up questions that use previous context

### If a student is blocked

* A new `SessionId` is generated on every run. Old history is intentionally
  isolated.
* If a follow-up forgets context, check that recent messages are included in
  the system content.
* If retrieval works but generation is generic, inspect the context block in
  the prompt.
* Foundry chat uses Entra authentication. Restart the app after renewing
  `az login` so cached credentials are refreshed.

### Transition

> The agent has produced operational data. The final lab separates operational
> writes from analytical reads.

## Lab 4B: Fabric Mirror Analytics

### Say this

> Fabric mirroring creates a near-real-time analytical copy of the Cosmos
> `Messages` container in OneLake. The application continues to read and write
> Cosmos DB, while analytical queries run against the mirror with zero request
> unit impact on the operational account.
>
> The SQL endpoint exposes document fields as columns. Nested `metadata` remains
> JSON, so T-SQL uses `JSON_VALUE`, `JSON_QUERY`, and `OPENJSON` to extract scalar
> values and expand arrays.
>
> This is an HTAP pattern: one operational data model supports the live agent,
> while a decoupled analytical surface supports reporting without an ETL
> pipeline competing with production traffic.

### Coach the exercises

Build the analysis from simple to operationally meaningful:

1. Smoke-test recent rows ordered by `_ts`.
2. Count messages by day and role.
3. Rank sessions by turn count.
4. Group activity by hour.
5. Measure average assistant response length.
6. Calculate p50, p95, and p99 latency.
7. Sum tokens by session.
8. Expand `retrievedDocIds` with `OPENJSON` for source attribution.

Use this pattern for scalar metadata:

```sql
CAST(JSON_VALUE(metadata, '$.latencyMs') AS INT)
```

Use this pattern for arrays:

```sql
CROSS APPLY OPENJSON(
    JSON_QUERY(metadata, '$.retrievedDocIds')
) WITH (docId NVARCHAR(100) '$') AS d
```

### Proof of success

Students should be able to identify:

* The busiest day and role
* The most active session
* The p95 assistant latency
* The highest-token session
* The most frequently retrieved source document

The Cosmos normalized RU chart should remain flat while these analytical
queries run.

### If a student is blocked

* Confirm Lab 4A created several messages first.
* Wait for replication status `Running` and for row counts to populate.
* Fabric queries use T-SQL, not the Cosmos DB for NoSQL query dialect.
* Mirroring is read-only from Fabric. Writes still go through the application
  and Cosmos DB.
* If authentication fails, verify the mirroring role assignment and workspace
  access before falling back to key authentication.

## Closing script

> We started with an item addressed by ID and partition key. We then connected
> query cost to indexing, indexing to data modeling, and data modeling to
> partition distribution.
>
> On that operational foundation, we added embeddings, compared semantic and
> lexical retrieval, fused both signals, grounded generation with retrieved
> evidence, and evaluated the result.
>
> Finally, we made the application stateful by persisting each conversation turn
> and exposed its telemetry to Fabric without adding analytical load to the
> operational database.
>
> The architecture is one connected system: Cosmos DB stores operational state
> and vectors, Foundry provides model inference, the C# application orchestrates
> retrieval and memory, and Fabric analyzes the resulting history.

## Fast support decision tree

| Symptom | First check | Likely action |
|---------|-------------|---------------|
| Cosmos 403 mentions a public source IP | Resolve the Cosmos hostname from the VM | Fix private endpoint or private DNS; do not enable public access |
| Cosmos 403 mentions missing permission or data action | Data-plane role assignment | Rerun `1B_Account_Access.ps1`, wait, and restart |
| Cosmos 401 | Azure CLI session | Run `az login` and restart the process |
| Foundry `DeploymentNotFound` | Deployment environment variables | Rerun `SetEnv.ps1` and open a new terminal |
| Embedding dimension mismatch | Embedding model and vector policy | Use the configured 1,536-dimension model |
| Vector search returns no rows | Partition key and stored embeddings | Confirm `docs` or `rag` and verify vectorized items |
| Full-text or hybrid search returns no output | Account capability and full-text index | Verify full-text capability, policy, and index |
| RAG answer is generic | Retrieved chunks in the system prompt | Inspect retrieval results and prompt composition |
| Evaluation has no context | Lab 2E data | Run Lab 2E before Lab 2F |
| Chat forgets earlier turns | Session-scoped history query | Verify `sessionId`, ordering, and history injection |
| Fabric table is empty | Mirror replication and Lab 4A data | Create chat turns, wait for replication, and retry |
