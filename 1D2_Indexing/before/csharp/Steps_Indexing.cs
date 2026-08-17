// Lab 1D2: Indexing Policy - Consolidated Steps (STUDENT VERSION)

#nullable enable
using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace Lab1D2;

public class Steps_Indexing
{
    #region State
    public string? Endpoint { get; private set; }
    public string DbName { get; private set; } = "WorkshopData";
    public CosmosClient? Client { get; private set; }
    public Database? DB { get; private set; }
    private const string DefaultContainerName = "ItemsDefaultIndex";
    private const string CustomContainerName = "ItemsCustomIndex";
    public bool DefaultContainerCreated { get; private set; }
    public bool CustomContainerCreated { get; private set; }

    private CosmosClient CreateClient(string endpoint)
    {
        var credential = new AzureCliCredential();

        return new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
    }
    #endregion

    #region Init
    public async Task Step0()
    {
        Console.WriteLine("\n=== Step 0: Init (Connection) ===\n");

        var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        Client = CreateClient(endpoint);
        DB = Client.GetDatabase(DbName);
        Endpoint = endpoint;

        Console.WriteLine($"Connected to: {endpoint}{DbName}");
    }
    #endregion

    #region Step 1
    public async Task Step1()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Inspect Default Indexing Container (Prebuilt) ===\n");

        var container = DB.GetContainer(DefaultContainerName);
        var props = await container.ReadContainerAsync();

        Console.WriteLine($"  Container '{DefaultContainerName}' found");
        Console.WriteLine($"    Indexing mode: {props.Resource.IndexingPolicy.IndexingMode}");
        Console.WriteLine($"    Included paths: {string.Join(", ", props.Resource.IndexingPolicy.IncludedPaths.Select(p => p.Path))}");
        Console.WriteLine($"    Excluded paths: {string.Join(", ", props.Resource.IndexingPolicy.ExcludedPaths.Select(p => p.Path))}");
        DefaultContainerCreated = true;
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 2: Inspect Custom Indexing Container (STUDENT EXERCISE) ===\n");

        var container = DB.GetContainer(CustomContainerName);

        // STUDENT EXERCISE: replace the placeholder below with a real ReadContainerAsync call
        // and pull the excluded paths off the IndexingPolicy. See Instructions.md Step 2.
        var excluded = new List<string> { "(placeholder)" };
        Console.WriteLine($"  Container '{CustomContainerName}' found");
        Console.WriteLine($"    Excluded paths: {string.Join(", ", excluded)}");

        bool blobExcluded = excluded.Any(p => p.StartsWith("/largeBlob/"));
        bool metaExcluded = excluded.Any(p => p.StartsWith("/metadata/"));
        bool ok = blobExcluded && metaExcluded;
        Console.WriteLine(ok
            ? "  Custom indexing policy verified (/largeBlob and /metadata excluded)."
            : "  WARNING: expected /largeBlob and /metadata exclusions not both present.");
        CustomContainerCreated = ok;
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 3: Compare RU Costs - largeBlob only ('?' exclusion) ===\n");

        string largeBlob = string.Join("", Enumerable.Range(0, 10000).Select(_ => (char)('a' + Random.Shared.Next(26))));

        var itemDefault = new { id = $"blob_test_{Guid.NewGuid():N}", partitionKey = "idx", largeBlob };
        var itemCustom = new { id = $"blob_test_{Guid.NewGuid():N}", partitionKey = "idx", largeBlob };

        await CompareRu(itemDefault, itemCustom);
    }
    #endregion

    #region Step 4
    public async Task Step4()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 4: Compare RU Costs - metadata only ('*' exclusion) ===\n");

        var metadata = Enumerable.Range(0, 50).ToDictionary(i => $"tag{i}", i => $"value_{i}");

        var itemDefault = new { id = $"meta_test_{Guid.NewGuid():N}", partitionKey = "idx", metadata };
        var itemCustom = new { id = $"meta_test_{Guid.NewGuid():N}", partitionKey = "idx", metadata };

        await CompareRu(itemDefault, itemCustom);
    }
    #endregion

    #region Step 5
    public async Task Step5()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 5: Compare RU Costs - combined (largeBlob + metadata) ===\n");

        string largeBlob = string.Join("", Enumerable.Range(0, 10000).Select(_ => (char)('a' + Random.Shared.Next(26))));
        var metadata = Enumerable.Range(0, 50).ToDictionary(i => $"tag{i}", i => $"value_{i}");

        var itemDefault = new { id = $"both_test_{Guid.NewGuid():N}", partitionKey = "idx", largeBlob, metadata };
        var itemCustom = new { id = $"both_test_{Guid.NewGuid():N}", partitionKey = "idx", largeBlob, metadata };

        await CompareRu(itemDefault, itemCustom);
    }
    #endregion

    #region Helpers
    private async Task CompareRu<T>(T itemDefault, T itemCustom)
    {
        var defaultContainer = DB!.GetContainer(DefaultContainerName);
        var customContainer = DB!.GetContainer(CustomContainerName);

        var respDefault = await defaultContainer.CreateItemAsync(itemDefault, new PartitionKey("idx"));
        Console.WriteLine($"  Default index - RU: {respDefault.RequestCharge:F2}");

        var respCustom = await customContainer.CreateItemAsync(itemCustom, new PartitionKey("idx"));
        Console.WriteLine($"  Custom index   - RU: {respCustom.RequestCharge:F2}");

        double ruSavings = respDefault.RequestCharge - respCustom.RequestCharge;
        double percentSavings = (ruSavings / respDefault.RequestCharge) * 100;
        Console.WriteLine($"  RU savings: {ruSavings:F2} RU ({percentSavings:F1}%)\n");
    }
    #endregion
}
