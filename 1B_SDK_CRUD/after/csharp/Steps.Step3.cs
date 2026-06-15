using System.Text.Json;
using Microsoft.Azure.Cosmos;
// CatalogItem and CatalogItemData are in DataModel.cs in the CosmosLabs namespace

namespace CosmosLabs;

public static partial class Steps
{
    public static async Task Step3Async()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 3: Upsert the Item ===\n");

        var itemId = _itemId!;
        Console.WriteLine("  updating price: 42.0 -> 55.0");

        var item = new CatalogItem
        {
            Id = itemId,
            Name = "Cosmic Item #1",
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
            var upsertResponse = await _container.UpsertItemAsync<CatalogItem>(
                item,
                new PartitionKey("workshop"));

            Console.WriteLine($"  upserted item: {upsertResponse.Resource.Id}");
            Console.WriteLine($"  new price: {upsertResponse.Resource.Data.Price}");
            Console.WriteLine($"  RU charged: {upsertResponse.RequestCharge}\n");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  error upserting item: {ex.Message}\n");
        }
    }
}
