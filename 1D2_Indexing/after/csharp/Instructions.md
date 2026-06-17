# Lab 1D2: Indexing Policy in C#

**Time**: ~15 min  
**Environment**: .NET 10 terminal

In this exercise you will explore Cosmos DB indexing policies and see how custom indexing can reduce RU costs.

The lab uses a single project in the `1D2_Indexing` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed:

```bash
dotnet --version
```

The `ItemsDefaultIndex` and `ItemsCustomIndex` containers in the `WorkshopData` database are deployed in advance by the workshop Bicep template (`CosmosLabs2026/bicep/modules/cosmosdb.bicep`). Cosmos DB AAD tokens only authorize data-plane operations, so the lab inspects existing containers rather than creating them.

`ItemsCustomIndex` is deployed with this policy:

```json
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [{ "path": "/*" }],
  "excludedPaths": [
    { "path": "/largeBlob/?" },
    { "path": "/metadata/*" }
  ]
}
```

The two forms illustrate two patterns: `?` excludes the scalar value at a path (used here for a single ~100 KB string in `largeBlob`), while `*` excludes everything under a path (used here for the nested `metadata` object with ~50 fields). Step 3 writes a document combining both — the default container indexes all of it, the custom container skips both, producing the measurable RU difference.

## Indexing Operations

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connection

Set up the Cosmos client connection to the `WorkshopData` database.

### Step 1: Inspect Default Indexing Container (Prebuilt)

Reads `ItemsDefaultIndex` and prints its indexing mode and paths. With default indexing every path is indexed and `ExcludedPaths` is empty.

### Step 2: Inspect Custom Indexing Container (STUDENT EXERCISE)

Read `ItemsCustomIndex` and verify that `/largeBlob/*` and `/metadata/*` appear in `ExcludedPaths`.

**Student task**: Use `GetContainer(...).ReadContainerAsync()` to fetch the `IndexingPolicy` and check the excluded paths.

**Expected output**: Both `/largeBlob/*` and `/metadata/*` listed; "Custom indexing policy verified."

### Step 3: RU Comparison — `largeBlob` only (`?` exclusion)

Writes a document containing only a ~100 KB scalar string at `/largeBlob` to both containers. The custom container's `/largeBlob/?` exclusion skips indexing that single value. Shows the impact of excluding one large scalar.

### Step 4: RU Comparison — `metadata` only (`*` exclusion)

Writes a document with a nested `metadata` object (~50 string fields) to both containers. The custom container's `/metadata/*` exclusion skips the entire subtree. Shows the impact of excluding many sub-paths at once.

### Step 5: RU Comparison — combined

Writes a document with **both** `largeBlob` and `metadata`. The savings from Steps 3 and 4 stack: the default container pays for the big string and every nested field; the custom container pays for neither.

## Lab Complete!

You have completed the indexing policy exercise in C#. You:
- Inspected a container with default indexing
- Inspected a container with custom indexing (excluded paths)
- Compared RU costs between default and custom indexing
- Learned how indexing policies affect cost

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
