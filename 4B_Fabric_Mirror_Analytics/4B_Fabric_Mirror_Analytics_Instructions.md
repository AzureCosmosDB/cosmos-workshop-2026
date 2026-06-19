# Lab 4B: Analyzing Chat History with Fabric Mirror

**Time**: ~40 min
**Environment**: Microsoft Fabric portal (browser) — SQL notebook + PySpark notebook + Power BI

In this exercise you will take the conversational history written by Lab 4A and analyze it in Microsoft Fabric. Because Fabric reads from a **mirrored** copy of the `Messages` container in OneLake, every query you run here costs **zero RU** against the live Cosmos DB account — the operational agent keeps serving traffic uninterrupted while you do analytics on the same data.

## Prerequisites

Before starting, confirm:

- You completed **Lab 4A** and the `Messages` container in the `Conversations` database holds at least one multi-turn session. If you only have one turn, run the `chat_agent(...)` cell from 4A a few more times so there is data to aggregate.
- The Cosmos DB account meets the Fabric mirroring requirements (already configured in the pre-deployed infrastructure): NoSQL API, continuous backup enabled, system-assigned identity enabled, and network access reachable from Fabric.
- You can sign in to https://app.fabric.microsoft.com/ with the workshop credentials and you have access to the `CosmosWorkshop` workspace.

---

## Setup

### Step 1: Open the Fabric workspace

1. Navigate to https://app.fabric.microsoft.com/ and sign in with the workshop credentials.
2. Open the pre-provisioned `CosmosWorkshop` workspace.
3. Confirm you can see the workspace's items list — you will create a Mirrored DB and two notebooks here.

---

### Step 2: Mirror the `Messages` container

1. In the workspace, click **+ New item**.
2. Search for and select **Mirrored Azure Cosmos DB for NoSQL**.
3. Enter the Cosmos DB **account URI** from `COSMOS_ENDPOINT`.
4. Choose **Organizational account / Entra ID** for the authentication method (this is preferred over account key).
5. Pick the source database **`Conversations`** and check the **`Messages`** container.
6. Name the mirrored item (for example `Conversations_Mirror`) and click **Mirror database**.
7. On the resulting Mirrored DB page, wait until **Replication status** reads **Running** and **Rows replicated** and **Last completed** columns populate for `Messages`. Initial snapshots typically complete in 1–2 minutes for the workshop volume.

**Expected output**: Mirrored DB item shows **Replication status = Running** and the `Messages` table is visible from the SQL analytics endpoint.

> The mirrored `Messages` table preserves the Cosmos system property `_ts` (a unix epoch in seconds) alongside the document properties you wrote in 4A (`id`, `sessionId`, `role`, `content`, `timestamp`, `metadata`).

---

## T-SQL Analytics (Fabric SQL Notebook)

### Step 3: Create a new SQL notebook

1. From the workspace, click **+ New item** and search for **Notebook**. Name the Notebook `SQL Notebook` and use the default **Location**.
2. In the top toolbar, switch the language from **PySpark** to **T-SQL**.
3. In the **Explorer** pane on the left, under **Data items**, click **Add data items** -> **From OneLake catalog** and select the **SQL Analytics endpoint** for the mirrored database you created in Step 2.
4. Confirm the `Messages` table appears in the Explorer tree.

---

### Step 4: Smoke-test the mirrored table (Prebuilt)

Run this cell first to confirm the mirror is alive and you have rows to aggregate.

```sql
SELECT TOP 10
    id,
    sessionId,
    role,
    content,
    _ts
FROM Conversations.Messages
ORDER BY _ts DESC;
```

**Expected output**: The most recent turns written by your `chat_agent(...)` calls in Lab 4A, newest first.

If this returns zero rows, go back to Lab 4A and run a few more `chat_agent(...)` calls, then wait ~30 seconds for the mirror to catch up before re-running.

---

### Step 5: Aggregate message volume by day and role (STUDENT EXERCISE)

Add a new Code cell to create the next query. Fill in the missing pieces of the query to count messages per day per role.

**Expected output**: One row per `(day, role)` combination with a `MessageCount` column, ordered by day then role.

