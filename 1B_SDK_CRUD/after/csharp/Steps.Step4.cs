using Microsoft.Azure.Cosmos;
// CatalogItem and CatalogItemData are in DataModel.cs in the CosmosLabs namespace

namespace CosmosLabs;

public static partial class Steps
{
    public static async Task Step4Async()
    {
        if (_container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (string.IsNullOrEmpty(_itemId)) throw new InvalidOperationException("Item not created yet. Run Step 1 first.");

        Console.WriteLine("\n=== Step 4: Delete the Item ===\n");

        var itemId = _itemId!;
        Console.WriteLine($"  deleting item: {itemId}\n");

        try
        {
            var deleteResponse = await _container.DeleteItemAsync<CatalogItem>(
                itemId,
                new PartitionKey("workshop"));

            Console.WriteLine($"  deleted item: {itemId}");
            Console.WriteLine($"  status: {deleteResponse.StatusCode}");
            Console.WriteLine($"  RU charged: {deleteResponse.RequestCharge}\n");

            Console.WriteLine("=== Lab Complete ===");
            Console.WriteLine("You have completed the CRUD operations exercise in C#. You:");
            Console.WriteLine("- Connected to Cosmos DB using DefaultAzureCredential");
            Console.WriteLine("- Created an item with CreateItemAsync()");
            Console.WriteLine("- Read an item with ReadItemAsync()");
            Console.WriteLine("- Updated an item with UpsertItemAsync()");
            Console.WriteLine("- Deleted an item with DeleteItemAsync()");
            Console.WriteLine("- Inspected RU charges from each operation response");
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
}
