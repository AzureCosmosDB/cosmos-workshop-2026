# Lab 1B: SDK Basics / CRUD in C#

**Time**: ~10 min  
**Environment**: Terminal with `.`NET 10 SDK

In this exercise you will perform Create, Read, Update, and Delete operations on Azure Cosmos DB using the C# `Azure.Cosmos` SDK v3 with `DefaultAzureCredential` authentication.

The lab uses the `1B_SDK_CRUD` directory. A console program walks through each step in sequence, pausing for **Enter** between steps so you can read the output before moving on. Each step builds on the previous one — you cannot run them out of order.

## Prerequisites

- .NET 10 SDK
- `COSMOS_ENDPOINT` environment variable set to your Cosmos DB account endpoint
- `COSMOS_ACCOUNT_NAME` environment variable set to your Cosmos DB account name
- (Optional) `COSMOS_TENANT_ID` environment variable for tenant-specific Azure Identity

## Setup

1. Open a terminal in the `1B_SDK_CRUD` directory:

   ```bash
   cd 1B_SDK_CRUD
   ```

2. Build the project:

   ```bash
   dotnet build
   ```

3. Run the program:

   ```bash
   dotnet run
   ```

## Running the Lab

The program runs each step in sequence and pauses between steps — press **Enter** at each prompt to continue to the next step. Each step builds on the previous one, so you must implement them in order.

- **Step 0** - Initialize connection to Cosmos DB
- **Step 1** - Create an item
- **Step 2** - Read an item (**student exercise - complete this step**)
- **Step 3** - Update the item (upsert)
- **Step 4** - Delete the item

## Expected Behavior

- **Step 0**: Connects using `DefaultAzureCredential` and prints the endpoint, database, and container info.
- **Step 1**: Creates a new item in the `Catalog` container.

**Expected output**: The item ID and the RU charge (typically 2-3 RU for a small item).

If you see a "item already exists" message, run the Delete step first to clean up.
- **Step 2**: Read the item back from the `Catalog` container. Verify the output shows the item JSON with all properties and the RU charge (typically 1 RU for a small point read).
- **Step 3**: Updates the item's price from 42.0 to 55.0 via upsert. Note the increased RU charge required to update an existing item.
- **Step 4**: Deletes the item and prints the response status (should be 204/Ok).

## Lab Complete!

You have completed the CRUD exercise in C#. You:
- Connected to Cosmos DB using `DefaultAzureCredential`
- Created an item in the `Catalog` container
- Read the item back from Cosmos DB
- Updated the item with upsert
- Deleted the item
- Inspected RU charges from each operation response

To run the lab again from scratch, run `dotnet run` again. The program will walk through every step in sequence.
