using System.Text.Json;
using Microsoft.Azure.Cosmos;
// CatalogItem and CatalogItemData are in DataModel.cs in the CosmosLabs namespace
namespace CosmosLabs;

public static partial class Steps
{
    public static async Task Step1Async()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Create an Item ===\n");

        var itemId = Guid.NewGuid().ToString();
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
            var response = await _container.CreateItemAsync<CatalogItem>(
                item,
                new PartitionKey("workshop"));

            var requestCharge = response.RequestCharge;
            Console.WriteLine($"  created item: {response.Resource.Id}");
            Console.WriteLine($"  RU charged: {requestCharge}\n");

            _itemId = itemId;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
        {
            Console.WriteLine($"  item {itemId} already exists in container\n");
            _itemId = itemId;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error creating item: {ex.Message}\n");
        }
    }
}
