# Lab 1E: Data Modeling in C#

**Time**: ~60 min
**Environment**: .NET 10 terminal

In this exercise you compare two data models for the same e-commerce domain — a **reference (normalized)** model that mirrors a relational schema, and an **embed (denormalized)** model designed around the queries the app actually runs. You then revisit partition-key choice with the classic hot-partition / composite-key demo on a separate provisioned account.

The lab uses a single project in `1E_Data_Modeling/after/csharp`. Running `dotnet run` walks through each step, pausing for **Enter** between steps.

## Prerequisites

```bash
dotnet --version   # 10.x
```

This lab uses two Cosmos accounts:

| Steps  | Account                                         | Endpoint env var               | Why                                                                                                       |
|--------|-------------------------------------------------|--------------------------------|-----------------------------------------------------------------------------------------------------------|
| 0–4    | Serverless (`bicep/modules/cosmosdb.bicep`)     | `COSMOS_ENDPOINT`              | Two new databases (`ModelingReference`, `ModelingEmbed`) hold the reference vs embed datasets.            |
| 5–7    | Provisioned (`bicep/modules/cosmosdb.provisioned.bicep`) | `COSMOS_ENDPOINT_PROVISIONED`  | Azure Monitor exposes per-partition RU consumption only for provisioned containers — needed for Step 7.   |

The new modeling databases on the serverless account are deployed in advance:

| Database           | Containers                                                                 | Partition key path |
|--------------------|----------------------------------------------------------------------------|--------------------|
| `ModelingReference`| `Customers`, `Addresses`, `Products`, `ProductCategories`, `Orders`, `OrderItems` | `/partitionKey`    |
| `ModelingEmbed`    | `Customers`, `Products`, `Orders` (mixed `OrderDocument` + `ServiceInvoice`)     | `/partitionKey`    |

Every document in both modeling databases writes the same fixed value (`partitionKey = "default"`). The dataset is small enough to live in one logical partition — **partitioning isn't needed for scale and queries stay simple** (no cross-partition fan-out).

## Setup

1. Open a terminal in the `1E_Data_Modeling` directory:

   ```bash
   cd 1E_Data_Modeling
   ```

2. Verify both endpoint environment variables (set by repo-root `SetEnv.ps1`):

   ```powershell
   $env:COSMOS_ENDPOINT              # serverless — used by steps 0-4
   $env:COSMOS_ENDPOINT_PROVISIONED  # provisioned — used by steps 5-7
   ```

3. Run the lab:

   ```bash
   dotnet run
   ```

## Step 0: Seed the reference and embed databases

The seed data lives in `seed-reference.json` and `seed-embed.json` in this directory, each grouped into sections by container. The C# project copies them to its output folder; the Python notebook reads its own copy from `1E_Data_Modeling/after/python/`.

The seeded data describes three customers, five products in three categories, three orders and two service invoices. Identical logical data is shaped two ways: as relational rows in the reference DB, and as denormalized documents in the embed DB.

## Step 1: Fetch a complete order — reference model


To assemble one complete order in the reference model you walk references across six containers — `Orders → OrderItems → Products → ProductCategories`, plus `Customers` and `Addresses`.

In an equivalent relational database, you might use JOINs in a SQL query to achieve the same result with a normalized schema:

```sql
SELECT *
FROM Orders o
JOIN OrderItems oi ON o.Id = oi.OrderId
JOIN Customers c ON o.CustomerId = c.Id
JOIN Addresses a ON o.AddressId = a.Id
JOIN Products p ON oi.ProductId = p.Id
JOIN ProductCategories pc ON p.CategoryId = pc.Id
WHERE o.Id = 'order_001';
```

In Cosmos DB queries involve a single container, so every hop is its own round-trip and its own RU charge. This step prints each hop and tallies total RU and round-trip count.

**Expected behavior**: 7+ round-trips, RU charge sums across all of them.

## Step 2: Fetch a complete order — embed model

In the embed model the customer name/address snapshot and all line items already live inside the order document, so a single point read returns everything.

**Expected behavior**: 1 round-trip, ~1-3 RU. Compare directly to Step 1's totals.

**Tradeoff**: writes get bigger and customer data is duplicated across orders — Step 3 explores what that costs.

## Step 3: Update a customer address — model tradeoffs

Alice (cust_001) moves from `100 Main St, Seattle WA` to `555 New Lane, Bellevue WA`. The step performs the update in both models:

