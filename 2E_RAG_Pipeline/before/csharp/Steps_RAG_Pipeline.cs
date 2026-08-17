// Lab 2E: RAG Pipeline - Consolidated Steps (STUDENT VERSION)

#nullable enable
using Azure;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;
using OpenAI.Embeddings;

namespace Lab2E;

public class Steps_RAG_Pipeline
{
    #region State
    public string? CosmosEndpoint { get; private set; }
    public string DbName { get; private set; } = "WorkshopData";
    public string ContainerName { get; private set; } = "Docs";
    public CosmosClient? CosmosClient { get; private set; }
    public Database? DB { get; private set; }
    public Container? Container { get; private set; }
    public AzureOpenAIClient? OpenAIClient { get; private set; }
    public AzureOpenAIClient? EmbeddingsOpenAIClient { get; private set; }
    public string? FoundryEndpoint { get; private set; }
    public string? EmbeddingsEndpoint { get; private set; }
    public string? CompletionsModel { get; private set; }
    public string EmbeddingsModel { get; private set; } = "textembedding3small";

    private EmbeddingClient? _embeddingClient;
    private ChatClient? _chatClient;

    private static readonly List<Dictionary<string, string>> SampleDocs = new()
    {
        new Dictionary<string, string> {
            { "id", "doc1" },
            { "title", "Cosmos DB Overview" },
            { "content", "Azure Cosmos DB is a globally distributed, multi-model database service. " +
                        "It supports multiple API modes including SQL, MongoDB, Cassandra, Table, and Gremlin. " +
                        "Cosmos DB provides five consistency levels: Strong, Bounded Staleness, Session, Consistent Prefix, and Eventual." }
        },
        new Dictionary<string, string> {
            { "id", "doc2" },
            { "title", "Vector Search" },
            { "content", "Azure Cosmos DB supports vector indexing for semantic similarity search queries. " +
                        "Vector search enables finding semantically similar items by comparing embeddings. " +
                        "The VectorDistance function calculates similarity scores between vectors." }
        },
        new Dictionary<string, string> {
            { "id", "doc3" },
            { "title", "Data Modeling" },
            { "content", "Effective data modeling in Cosmos DB involves choosing the right partition key. " +
                        "Composite partition keys can help distribute load across partitions. " +
                        "Denormalization and fan-out patterns can optimize read performance." }
        }
    };

    private CosmosClient CreateCosmosClient(string endpoint)
    {
        var credential = new AzureCliCredential();

        return new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
    }

    #endregion

    #region Init
    public async Task Init()
    {
        Console.WriteLine("\n=== Step 0: Setup (Connection) ===\n");

        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");
        var foundryEndpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT environment variable is required.");
        var embeddingsEndpoint = Environment.GetEnvironmentVariable("EMBEDDINGS_ENDPOINT")
            ?? throw new InvalidOperationException("EMBEDDINGS_ENDPOINT environment variable is required.");
        CosmosClient = CreateCosmosClient(cosmosEndpoint);
        DB = CosmosClient.GetDatabase(DbName);
        Container = DB.GetContainer(ContainerName);
        CosmosEndpoint = cosmosEndpoint;

        CompletionsModel = Environment.GetEnvironmentVariable("COMPLETIONS_MODEL") ?? "gpt41";
        EmbeddingsModel = Environment.GetEnvironmentVariable("EMBEDDINGS_MODEL") ?? "textembedding3small";

        OpenAIClient = new AzureOpenAIClient(new Uri(foundryEndpoint), new AzureCliCredential());
        FoundryEndpoint = foundryEndpoint;
        _chatClient = OpenAIClient.GetChatClient(CompletionsModel);

        EmbeddingsOpenAIClient = new AzureOpenAIClient(new Uri(embeddingsEndpoint), new AzureCliCredential());
        EmbeddingsEndpoint = embeddingsEndpoint;
        _embeddingClient = EmbeddingsOpenAIClient.GetEmbeddingClient(EmbeddingsModel);

        Console.WriteLine($"  endpoint:   {cosmosEndpoint}");
        Console.WriteLine($"  database:   {DbName}");
        Console.WriteLine($"  container:  {ContainerName}");
        Console.WriteLine($"  foundry:    {foundryEndpoint} (chat: {CompletionsModel})");
        Console.WriteLine($"  embeddings: {embeddingsEndpoint} (model: {EmbeddingsModel})");
    }
    #endregion

    #region Step 1
    public Task Step1()
    {
        Console.WriteLine("\n=== Step 1: Text Chunking and Seed Documents (Prebuilt) ===\n");

        foreach (var doc in SampleDocs)
        {
            var chunks = ChunkText(doc["content"]);
            Console.WriteLine($"  Chunked '{doc["title"]}': {chunks.Count} chunks");
        }

        Console.WriteLine($"Total: {SampleDocs.Count} documents loaded");
        return Task.CompletedTask;
    }

