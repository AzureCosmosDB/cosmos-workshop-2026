# Lab 1E: Data Modeling / Partition Keys in C#

**Time**: ~60 min  
**Environment**: .NET 10 terminal

In this exercise you will explore partition key strategies, composite partition keys, denormalized fan-out patterns, and TTL policies in Azure Cosmos DB.

The lab uses a single project in the `1E_Data_Modeling` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed:

```bash
dotnet --version
```

This lab targets the **provisioned-throughput** Cosmos account (deployed by `CosmosLabs2026/bicep/modules/cosmosdb.provisioned.bicep`), not the serverless one the other labs use. Provisioned throughput is what makes the Step 6 portal-metrics observation possible — Azure Monitor reports normalized RU consumption per partition for provisioned containers.

The `OrdersHot`, `OrdersComposite`, and `EventsTtl` containers in the `Modeling` database are deployed in advance. (The DB is named `Modeling` rather than reusing the serverless account's `WorkshopData` so it's obvious which endpoint you're talking to.) Cosmos DB AAD tokens only authorize data-plane operations, so the lab seeds and inspects existing containers rather than creating them.

The containers are deployed with **two different throughput configurations** so you see both patterns side by side:

| Container          | Partition key path | Throughput                                           | Notes                                                                     |
|--------------------|--------------------|------------------------------------------------------|---------------------------------------------------------------------------|
| `OrdersHot`        | `/customerId`      | **Container-level autoscale** (dedicated)            | All seeded orders use the same customer to demonstrate hot-partitioning. |
| `OrdersComposite`  | `/partitionKey`    | **Container-level autoscale** (dedicated, same RU)   | Synthetic composite value (`customerId#orderDate`) into `/partitionKey`.  |
| `EventsTtl`        | `/partitionKey`    | **Database-level autoscale** (shared with the DB)    | `defaultTtl = 2,592,000` seconds (30 days).                               |

`OrdersHot` and `OrdersComposite` get the same dedicated max RU so the Step 6 RU-distribution comparison reflects partition-key strategy only. `EventsTtl` shares the database pool to illustrate the alternative provisioning model.

## Setup

1. Open a terminal in the `1E_Data_Modeling` directory:

   ```bash
   cd 1E_Data_Modeling
   ```

2. Ensure `COSMOS_ENDPOINT_PROVISIONED` is set to the provisioned account's endpoint (the repo-root `SetEnv.ps1` initializes this alongside the serverless `COSMOS_ENDPOINT` other labs use):

   ```powershell
   $env:COSMOS_ENDPOINT_PROVISIONED
   # https://cosmos-provisioned-...documents.azure.com:443/
   ```

## Partition Key Strategies

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connection

Set up the Cosmos client connection to the `WorkshopData` database.

### Step 1: Seed Data with Hot Partition (Prebuilt)

Seed 10,000 orders (~1 KB each, written with 64 concurrent writers) into `OrdersHot` — all with the same `customerId` (`CUST_001`). The volume and concurrency are deliberately high so the single logical partition shows up clearly on **Normalized RU Consumption (Max)** in Azure Monitor; a smaller seed barely registers.

### Step 2: Inspect Composite-Key Container (STUDENT EXERCISE)

Read `OrdersComposite` properties and confirm it's keyed on `/partitionKey`. The lab uses a **synthetic composite key**: each document writes `customerId#orderDate` into `/partitionKey` to spread load across partitions.

**Expected output**: `Composite container verified (synthetic '/partitionKey').`

**Hint**: Use `GetContainer(...).ReadContainerAsync()` and inspect `PartitionKeyPaths`.

### Step 3: Re-seed with Composite Partition Key (STUDENT EXERCISE)

For each order, set `partitionKey = customerId + "#" + orderDate` and upsert into `OrdersComposite`. The lab re-seeds the same 10,000-order volume as Step 1 but spreads it across 50 customers × 28 dates, so Azure Monitor's per-partition chart will be visibly flat.

**Expected output**: All 10,000 orders re-seeded; writes are distributed across many logical partitions.

**Hint**: Pass the composite string to `new PartitionKey(value)` when calling `UpsertItemAsync`.

### Step 4: Query for Denormalized Fan-Out Pattern (STUDENT EXERCISE)

Query a few orders from `OrdersHot` and observe that each order's line `items` array comes back **inside the same document** — no second query, no cross-container join. That's the fan-out / denormalization payoff.

**Expected output**: Three orders printed, each with its embedded `items` array, plus the total RU charged for the single query.

**Hint**: Use `GetItemQueryIterator<JsonElement>` (not `dynamic` — `System.Text.Json` won't pretty-print `dynamic`) and pass `new QueryRequestOptions { PartitionKey = new PartitionKey("CUST_001") }` so the query stays single-partition.

### Step 5: Per-Item TTL Override (STUDENT EXERCISE)

Read the container's `DefaultTimeToLive` (30 days) and then watch the **per-item `ttl` property** override it. The step writes three documents:

| Item id          | `ttl` property | Behavior                                                |
|------------------|----------------|---------------------------------------------------------|
| `short-lived`    | `5`            | Expires 5 seconds after `_ts` — overrides the default.  |
| `never-expires`  | `-1`           | Never expires — overrides the default.                   |
| `default-ttl`    | (omitted)      | Inherits the container's 30-day default.                |

The step then waits ~15 seconds and reads all three back. The short-lived item should return **404 NotFound** while the other two still resolve.

**Expected output**:
```
short-lived   (ttl=5)         exists? False
never-expires (ttl=-1)        exists? True
default-ttl   (no override)   exists? True
```

**Hint**: The Cosmos TTL sweeper runs asynchronously and is best-effort, not instant — if `short-lived` still resolves on the first read-back, retry after a few more seconds. Catch `CosmosException` with `StatusCode == HttpStatusCode.NotFound` to detect expiration.

### Step 6: Compare RU Distribution

The hot partition container concentrates all write RU on a single partition. The composite partition container distributes writes across multiple partitions.

Check **Azure Portal** > Cosmos DB > Monitor > Metrics > Request Units > Partition-Key to see:
- **Hot partition container**: RU spike on `CUST_001`
- **Composite container**: flat distribution across partitions

## Lab Complete!

You have completed the Data Modeling exercise. You:
- Seeded a container with a single partition key value (hot partition scenario)
- Inspected a container keyed on a synthetic composite partition key
- Re-seeded data using composite partition key values
- Queried denormalized fan-out data using `SELECT VALUE`
- Watched per-item `ttl` overrides shorten, extend, and disable expiration relative to the container default

**Key takeaways**:
- Composite partition keys distribute load across partitions
- Denormalization (fan-out) reduces cross-partition queries
- TTL policies automate data lifecycle management

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