- **Reference model**: replace one `Addresses` document. Every order that joins on `addressId` resolves the new address on its next read. One write.
- **Embed model**: replace the `Customers` document — but past `OrderDocument`s still carry the **snapshotted old address** in `customerStreet / customerCity / ...`. Two valid answers:
  1. **Historical accuracy**: leave past orders as-is so each order reflects where it was actually shipped.
  2. **Propagate the change**: query affected orders and `ReplaceItem` each one. The step demonstrates this fan-out and reports the extra RU.

**The plumbing for option 2 in real systems is the Cosmos change feed**: subscribe to writes on `Customers`, look up affected orders, replace them. The lab does the same work inline with a query + replace so the cost is observable.

## Step 4: Designing by usage patterns

The embed schema was driven by the queries the app needs to be fast. The step runs the canonical example — **orders by customer name** — and reports its RU cost. Because every order doc carries a snapshot of `customerName`, this is a single-container query: no second round-trip to look up the customer, no cross-container join.

```sql
SELECT * FROM c WHERE c.docType = 'order' AND c.customerName = @name
```

Other patterns this model is shaped for (try them in Data Explorer or extend Step 4):

| Pattern                       | How it's served                                                                                       |
|------------------------------|-------------------------------------------------------------------------------------------------------|
| **Customer by id**           | Point read on `Customers/{id}`. Cheapest possible — typically ~1 RU.                                  |
| **Customer by name**         | `SELECT * FROM c WHERE c.name = @name` on `Customers`. Single PK so no fan-out.                       |
| **Order by id**              | Point read on `Orders/{id}`. The full order — customer snapshot + line items — comes back in one hop. |
| **Orders by customer name**  | The example the step runs. Snapshotted `customerName` keeps it single-container.                      |
| **Product list**             | `SELECT * FROM c` on `Products`. Tiny catalog, single PK, no `WHERE` clause needed.                   |
| **Revenue by date / month**  | `Orders` holds both `OrderDocument` and `ServiceInvoice` (discriminated by `docType`). A single `GROUP BY` on `c.date` rolls up product sales *and* service revenue — no `UNION`, no second container. |

**Takeaway**: design the model around the hot read paths. Embedding the customer snapshot keeps the orders-by-customer-name path cheap; co-locating invoices with orders keeps revenue rollups single-container. Both patterns trade write complexity for read simplicity.

## Step 5: Hot-partition seed (provisioned account)

The remaining three steps revisit partition-key choice on the **provisioned** account so you can view throughput metrics and scale settings in the Azure Portal. `OrdersHot` is keyed on `/orderDate` — a real-world anti-pattern where a system partitions by date and then every write "right now" lands on the same logical partition. Seed 100 orders, all with today's date, then run `SELECT DISTINCT VALUE c.orderDate FROM c` and observe **one** distinct partition-key value across the whole container.

## Step 6: Composite key — inspect and re-seed

Read `OrdersComposite` and confirm it's keyed on `/partitionKey`. The lab uses a **synthetic composite key**: each document writes `customerId#orderDate` into `/partitionKey`. Seed the same 100 orders on today's date and run `SELECT DISTINCT VALUE c.partitionKey FROM c` — this time the container holds **~50** distinct partition-key values (one per customer for today).

## Step 7: Distribution summary

The step prints the contrast directly: `OrdersHot` ended up with 1 partition-key value, `OrdersComposite` with ~50. At a small scale like 100 docs Cosmos won't have split into multiple physical partitions, so the portal heat map won't show a dramatic split — but the **logical** partition distribution is shown in the results of the distinct-value query measures.

If you want to see what this looks like at production scale, open **Azure Portal > Cosmos DB > Monitoring > Insights > Throughput > Normalized RU Consumption (Max) Heat Map By PartitionKeyRangeId**. Above ~10k RU/s with multiple physical partitions, the hot container spikes one PartitionKeyRangeId while the composite stays flat.



You compared a normalized vs denormalized model on the same domain, observed the read-cost difference (Step 2 vs Step 1) and the write-cost difference (Step 3), demonstrated the query patterns the embed model was actually designed around (Step 4), and finished with the classic hot-partition vs composite-key visualization (Steps 5–7).

**Key takeaways**:
- Reads in a normalized model fan out across many containers; embedding collapses that to one point read.
- Denormalization moves cost from reads to writes — updates to shared data need to fan out, typically via change feed.
- Design the model around the hot query paths the app actually runs.
- Small datasets don't need partitioning — a single fixed `partitionKey` value keeps queries simple and lets you point-read by `id`.
- For high-volume workloads, a composite partition key (e.g. `customerId#orderDate`) spreads load and avoids hot partitions.
