using System.Text.Json;
using Microsoft.Azure.Cosmos;
// CatalogItem and CatalogItemData are in DataModel.cs in the CosmosLabs namespace

namespace CosmosLabs;

public static partial class Steps
{
    public static async Task Step2Async()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 2: Read an Item ===");
        Console.WriteLine("*** STUDENT EXERCISE - Complete this step ***\n");

        var itemId = _itemId!;
        Console.WriteLine($"  reading item with id: {itemId}");

        try
        {
            var readResponse = await _container.ReadItemAsync<CatalogItem>(
                itemId,
                new PartitionKey("workshop"));

            var json = JsonSerializer.Serialize(readResponse.Resource, new JsonSerializerOptions { WriteIndented = true });
            Console.WriteLine($"  item: {json}");
            Console.WriteLine($"  RU charged: {readResponse.RequestCharge}\n");
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
}