    private static List<string> ChunkText(string text, int chunkSize = 512)
    {
        var chunks = new List<string>();
        var currentChunk = new List<string>();
        var currentSize = 0;

        var sentences = text.Split(new[] { ". ", "! ", "? " }, StringSplitOptions.RemoveEmptyEntries);

        foreach (var sentence in sentences)
        {
            if (currentSize + sentence.Length > chunkSize && currentChunk.Count > 0)
            {
                chunks.Add(string.Join(".", currentChunk) + ".");
                currentChunk = new List<string> { sentence };
                currentSize = sentence.Length;
            }
            else
            {
                currentChunk.Add(sentence);
                currentSize += sentence.Length;
            }
        }

        if (currentChunk.Count > 0)
        {
            chunks.Add(string.Join(".", currentChunk) + ".");
        }

        return chunks;
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (Container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 2: Embed and Store Chunks (Prebuilt) ===\n");

        foreach (var doc in SampleDocs)
        {
            var chunks = ChunkText(doc["content"]);

            for (int i = 0; i < chunks.Count; i++)
            {
                var chunk = chunks[i];
                var embedding = GetEmbedding(chunk);

                var storedDoc = new Dictionary<string, object>
                {
                    { "id", $"{doc["id"]}_chunk_{i}" },
                    { "title", doc["title"] },
                    { "text", chunk },
                    { "embedding", embedding },
                    { "source", doc["id"] },
                    { "partitionKey", "rag" }
                };

                try
                {
                    var response = await Container.UpsertItemAsync(storedDoc, new PartitionKey("rag"));
                    Console.WriteLine($"  Stored chunk {i+1} of {doc["title"]} (chunks={chunks.Count})");
                    Console.WriteLine($"  RU charged: {response.RequestCharge}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  Error storing chunk: {ex.Message}");
                }
            }
        }

        Console.WriteLine("Chunk embedding and storage complete.");
    }

    private List<float> GetEmbedding(string text)
    {
        if (_embeddingClient is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");
        var embedding = _embeddingClient.GenerateEmbedding(text);
        return embedding.Value.ToFloats().ToArray().ToList();
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        Console.WriteLine("\n=== Step 3: RAG Retrieval (STUDENT EXERCISE) ===\n");

        string testQuery = "What is vector search in Azure Cosmos DB?";
        Console.WriteLine($"Retrieving for: \"{testQuery}\"\n");

        var results = await RetrieveRelevant(testQuery, 3);
        Console.WriteLine($"Found {results.Count} results:\n");
        foreach (var result in results)
        {
            var text = (string)result["text"];
            Console.WriteLine($"  Title: {result["title"]}");
            Console.WriteLine($"  Score: {result["score"]}");
            Console.WriteLine($"  Text: {text.Substring(0, Math.Min(100, text.Length))}...\n");
        }

        Console.WriteLine("Retrieval complete.");
    }

    private async Task<List<Dictionary<string, object>>> RetrieveRelevant(string textQuery, int topK = 3)
    {
        if (Container is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        var queryEmbedding = GetEmbedding(textQuery);

        // STUDENT EXERCISE: replace the placeholder query string below with a TOP @topK VectorDistance query
        // ordered by VectorDistance. See Instructions.md Step 3.
        var vectorQuery = "SELECT '(placeholder)' AS title, '(placeholder)' AS text, 0 AS score WHERE 1=0";

        var queryDefinition = new QueryDefinition(vectorQuery)
            .WithParameter("@emb", queryEmbedding);

        var iterator = Container.GetItemQueryIterator<Dictionary<string, object>>(
            queryDefinition,
            null,
            new QueryRequestOptions { PartitionKey = new PartitionKey("rag") }
        );

        var results = new List<Dictionary<string, object>>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }
    #endregion

    #region Step 4
    public async Task Step4()
    {
        Console.WriteLine("\n=== Step 4: RAG Generation (STUDENT EXERCISE) ===\n");

        string testQuestion = "What is vector search in Azure Cosmos DB?";
        Console.WriteLine($"Question: {testQuestion}");

        string answer = await GenerateResponse(testQuestion);
        Console.WriteLine($"\nAnswer:\n{answer}");

        Console.WriteLine("\n=== COMPLETE ===");
    }

    private async Task<string> GenerateResponse(string question)
    {
        if (_chatClient is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        var results = await RetrieveRelevant(question, 3);
        var context = string.Join("\n\n", results.Select(r => (string)r["text"]));

        // STUDENT EXERCISE: replace the placeholder systemPrompt below with one that grounds the
        // chat model in the retrieved <context>. See Instructions.md Step 4.
        var systemPrompt = "You are a helpful assistant. (placeholder - no context grounding)";

        var messages = new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(question)
        };

        var options = new ChatCompletionOptions();

        try
        {
            var completion = await _chatClient.CompleteChatAsync(messages, options);
            return completion.Value.Content[0].Text;
        }
        catch (Exception ex)
        {
            return $"Error generating response: {ex.Message}";
        }
    }
    #endregion
}
