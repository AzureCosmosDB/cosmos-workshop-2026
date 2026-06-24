# Lab 1D1: Query Language in C#

**Time**: ~15 min  
**Environment**: .NET 10 terminal

In this exercise you will run SQL-style queries against Azure Cosmos DB using the C# `Microsoft.Azure.Cosmos` SDK.

The lab uses a single project in the `1D1_Query_Language` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- `COSMOS_ENDPOINT` environment variable set to your Cosmos DB account endpoint

## Setup

1. Open a terminal in the `1D1_Query_Language` directory:

   ```bash
   cd 1D1_Query_Language
   ```

2. Run the project. It executes each step in order, pausing for **Enter** between steps:

   ```bash
   dotnet run
   ```

### Step 0: Initialize Connection

Set up the Cosmos client connection to the `WorkshopData/Catalog` container.

### Step 1: Seed Data (Prebuilt)

Seeds 5 fruit/vegetable items into the container with grocery partition key. Each item has a `tags` array and a nested `nutrition` object (`calories`, `vitamins[]`) so later steps can demonstrate JSON and subquery features.

### Step 2: Query for All Fruits (STUDENT EXERCISE)

Replace the placeholder `QueryDefinition` in `Steps_Query_Language.cs` Step 2 with a parameterized query that returns items where `c.category` matches `categoryToQuery`:

```csharp
var query = new QueryDefinition("SELECT * FROM c WHERE c.category = @cat")
    .WithParameter("@cat", categoryToQuery);
```

**Expected output**: Apples, Bananas, and Dates are listed with prices.

### Step 3: Point Read vs Query Cost

Fetches the same single item (`id = "1"`) two ways — a point read and a `SELECT * FROM c WHERE c.id = '1'` query — and compares their RU charges. Same logical result, two access patterns, so the RU difference is a fair head-to-head.

### Step 4: Parameterized Query (STUDENT EXERCISE)

Replace the placeholder `QueryDefinition` in `Steps_Query_Language.cs` Step 4 with a parameterized `SELECT TOP @limit` query ordered by price descending:

```csharp
var topQuery = new QueryDefinition("SELECT TOP @limit c.name, c.price FROM c ORDER BY c.price DESC")
    .WithParameter("@limit", limit);
```

**Expected output**: 3 items listed by price (highest first).

### Step 5: JSON Properties + System Functions (STUDENT EXERCISE)

Replace the placeholder `QueryDefinition` in `Steps_Query_Language.cs` Step 5 with a query that uses Cosmos DB's native JSON support and two built-in [system functions](https://learn.microsoft.com/azure/cosmos-db/nosql/query/system-functions) — filters on a nested property (`c.nutrition.calories`) and an array tag (`ARRAY_CONTAINS(c.tags, 'organic')`), and projects `CONCAT(c.category, ' category')`:

```csharp
var query = new QueryDefinition(
    "SELECT c.name, CONCAT(c.category, ' category') AS category, c.nutrition.calories " +
    "FROM c " +
    "WHERE ARRAY_CONTAINS(c.tags, 'organic') AND c.nutrition.calories < 100");
```

**Expected output**: Apples, Broccoli, and Carrots — the organic items under 100 calories.

### Step 6: Subquery Over a Nested Array (STUDENT EXERCISE)

Replace the placeholder `QueryDefinition` in `Steps_Query_Language.cs` Step 6 with a [subquery](https://learn.microsoft.com/azure/cosmos-db/nosql/query/subquery) that iterates the nested `nutrition.vitamins` array per item and projects a `COUNT(1)`:

```csharp
var query = new QueryDefinition(
    "SELECT c.name, " +
    "       (SELECT VALUE COUNT(1) FROM v IN c.nutrition.vitamins) AS vitaminCount " +
    "FROM c " +
    "ORDER BY c.name");
```

**Expected output**: each item listed with its count of vitamins from `nutrition.vitamins`.

## Lab Complete!

You have completed the query language exercise in C#. You:
- Connected to Cosmos DB using `DefaultAzureCredential`
- Seeded sample data with nested objects and arrays
- Ran a filter query using `QueryDefinition`
- Compared point read vs query cost
- Wrote a parameterized query with `TOP`
- Queried nested JSON properties with `ARRAY_CONTAINS` and `CONCAT`
- Wrote a subquery that aggregates a nested array

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
