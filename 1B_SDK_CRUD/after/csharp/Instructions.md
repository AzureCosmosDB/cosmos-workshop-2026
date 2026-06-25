# Lab 1B: SDK Basics / CRUD in C#

**Time**: ~15 min  
**Environment**: Terminal with `.NET 10 SDK`

In this exercise you will perform Create, Read, Update, and Delete operations on Azure Cosmos DB using the C# `Microsoft.Azure.Cosmos` SDK v3 with `DefaultAzureCredential` authentication.

The lab uses the `1B_SDK_CRUD` directory. A console program walks through each step in sequence, pausing for **Enter** between steps so you can read the output before moving on. Each step builds on the previous one — you cannot run them out of order.

## Prerequisites

- .NET 10 SDK
- `COSMOS_ENDPOINT` environment variable set to your Cosmos DB account endpoint

## Setup

1. Open a terminal in the `1B_SDK_CRUD` directory:

   ```bash
   cd 1B_SDK_CRUD
   ```

2. Run the program:

   ```bash
   dotnet run
   ```

   The program runs each step in sequence and pauses between steps — press **Enter** at each prompt to continue. The `CatalogItem` payload is already built for you; your job in each step is to write the single Cosmos SDK call that operates on it.

## Student Exercises

Open `Steps_SDK_CRUD.cs`. Each step has a `// STUDENT EXERCISE` comment inside a `try` block followed by a placeholder line. Replace the placeholder line with the SDK call for that step — the surrounding `Console.WriteLine` calls already know how to print the result.

### Step 1 — Create the item with `CreateItemAsync`

```csharp
var response = await _container.CreateItemAsync<CatalogItem>(
    item,
    new PartitionKey("workshop"));
```

**Expected output**: `created item: <guid>`. An "item already exists" message means a previous run left an item behind — finish the lab so Step 4 cleans it up, then re-run.

### Step 2 — Read the item with `ReadItemAsync`

```csharp
var readResponse = await _container.ReadItemAsync<CatalogItem>(
    _itemId!,
    new PartitionKey("workshop"));
```

`ReadItemAsync` takes the **id** and **partition key** — not the item itself.

**Expected output**: the item JSON with all properties.

### Step 3 — Update the item with `UpsertItemAsync`

```csharp
var upsertResponse = await _container.UpsertItemAsync<CatalogItem>(
    item,
    new PartitionKey("workshop"));
```

`UpsertItemAsync` takes the **full item** (like `CreateItemAsync`), not just the id. Items can be newly constructed or results of `ReadItemAsync<>` requests.

**Expected output**: `new price: 55.0`.

### Step 4 — Delete the item with `DeleteItemAsync`

```csharp
var deleteResponse = await _container.DeleteItemAsync<CatalogItem>(
    _itemId!,
    new PartitionKey("workshop"));
```

Like `ReadItemAsync`, `DeleteItemAsync` takes the **id** and **partition key**.

**Expected output**: `status: NoContent` (HTTP 204), followed by the lab completion message.

## Lab Complete!

To run the lab again from scratch, run `dotnet run`. The program walks through every step in sequence.