**Hints**:
- `_ts` is a unix epoch in seconds. Convert it to a date with `DATEADD(SECOND, _ts, '1970-01-01')`, then bucket with `CAST(... AS DATE)`.
- Group by the same expression you select.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT
--     CAST(DATEADD(SECOND, _ts, '1970-01-01') AS DATE) AS Day,
--     role,
--     COUNT(*) AS MessageCount
-- FROM Conversations.Messages
-- GROUP BY CAST(DATEADD(SECOND, _ts, '1970-01-01') AS DATE), role
-- ORDER BY Day, role;
```

> This query runs entirely against OneLake — it consumes **zero RU** on the source Cosmos DB account. Confirm that by checking the **Normalized RU Consumption** chart in the Cosmos DB account's **Metrics** blade in the Azure portal before and after running the query: the line should not move.

---

### Step 6: Identify the most active sessions (STUDENT EXERCISE)

Add another new Code cell. Write a T-SQL query that ranks sessions by total turn count and returns the top 5.

**Expected output**: Up to five rows showing `sessionId` and `TurnCount`, ordered from most to least active.

**Hint**: `GROUP BY sessionId` and use `COUNT(*)`. Use `ORDER BY ... DESC` plus `TOP 5` (or `OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY`).

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT TOP 5
--     sessionId,
--     COUNT(*) AS TurnCount
-- FROM Conversations.Messages
-- GROUP BY sessionId
-- ORDER BY TurnCount DESC;
```

---

### Step 7: Hour-of-day distribution (STUDENT EXERCISE)

Add a new Code cell and fill in the missing pieces of the query to bucket messages by hour-of-day and role.

**Expected output**: Up to 24 rows per role showing `HourOfDay`, `role`, and `MessageCount`, ordered by hour then role.

**Hints**:
- Reuse the `DATEADD(SECOND, _ts, '1970-01-01')` pattern from Step 5, but pull the hour out with `DATEPART(HOUR, ...)`.
- Group by the same expression you select.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT
--     DATEPART(HOUR, DATEADD(SECOND, _ts, '1970-01-01')) AS HourOfDay,
--     role,
--     COUNT(*) AS MessageCount
-- FROM Conversations.Messages
-- GROUP BY DATEPART(HOUR, DATEADD(SECOND, _ts, '1970-01-01')), role
-- ORDER BY HourOfDay, role;
```

---

### Step 8: Average assistant response length per session (STUDENT EXERCISE)

Add a new Code cell. Write a query that computes the average character length of `assistant` responses per session, ordered by longest average first.

**Expected output**: One row per session with `sessionId` and `AvgResponseChars`, longest average first.

**Hint**: Filter to `role = 'assistant'` first, then `AVG(CAST(LEN(content) AS FLOAT))` grouped by `sessionId`.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT
--     sessionId,
--     AVG(CAST(LEN(content) AS FLOAT)) AS AvgResponseChars
-- FROM Conversations.Messages
-- WHERE role = 'assistant'
-- GROUP BY sessionId
-- ORDER BY AvgResponseChars DESC;
```

---

### Step 9: Latency percentiles from metadata (STUDENT EXERCISE)

Every assistant turn written by Lab 4A's `chat_agent(...)` carries an analytics payload under `metadata` that includes `latencyMs`, `promptTokens`, `completionTokens`, `totalTokens`, `ragHits`, and `retrievedDocIds`. The mirror exposes `metadata` to the SQL endpoint as a JSON **string** — you address its fields with `JSON_VALUE(metadata, '$.<field>')`, casting the result to the type you want.

Compute the p50 / p95 / p99 end-to-end latency of assistant responses.

**Expected output**: A single row with `P50`, `P95`, and `P99` columns in milliseconds.

