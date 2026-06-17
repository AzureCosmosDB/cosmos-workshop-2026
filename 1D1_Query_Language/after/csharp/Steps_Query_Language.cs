// Lab 1D1: Query Language - Consolidated Steps

using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace Lab1D1;

public class Steps_Query_Language
{
    #region State
    private string _endpoint = "";
    private CosmosClient _client = null!;
    private Database _db = null!;
    private Container _container = null!;

    public List<dynamic> SeededItems { get; private set; } = new();
    public bool IsSeeded { get; private set; }

    public List<dynamic> Fruits { get; private set; } = new();
    public bool FruitQueryRun { get; private set; }

    public bool ParameterizedQueryRun { get; private set; }

    private CosmosClient CreateClient(string endpoint)
    {
        var credential = new DefaultAzureCredential();
        return new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
    }
    #endregion

    #region Init
    public async Task Init()
    {
        _endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        Console.WriteLine("=== INIT: Connection ===\n");

        _client = CreateClient(_endpoint);
        _db = _client.GetDatabase("WorkshopData");
        _container = _db.GetContainer("Catalog");

        Console.WriteLine($"Connected to: {_endpoint}/WorkshopData/Catalog");
    }
    #endregion

    #region Step 1
    public async Task Step1()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== SETUP: Verifying connection ===");
        Console.WriteLine($"Database: WorkshopData");
        Console.WriteLine($"Container: Catalog");
        Console.WriteLine($"Endpoint: {_endpoint}");
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== SEEDING DATA ===");

        SeededItems = new List<dynamic>
        {
            new { id = "1", name = "Apples",   category = "fruit",     price = 1.20, partitionKey = "grocery",
                  tags = new[] { "organic", "seasonal", "domestic" },
                  nutrition = new { calories = 95,  vitamins = new[] { "A", "C" } } },
            new { id = "2", name = "Broccoli", category = "vegetable", price = 2.50, partitionKey = "grocery",
                  tags = new[] { "organic", "fresh" },
                  nutrition = new { calories = 55,  vitamins = new[] { "C", "K", "A" } } },
            new { id = "3", name = "Bananas",  category = "fruit",     price = 0.80, partitionKey = "grocery",
                  tags = new[] { "imported", "ripe" },
                  nutrition = new { calories = 105, vitamins = new[] { "B6", "C" } } },
            new { id = "4", name = "Carrots",  category = "vegetable", price = 1.00, partitionKey = "grocery",
                  tags = new[] { "organic", "root", "fresh" },
                  nutrition = new { calories = 41,  vitamins = new[] { "A", "K" } } },
            new { id = "5", name = "Dates",    category = "fruit",     price = 4.00, partitionKey = "grocery",
                  tags = new[] { "imported", "dried", "premium" },
                  nutrition = new { calories = 280, vitamins = new[] { "B6", "K" } } }
        };

        foreach (var item in SeededItems)
        {
            try
            {
                var response = await _container.UpsertItemAsync<dynamic>(item, new PartitionKey(item.partitionKey));
                Console.WriteLine($"Upserted: {item.name}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

        IsSeeded = true;
        Console.WriteLine($"\nSeeded {SeededItems.Count} items");
    }
    #endregion

    #region Step 3
    // STUDENT EXERCISE: Students should fill in the QueryDefinition parameter and verify the output shows 3 fruit items (Apples, Bananas, Dates).
    public async Task Step3()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== Query for all fruits (STUDENT EXERCISE) ===");

        if (!IsSeeded)
        {
            Console.WriteLine("Warning: Seed data may not be present. Run Step 2 first.");
        }

        string categoryToQuery = "fruit";

        var query = new QueryDefinition("SELECT * FROM c WHERE c.category = @cat")
            .WithParameter("@cat", categoryToQuery);

        var iterator = _container.GetItemQueryIterator<dynamic>(query);
        Fruits = new List<dynamic>();

        FeedResponse<dynamic> response = null!;
        while (iterator.HasMoreResults)
        {
            response = await iterator.ReadNextAsync();
            foreach (var item in response)
            {
                Fruits.Add(item);
                Console.WriteLine($"  {item.name}: ${item.price}");
            }
        }

        Console.WriteLine($"RU charged: {response.RequestCharge}");
        FruitQueryRun = true;
        Console.WriteLine($"Found {Fruits.Count} fruit items");
    }
    #endregion

    #region Step 4
    public async Task Step4()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== Point Read vs Query Cost ===");
        Console.WriteLine("Fetching the same single item (id='1') two different ways.\n");

        var pointReadResponse = await _container.ReadItemAsync<dynamic>("1", new PartitionKey("grocery"));
        double pointReadRu = pointReadResponse.RequestCharge;

        var iterator = _container.GetItemQueryIterator<dynamic>(
            new QueryDefinition("SELECT * FROM c WHERE c.id = '1'"));

        double queryRuActual = 0;
        FeedResponse<dynamic> response = null!;
        while (iterator.HasMoreResults)
        {
            response = await iterator.ReadNextAsync();
            queryRuActual += response.RequestCharge;
        }

        Console.WriteLine($"Point read (1 item by id + partition key): {pointReadRu} RU");
        Console.WriteLine($"Query  (SELECT * FROM c WHERE c.id='1'):   {queryRuActual} RU");
        Console.WriteLine($"Point read is {queryRuActual / pointReadRu:F1}x cheaper for fetching a single item by id.");
    }
    #endregion

