// Lab 1B: SDK Basics / CRUD - Consolidated Steps (STUDENT VERSION)

using System.Text.Json;
using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace Lab1B;

public class Steps_SDK_CRUD
{
    public CosmosClient? _client = null;
    public Database? _database = null;
    public Container? _container = null;
    public string? _endpoint = null;
    public string? _itemId = null;

    #region Init
    public async Task Init()
    {
        Console.WriteLine("\n=== Step 0: Setup (Connection) ===\n");

        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT");
        if (string.IsNullOrEmpty(cosmosEndpoint))
            throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        _endpoint = cosmosEndpoint;

        var credential = new DefaultAzureCredential();
        var dbName = "WorkshopData";
        var containerName = "Catalog";

        _client = new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
        _database = _client.GetDatabase(dbName);
        _container = _database.GetContainer(containerName);

        Console.WriteLine($"  endpoint: {_endpoint}");
        Console.WriteLine($"  database: {dbName}");
        Console.WriteLine($"  container: {containerName}");
        Console.WriteLine($"  connected: {_endpoint}{dbName}/{containerName}\n");
    }
    #endregion

    #region Step 1
    public async Task Step1()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Create an Item ===");
        Console.WriteLine("*** STUDENT EXERCISE - Complete this step ***\n");

        var itemId = Guid.NewGuid().ToString();
        _itemId = itemId;
        Console.WriteLine($"  creating item with id: {itemId}");

        var item = new CatalogItem
        {
            Id = itemId,
            Name = "Store Item #1",
            Category = "workshop",
            PartitionKey = "workshop",
            Data = new CatalogItemData
            {
                Price = 42.0m,
                Tags = new[] { "cosmos", "demo" }
            }
        };

        try
        {
            // STUDENT EXERCISE: replace the placeholder below with a CreateItemAsync<CatalogItem> call.
            // See Instructions.md Step 1.
            var response = new { Resource = new { Id = "(placeholder)" } };

            Console.WriteLine($"  created item: {response.Resource.Id}\n");
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
        {
            Console.WriteLine($"  item {itemId} already exists in container\n");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error creating item: {ex.Message}\n");
        }
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 2: Read an Item ===");
        Console.WriteLine("*** STUDENT EXERCISE - Complete this step ***\n");

        var itemId = _itemId!;
        Console.WriteLine($"  reading item with id: {itemId}");

        try
        {
            // STUDENT EXERCISE: replace the placeholder below with a ReadItemAsync<CatalogItem> call.
            // See Instructions.md Step 2.
            var readResponse = new { Resource = new { Name = "(placeholder)" } };

            var json = JsonSerializer.Serialize(readResponse.Resource, new JsonSerializerOptions { WriteIndented = true });
            Console.WriteLine($"  item: {json}\n");
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            Console.WriteLine($"  item {itemId} not found\n");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error reading item: {ex.Message}\n");
        }
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 3: Upsert the Item ===");
        Console.WriteLine("*** STUDENT EXERCISE - Complete this step ***\n");

        var itemId = _itemId!;
        Console.WriteLine("  updating price: 42.0 -> 55.0");

        var item = new CatalogItem
        {
            Id = itemId,
            Name = "Store Item #1",
            Category = "workshop",
            PartitionKey = "workshop",
            Data = new CatalogItemData
            {
                Price = 55.0m,
                Tags = new[] { "cosmos", "demo" }
            }
        };

        try
        {
            // STUDENT EXERCISE: replace the placeholder below with an UpsertItemAsync<CatalogItem> call.
            // See Instructions.md Step 3.
            var upsertResponse = new { Resource = new { Id = "(placeholder)", Data = new { Price = 0m } } };

            Console.WriteLine($"  upserted item: {upsertResponse.Resource.Id}");
            Console.WriteLine($"  new price: {upsertResponse.Resource.Data.Price}\n");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error upserting item: {ex.Message}\n");
        }
    }
    #endregion

    #region Step 4
    public async Task Step4()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 4: Delete the Item ===");
        Console.WriteLine("*** STUDENT EXERCISE - Complete this step ***\n");

        var itemId = _itemId!;
        Console.WriteLine($"  deleting item: {itemId}\n");

        try
        {
            // STUDENT EXERCISE: replace the placeholder below with a DeleteItemAsync<CatalogItem> call.
            // See Instructions.md Step 4.
            var deleteResponse = new { StatusCode = System.Net.HttpStatusCode.BadRequest };

            Console.WriteLine($"  deleted item: {itemId}");
            Console.WriteLine($"  status: {deleteResponse.StatusCode}\n");

            Console.WriteLine("=== Lab Complete ===");
            Console.WriteLine("You have completed the CRUD operations exercise in C#. You:");
            Console.WriteLine("- Connected to Cosmos DB using DefaultAzureCredential");
            Console.WriteLine("- Created an item with CreateItemAsync()");
            Console.WriteLine("- Read an item with ReadItemAsync()");
            Console.WriteLine("- Updated an item with UpsertItemAsync()");
            Console.WriteLine("- Deleted an item with DeleteItemAsync()");
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            Console.WriteLine($"  item {itemId} not found (may have been deleted)\n");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error deleting item: {ex.Message}\n");
        }
    }
    #endregion
}