**Hint**: `PERCENTILE_CONT` is a windowed aggregate in T-SQL, so pair it with `OVER ()` and use `SELECT DISTINCT` to collapse to one row. Cast the JSON value with `CAST(JSON_VALUE(metadata, '$.latencyMs') AS INT)`.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT DISTINCT
--     PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY CAST(JSON_VALUE(metadata, '$.latencyMs') AS INT)) OVER () AS P50,
--     PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY CAST(JSON_VALUE(metadata, '$.latencyMs') AS INT)) OVER () AS P95,
--     PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY CAST(JSON_VALUE(metadata, '$.latencyMs') AS INT)) OVER () AS P99
-- FROM Conversations.Messages
-- WHERE role = 'assistant';
```

---

### Step 10: Token spend per session (STUDENT EXERCISE)

Use `metadata.totalTokens` to compute how many tokens each session has consumed. This can help identify expensive sessions as well as total budget per session.

**Expected output**: One row per session showing `sessionId`, `TurnCount`, and `TotalTokens`, ordered from most-expensive to least-expensive.

**Hint**: Filter to assistant turns first (user turns don't carry token metadata), then `SUM(CAST(JSON_VALUE(metadata, '$.totalTokens') AS INT))` grouped by `sessionId`.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT
--     sessionId,
--     COUNT(*) AS TurnCount,
--     SUM(CAST(JSON_VALUE(metadata, '$.totalTokens') AS INT)) AS TotalTokens
-- FROM Conversations.Messages
-- WHERE role = 'assistant'
-- GROUP BY sessionId
-- ORDER BY TotalTokens DESC;
```

---

### Step 11: RAG document attribution (STUDENT EXERCISE)

`metadata.retrievedDocIds` is an array of the corpus document IDs that grounded each assistant answer. Use `OPENJSON(...)` to unroll the array into one row per (turn, doc) pair, then count how often each doc was retrieved.

**Expected output**: One row per corpus doc ID with a `RetrievalCount` column, ordered from most-retrieved to least-retrieved. Docs that never grounded an answer don't appear.

**Hint**: Pull the array sub-document with `JSON_QUERY(metadata, '$.retrievedDocIds')`, then `CROSS APPLY OPENJSON(...) WITH (docId NVARCHAR(100) '$')`. Filter to assistant turns first to avoid scanning user turns with no metadata.

```sql
-- TODO: Replace the commented code with your implementation
-- SELECT
--     d.docId,
--     COUNT(*) AS RetrievalCount
-- FROM Conversations.Messages AS m
-- CROSS APPLY OPENJSON(JSON_QUERY(m.metadata, '$.retrievedDocIds')) WITH (docId NVARCHAR(100) '$') AS d
-- WHERE m.role = 'assistant'
-- GROUP BY d.docId
-- ORDER BY RetrievalCount DESC;
```

---

## Validation

After completing the lab, you should be able to answer:

- **What is the busiest day in your chat history, and which role drives the volume?** Read it from Step 5.
- **Which session has the most turns?** Read it from Step 6.
- **At what hour of day are most assistant responses produced?** Read it from Step 7.
- **What is the average length of assistant responses in your longest session?** Read it from Step 8.
- **What is the p95 latency of your agent's responses?** Read it from Step 9.
- **Which session has spent the most tokens?** Read it from Step 10.
- **Which corpus doc grounds the most answers — and are any docs never retrieved?** Read it from Step 11.
- **Did any of this work consume RUs on the live Cosmos DB account?** Check the Cosmos DB account's **Normalized RU Consumption** metric in the Azure portal — it should be flat for the duration of this lab. All compute happened in Fabric over the OneLake-mirrored copy.

---

### Lab Complete!

You have completed the Fabric Mirror analytics exercise. You:

- Mirrored the operational `Messages` container from Cosmos DB into OneLake with no ETL pipeline.
- Wrote T-SQL aggregations over the mirrored table to summarize volume by day, role, session, and hour-of-day, and to compare response length across sessions.
- Reached into the nested `metadata` JSON with `JSON_VALUE` and `OPENJSON` to compute latency percentiles, token spend per session, and RAG document attribution — the LLMOps surface that lives alongside the chat data with zero extra plumbing.

**Key takeaways**:

- Fabric mirroring gives you a near-real-time analytical copy of operational Cosmos DB data with zero RU impact on the live workload — the agent from Lab 4A keeps serving traffic while you run analytics.
- The mirrored table preserves Cosmos system properties (`_ts`, `_etag`, `_rid`) alongside your document fields, so time-series analytics use `_ts` directly.
- Nested Cosmos documents land in the SQL endpoint as JSON strings; T-SQL's `JSON_VALUE` / `JSON_QUERY` / `OPENJSON` let you query them without a separate flattening pipeline.
- The operational write path (4A) and the analytical read path (4B) are decoupled by the mirror — you can change one without disturbing the other.
