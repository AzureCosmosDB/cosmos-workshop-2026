using System.Text.Json;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
// CatalogItem and CatalogItemData are in DataModel.cs in the CosmosLabs namespace

namespace CosmosLabs;

public static partial class Steps
{
    public static CosmosClient? _client = null;
    public static Database? _database = null;
    public static Container? _container = null;
    public static string? _endpoint = null;
    public static string? _itemId = null;

    public static async Task InitAsync()
    {
        Console.WriteLine("\n=== Step 0: Setup (Connection) ===\n");

        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT");
        if (string.IsNullOrEmpty(cosmosEndpoint))
            throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        _endpoint = cosmosEndpoint;

        var cosmosTenantId = Environment.GetEnvironmentVariable("COSMOS_TENANT_ID");
        var credentialOptions = new DefaultAzureCredentialOptions();
        if (!string.IsNullOrEmpty(cosmosTenantId))
        {
            credentialOptions.TenantId = cosmosTenantId;
        }

        var credential = new DefaultAzureCredential(credentialOptions);
        var accountName = Environment.GetEnvironmentVariable("COSMOS_ACCOUNT_NAME") ?? "unknown";
        var dbName = "WorkshopData";
        var containerName = "Catalog";

        _client = new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
        _database = _client.GetDatabase(dbName);
        _container = _database.GetContainer(containerName);

        Console.WriteLine($"  endpoint: {_endpoint}");
        Console.WriteLine($"  account: {accountName}");
        Console.WriteLine($"  database: {dbName}");
        Console.WriteLine($"  container: {containerName}");
        Console.WriteLine($"  connected: {_endpoint}{dbName}/{containerName}\n");
    }
}