    #region Step 5
    // STUDENT EXERCISE: Students should set limit to 3 and verify the output shows top 3 items by price descending.
    public async Task Step5()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== Parameterized query (STUDENT EXERCISE) ===");

        int limit = 3;

        var topQuery = new QueryDefinition("SELECT TOP @limit c.name, c.price FROM c ORDER BY c.price DESC")
            .WithParameter("@limit", limit);

        var topIterator = _container.GetItemQueryIterator<dynamic>(topQuery);
        var topItems = new List<dynamic>();

        Console.WriteLine($"Top {limit} items by price (descending):");
        FeedResponse<dynamic> response = null!;
        while (topIterator.HasMoreResults)
        {
            response = await topIterator.ReadNextAsync();
            foreach (var item in response)
            {
                topItems.Add(item);
                Console.WriteLine($"  {item.name}: ${item.price}");
            }
            Console.WriteLine($"RU charged: {response.RequestCharge}");
        }

        ParameterizedQueryRun = true;
    }
    #endregion

    #region Step 6
    public async Task Step6()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== JSON properties + system functions ===");
        Console.WriteLine("Filter on a nested property and an array tag, project with CONCAT().\n");

        var query = new QueryDefinition(
            "SELECT c.name, CONCAT(c.category, ' category') AS category, c.nutrition.calories " +
            "FROM c " +
            "WHERE ARRAY_CONTAINS(c.tags, 'organic') AND c.nutrition.calories < 100");

        var iterator = _container.GetItemQueryIterator<dynamic>(query);

        FeedResponse<dynamic> response = null!;
        while (iterator.HasMoreResults)
        {
            response = await iterator.ReadNextAsync();
            foreach (var item in response)
            {
                Console.WriteLine($"  {item.name} ({item.category}): {item.calories} cal");
            }
        }

        Console.WriteLine($"RU charged: {response.RequestCharge}");
    }
    #endregion

    #region Step 7
    public async Task Step7()
    {
        if (_container is null) throw new InvalidOperationException("Run Init() first.");

        Console.WriteLine("\n=== Subquery over a nested array ===");
        Console.WriteLine("Use a subquery to count vitamins per item.\n");

        var query = new QueryDefinition(
            "SELECT c.name, " +
            "       (SELECT VALUE COUNT(1) FROM v IN c.nutrition.vitamins) AS vitaminCount " +
            "FROM c " +
            "ORDER BY c.name");

        var iterator = _container.GetItemQueryIterator<dynamic>(query);

        FeedResponse<dynamic> response = null!;
        while (iterator.HasMoreResults)
        {
            response = await iterator.ReadNextAsync();
            foreach (var item in response)
            {
                Console.WriteLine($"  {item.name}: {item.vitaminCount} vitamins");
            }
        }

        Console.WriteLine($"RU charged: {response.RequestCharge}");
    }
    #endregion
}
