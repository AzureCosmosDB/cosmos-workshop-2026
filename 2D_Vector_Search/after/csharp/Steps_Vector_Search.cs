// Lab 2D: Vector Search - Consolidated Steps

#nullable enable
using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace Lab2D;

public class Steps_Vector_Search
{
    #region State
    public string? Endpoint { get; private set; }
    public string DbName { get; private set; } = "WorkshopData";
    public string ContainerName { get; private set; } = "Docs";
    public CosmosClient? Client { get; private set; }
    public Database? DB { get; private set; }
    public Container? Container { get; private set; }
    public AzureOpenAIClient? EmbeddingsOpenAIClient { get; private set; }
    public string? EmbeddingsEndpoint { get; private set; }
    public string EmbeddingsModel { get; private set; } = "text-embedding-3-small";

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
    public async Task Step0()
    {
        Console.WriteLine("\n=== Step 0: Init (Connection) ===\n");

        var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");
        var embeddingsEndpoint = Environment.GetEnvironmentVariable("EMBEDDINGS_ENDPOINT")
            ?? throw new InvalidOperationException("EMBEDDINGS_ENDPOINT environment variable is required.");
        var embeddingsKey = Environment.GetEnvironmentVariable("EMBEDDINGS_KEY")
            ?? throw new InvalidOperationException("EMBEDDINGS_KEY environment variable is required.");

        EmbeddingsModel = Environment.GetEnvironmentVariable("EMBEDDINGS_MODEL") ?? "text-embedding-3-small";

        Client = CreateClient(endpoint);
        DB = Client.GetDatabase(DbName);
        Container = DB.GetContainer(ContainerName);
        Endpoint = endpoint;

        // Embeddings: Azure OpenAI resource, API key auth.
        EmbeddingsOpenAIClient = new AzureOpenAIClient(
            new Uri(embeddingsEndpoint),
            new System.ClientModel.ApiKeyCredential(embeddingsKey));
        EmbeddingsEndpoint = embeddingsEndpoint;

        Console.WriteLine($"Connected to Cosmos DB:   {endpoint}/{DbName}/{ContainerName}");
        Console.WriteLine($"Embeddings client:        {embeddingsEndpoint} (deployment: {EmbeddingsModel})");
    }
    #endregion

    #region Step 1
    public async Task Step1()
    {
        if (Container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (EmbeddingsOpenAIClient is null) throw new InvalidOperationException("EmbeddingsOpenAIClient not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Generate Embeddings (Prebuilt) ===\n");

        var docs = new List<Dictionary<string, object>>
        {
            new Dictionary<string, object>
            {
                { "id", "d1" },
                { "title", "Introduction to Cosmos DB" },
                { "text", "Azure Cosmos DB is a globally distributed, multi-model database service." },
                { "partitionKey", "docs" }
            },
            new Dictionary<string, object>
            {
                { "id", "d2" },
                { "title", "Vector Search Basics" },
                { "text", "Vector search enables semantic similarity search on embeddings." },
                { "partitionKey", "docs" }
            },
            new Dictionary<string, object>
            {
                { "id", "d3" },
                { "title", "Full-Text Search Guide" },
                { "text", "Full-text search in Cosmos DB supports natural language queries." },
                { "partitionKey", "docs" }
            }
        };

        foreach (var doc in docs)
        {
            var text = (string)doc["text"];
            var embedding = await GetEmbedding(text);

            doc["embedding"] = embedding;

            try
            {
                var response = await Container.UpsertItemAsync(doc, new PartitionKey((string)doc["partitionKey"]));
                Console.WriteLine($"  Indexed: {doc["title"]}");
                Console.WriteLine($"  RU charged: {response.RequestCharge}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Error indexing: {ex.Message}");
            }
        }

        Console.WriteLine($"Embedded {docs.Count} documents");
    }

    private async Task<float[]> GetEmbedding(string text)
    {
        if (EmbeddingsOpenAIClient is null) throw new InvalidOperationException("EmbeddingsOpenAIClient not initialized. Run Step 0 first.");

        var embeddingClient = EmbeddingsOpenAIClient.GetEmbeddingClient(EmbeddingsModel);
        var embedding = await embeddingClient.GenerateEmbeddingAsync(text);
        return embedding.Value.ToFloats().ToArray();
    }

    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (Container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        if (EmbeddingsOpenAIClient is null) throw new InvalidOperationException("EmbeddingsOpenAIClient not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 2: Vector Search (STUDENT EXERCISE) ===\n");

        var embeddingClient = EmbeddingsOpenAIClient.GetEmbeddingClient(EmbeddingsModel);

        string searchText = "cosmos db vector search";
        Console.WriteLine($"Searching for: {searchText}\n");

        var queryEmbedding = await embeddingClient.GenerateEmbeddingAsync(searchText);
        var queryVector = queryEmbedding.Value.ToFloats().ToArray();

        var vectorQuery = $"""
            SELECT TOP 2 c.id, c.title, c.text, VectorDistance(c.embedding, @emb) AS score
            FROM c
            WHERE c.partitionKey = 'docs'
            ORDER BY VectorDistance(c.embedding, @emb)
            """;

        var queryDefinition = new QueryDefinition(vectorQuery)
            .WithParameter("@emb", queryVector.ToArray());

        var topResults = await Container.GetItemQueryIterator<Dictionary<string, object>>(
            queryDefinition)
            .ReadNextAsync()
            .ConfigureAwait(false);

        if (topResults.Any())
        {
            Console.WriteLine("Vector search results:");
            foreach (var result in topResults)
            {
                Console.WriteLine($"  Title: {result["title"]}");
                Console.WriteLine($"  Text: {result["text"]}");
                Console.WriteLine($"  Score: {result["score"]}\n");
            }
        }
        else
        {
            Console.WriteLine("No results found.");
        }
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        if (Container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 3: Full-Text Search (STUDENT EXERCISE) ===\n");

        string searchText = "cosmos db";

        // Student exercise: Write a full-text search query using FullTextContains

        var ftsQuery = new QueryDefinition(
            $"SELECT * FROM c WHERE FullTextContains(c.text, @search) AND c.partitionKey = 'docs'")
            .WithParameter("@search", searchText);

        var ftsResults = await Container.GetItemQueryIterator<Dictionary<string, object>>(ftsQuery)
            .ReadNextAsync()
            .ConfigureAwait(false);

        Console.WriteLine($"Full-text search results for '{searchText}':");
        foreach (var result in ftsResults)
        {
            Console.WriteLine($"  ID: {result["id"]}");
            Console.WriteLine($"  Title: {result["title"]}");
            Console.WriteLine($"  Text: {result["text"]}\n");
        }
    }
    #endregion
}
