// Lab 2C: Completions + Embeddings - Consolidated Steps (STUDENT VERSION)

#nullable enable
using System.Numerics.Tensors;
using System.Text.Json;
using Azure;
using Azure.AI.OpenAI;
using Azure.AI.OpenAI.Embeddings;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;

namespace Lab2C;

public class Steps_Completions_Embeddings
{
    #region State
    public string? CosmosEndpoint { get; private set; }
    public string DbName { get; private set; } = "WorkshopData";
    public CosmosClient? CosmosClient { get; private set; }
    public Database? DB { get; private set; }
    public AzureOpenAIClient? OpenAIClient { get; private set; }
    public AzureOpenAIClient? EmbeddingsOpenAIClient { get; private set; }
    public string? FoundryEndpoint { get; private set; }
    public string? EmbeddingsEndpoint { get; private set; }
    public string? CompletionsModel { get; private set; }
    public string EmbeddingsModel { get; private set; } = "textembedding3small";
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
        var embeddingsKey = Environment.GetEnvironmentVariable("EMBEDDINGS_KEY")
            ?? throw new InvalidOperationException("EMBEDDINGS_KEY environment variable is required.");

        var credential = new DefaultAzureCredential();

        CosmosClient = new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });

        DB = CosmosClient.GetDatabase(DbName);
        CosmosEndpoint = cosmosEndpoint;

        OpenAIClient = new AzureOpenAIClient(new Uri(foundryEndpoint), credential);
        FoundryEndpoint = foundryEndpoint;

        EmbeddingsOpenAIClient = new AzureOpenAIClient(
            new Uri(embeddingsEndpoint),
            new System.ClientModel.ApiKeyCredential(embeddingsKey));
        EmbeddingsEndpoint = embeddingsEndpoint;

        CompletionsModel = Environment.GetEnvironmentVariable("COMPLETIONS_MODEL") ?? "gpt41";
        EmbeddingsModel = Environment.GetEnvironmentVariable("EMBEDDINGS_MODEL") ?? "textembedding3small";

        Console.WriteLine($"  endpoint:    {cosmosEndpoint}");
        Console.WriteLine($"  database:    {DbName}");
        Console.WriteLine($"  foundry:     {foundryEndpoint}");
        Console.WriteLine($"  embeddings:  {embeddingsEndpoint}");
        Console.WriteLine($"  connected:   {cosmosEndpoint}/{DbName}");
    }
    #endregion

    #region Step 1
    public async Task Step1()
    {
        if (OpenAIClient is null) throw new InvalidOperationException("OpenAIClient not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Chat Completions (STUDENT EXERCISE) ===\n");

        var chatClient = OpenAIClient.GetChatClient(CompletionsModel ?? "gpt41");

        var message = "Explain partitioning in Cosmos DB in 2 sentences.";
        var messages1 = new List<ChatMessage>
        {
            new SystemChatMessage("You are a data platform expert."),
            new UserChatMessage(message)
        };

        var completionsOptions = new ChatCompletionOptions
        {
            Temperature = 0.7f,
            MaxOutputTokenCount = 200,
            TopP = 0.95f
        };

        try
        {
            Console.WriteLine($"Sending chat completion request: {message}");

            // STUDENT EXERCISE: replace the placeholder below with a CompleteChatAsync call. See Instructions.md Step 1.
            var completion = new { Value = new { Content = new[] { new { Text = "(placeholder)" } }, Usage = new { InputTokenCount = 0, OutputTokenCount = 0 } } };

            Console.WriteLine($"Response: {completion.Value.Content[0].Text}");
            Console.WriteLine($"Token usage - Prompt: {completion.Value.Usage.InputTokenCount}, Completion: {completion.Value.Usage.OutputTokenCount}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        if (OpenAIClient is null) throw new InvalidOperationException("OpenAIClient not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 2: Streaming response (STUDENT EXERCISE) ===\n");

        var chatClient = OpenAIClient.GetChatClient(CompletionsModel ?? "gpt41");

        var message = "List 5 Cosmos DB consistency levels and their use cases.";
        var messages2 = new List<ChatMessage>
        {
            new UserChatMessage(message)
        };

        Console.WriteLine($"Sending chat completion request: {message}");
        Console.Write("Streaming response: ");

        // STUDENT EXERCISE: replace the placeholder below with a CompleteChatStreamingAsync loop. See Instructions.md Step 2.
        Console.Write("(placeholder - streaming not implemented)");

        Console.WriteLine();
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        if (EmbeddingsOpenAIClient is null) throw new InvalidOperationException("EmbeddingsOpenAIClient not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 3: Generate embeddings and compare (STUDENT EXERCISE) ===\n");

        var texts = new List<string>
        {
            "Azure Cosmos DB is globally distributed.",
            "Microsoft Azure is a cloud platform.",
            "Cosmos DB vector search supports semantic similarity."
        };

        var embeddings = new List<(string text, float[] embedding)>();

        Console.WriteLine("Generating embeddings:");
        foreach (var text in texts)
        {
            var embedding = GetEmbedding(text);
            embeddings.Add((text, embedding));
            Console.WriteLine($"  {text.Substring(0, Math.Min(40, text.Length))}... dim={embedding.Length}");
        }

        float cosineSimilarity = TensorPrimitives.CosineSimilarity(
            embeddings[0].embedding,
            embeddings[2].embedding);

        Console.WriteLine($"\nCosine similarity (docs 1 vs 3): {cosineSimilarity:F4}");
        Console.WriteLine($"Note: Higher value = more similar (range: -1 to 1)");

        Console.WriteLine("\n=== COMPLETE ===");
    }

    // Maps each input string to a fixed-size vector (1536 dims for text-embedding-3-small)
    // where semantically similar texts land near each other in vector space.
    private float[] GetEmbedding(string text)
    {
        if (EmbeddingsOpenAIClient is null) throw new InvalidOperationException("EmbeddingsOpenAIClient not initialized. Run Step 0 first.");

        // STUDENT EXERCISE: replace the placeholder return below with a call to the embeddings client. See Instructions.md Step 3.
        return new float[1536]; // (placeholder) zero vector
    }
    #endregion
}
