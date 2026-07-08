// Lab 4A: Conversational History / Agent Memory - Consolidated Steps

using System.Diagnostics;
using System.Text.Json;
using Azure.Identity;
using Azure.AI.OpenAI;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;

namespace Lab4A;

public class Steps_Chat_Memory
{
    #region State
    // Cosmos DB clients
    public CosmosClient CosmosClient { get; private set; } = null!;
    public Container ChatContainer { get; private set; } = null!;
    public Container RagContainer { get; private set; } = null!;
    public string ChatDbName { get; private set; } = "";
    public string ChatContainerName { get; private set; } = "";
    public string RagDbName { get; private set; } = "";
    public string RagContainerName { get; private set; } = "";

    // Azure OpenAI clients
    public AzureOpenAIClient FoundryClient { get; private set; } = null!;
    public AzureOpenAIClient EmbeddingsClient { get; private set; } = null!;
    public ChatClient ChatClient { get; private set; } = null!;
    public OpenAI.Embeddings.EmbeddingClient EmbeddingClient { get; private set; } = null!;
    public string ChatModel { get; private set; } = "";
    public string EmbeddingsModel { get; private set; } = "";

    // Runtime state
    public string SessionId { get; private set; } = "";
    #endregion

    #region Init
    public async Task Init()
    {
        // Cosmos DB connection
        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        var credential = new DefaultAzureCredential();

        CosmosClient = new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });

        // Chat memory: Conversations/Messages (pre-provisioned, partition key /sessionId)
        ChatDbName = "Conversations";
        ChatContainerName = "Messages";
        var chatDatabase = CosmosClient.GetDatabase(ChatDbName);
        ChatContainer = chatDatabase.GetContainer(ChatContainerName);
        Console.WriteLine($"Chat memory: {cosmosEndpoint}{ChatDbName}/{ChatContainerName}");

        // RAG corpus: WorkshopData/Docs (pre-provisioned with vector index on /embedding)
        RagDbName = "WorkshopData";
        RagContainerName = "Docs";
        var ragDatabase = CosmosClient.GetDatabase(RagDbName);
        RagContainer = ragDatabase.GetContainer(RagContainerName);
        Console.WriteLine($"RAG corpus:  {cosmosEndpoint}{RagDbName}/{RagContainerName}");

        // Azure OpenAI connection
        // Chat completions: Foundry endpoint, Entra ID auth.
        // Embeddings: separate Azure OpenAI resource, API key auth.
        var foundryEndpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT environment variable is required.");
        var embeddingsEndpoint = Environment.GetEnvironmentVariable("EMBEDDINGS_ENDPOINT")
            ?? throw new InvalidOperationException("EMBEDDINGS_ENDPOINT environment variable is required.");
        var embeddingsKey = Environment.GetEnvironmentVariable("EMBEDDINGS_KEY")
            ?? throw new InvalidOperationException("EMBEDDINGS_KEY environment variable is required.");
        ChatModel = Environment.GetEnvironmentVariable("COMPLETIONS_MODEL")
            ?? throw new InvalidOperationException("COMPLETIONS_MODEL environment variable is required.");
        EmbeddingsModel = Environment.GetEnvironmentVariable("EMBEDDINGS_MODEL")
            ?? throw new InvalidOperationException("EMBEDDINGS_MODEL environment variable is required.");

        FoundryClient = new AzureOpenAIClient(new Uri(foundryEndpoint), credential);
        EmbeddingsClient = new AzureOpenAIClient(
            new Uri(embeddingsEndpoint),
            new System.ClientModel.ApiKeyCredential(embeddingsKey));
        ChatClient = FoundryClient.GetChatClient(ChatModel);
        EmbeddingClient = EmbeddingsClient.GetEmbeddingClient(EmbeddingsModel);

        SessionId = Guid.NewGuid().ToString();

        Console.WriteLine($"\nSession ID:       {SessionId}");
        Console.WriteLine($"Chat Model:       {ChatModel}");
        Console.WriteLine($"Embeddings Model: {EmbeddingsModel}");
    }
    #endregion

    #region Step 1
    private record RagSeedDoc(string Id, string Title, string Text);

    public async Task Step1()
    {
        var seedPath = Path.Combine(AppContext.BaseDirectory, "rag_seed_docs.json");
        await using var stream = File.OpenRead(seedPath);
        var ragSeedDocs = await JsonSerializer.DeserializeAsync<List<RagSeedDoc>>(
            stream,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }
        ) ?? throw new InvalidOperationException($"Failed to load seed docs from {seedPath}");

        foreach (var seed in ragSeedDocs)
        {
            float[] embedding = await EmbedText(seed.Text);
            var doc = new RagDocument(seed.Id, "rag", seed.Title, seed.Text, embedding);
            await RagContainer.UpsertItemAsync(doc, new PartitionKey("rag"));
            Console.WriteLine($"  Seeded: {seed.Title}");
        }
        Console.WriteLine($"\nSeeded {ragSeedDocs.Count} docs into {RagDbName}/{RagContainerName}");
    }

    private async Task<float[]> EmbedText(string text)
    {
        var resp = await EmbeddingClient.GenerateEmbeddingAsync(text);
        return resp.Value.ToFloats().ToArray();
    }
    #endregion

    #region Step 2
    public async Task Step2()
    {
        Console.WriteLine("\n=== Step 2: Chat store message schema (Prebuilt) ===");

        var sampleChatStoreMessage = new ChatStoreMessage(
            Id: "chat_20260524_001",
            SessionId: "user_session_001",
            Role: MessageRole.Assistant,
            Content: "Hello! How can I help you with Cosmos DB today?",
            Timestamp: new DateTime(2026, 5, 24, 10, 0, 0, DateTimeKind.Utc),
            Metadata: new ChatMessageMetadata(
                Model: "phi-4-mini-reasoning",
                LatencyMs: 842,
                PromptTokens: 312,
                CompletionTokens: 128,
                TotalTokens: 440,
                RagHits: 3,
                RetrievedDocIds: new[] { "cosmos_overview", "cosmos_vector_search", "cosmos_request_units" }
            )
        );

        Console.WriteLine(JsonSerializer.Serialize(sampleChatStoreMessage, new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
        }));
        Console.WriteLine("\nThis is the record schema used to store conversation turns in Cosmos DB.");

        await SaveChatTurn(SessionId, MessageRole.User, "What is Cosmos DB?");
        Console.WriteLine("Saved user message");

        await SaveChatTurn(
            SessionId,
            MessageRole.Assistant,
            "Azure Cosmos DB is a globally distributed database service.",
            new ChatMessageMetadata { Model = ChatModel, LatencyMs = 0, TotalTokens = 0 }
        );
        Console.WriteLine("Saved assistant message");
    }

    private async Task<ChatStoreMessage> SaveChatTurn(string sid, MessageRole role, string content, ChatMessageMetadata? metadata = null)
    {
        var message = new ChatStoreMessage(
            Id: $"{sid}_{Guid.NewGuid().ToString().Substring(0, 8)}",
            SessionId: sid,
            Role: role,
            Content: content,
            Timestamp: DateTime.UtcNow,
            Metadata: metadata
        );
        await ChatContainer.CreateItemAsync(message, new PartitionKey(sid));
        return message;
    }
    #endregion

    #region Step 3
    public async Task Step3()
    {
        var recent = await GetRecentMessages(SessionId, 10);
        Console.WriteLine($"Retrieved {recent.Count} recent messages:");
        foreach (var msg in recent)
        {
            Console.WriteLine($"  [{msg.Role}]: {msg.Content}");
        }

        // Sanity-check retrieval
        Console.WriteLine("=== Retrieval check ===");
        foreach (var hit in await RetrieveRelevant("How does vector search work in Cosmos DB?", topK: 3))
        {
            Console.WriteLine($"  - [{hit.Id}] score={hit.Score:F4}  {hit.Title}");
        }
    }

    private async Task<List<ChatStoreMessage>> GetRecentMessages(string sid, int count = 10)
    {
        var query = $@"SELECT * FROM c WHERE c.sessionId = @sessionId
                            ORDER BY c._ts DESC OFFSET 0 LIMIT {count}";
        var queryDefinition = new QueryDefinition(query)
            .WithParameter("@sessionId", sid);
        var options = new QueryRequestOptions { PartitionKey = new PartitionKey(sid) };
        var iterator = ChatContainer.GetItemQueryIterator<ChatStoreMessage>(queryDefinition, null, options);
        var messages = new List<ChatStoreMessage>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            messages.AddRange(response);
        }
        return messages;
    }

    private async Task<List<RagHit>> RetrieveRelevant(string query, int topK = 3)
    {
        var queryEmbedding = await EmbedText(query);

        var vectorQuery = $@"SELECT TOP {topK} c.id, c.title, c.text,
                                  VectorDistance(c.embedding, @emb) AS score
                                  FROM c WHERE c.partitionKey = 'rag'
                                  ORDER BY VectorDistance(c.embedding, @emb)";

        var queryDefinition = new QueryDefinition(vectorQuery)
            .WithParameter("@emb", queryEmbedding);

        var options = new QueryRequestOptions { PartitionKey = new PartitionKey("rag") };
        var iterator = RagContainer.GetItemQueryIterator<RagHit>(queryDefinition, null, options);

        var hits = new List<RagHit>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            hits.AddRange(response);
        }
        return hits;
    }
    #endregion

    #region Step 4
    public async Task Step4()
    {
        var userMessage = "How does vector search work in Cosmos DB?";
        var answer = await ChatAgent(SessionId, userMessage);
        Console.WriteLine();
        Console.WriteLine($"Assistant: {answer}");
        Console.WriteLine();
    }

    private async Task<string> ChatAgent(string sid, string userMessage)
    {
        const string baseSystemPrompt = "You are a helpful assistant specializing in Azure Cosmos DB.";

        await SaveChatTurn(sid, MessageRole.User, userMessage);

        var context = await GetRecentMessages(sid, 10);
        var ordered = context.AsEnumerable().Reverse().ToList();
        var window = ordered.Skip(Math.Max(0, ordered.Count - 6));
        var history = string.Join("\n", window.Select(m => $"{m.Role}: {m.Content}"));

        var hits = await RetrieveRelevant(userMessage, topK: 3);
        var contextText = string.Join("\n\n", hits.Select(h => $"{h.Title}: {h.Text}"));

        var systemContent =
            $"{baseSystemPrompt}\n\n" +
            $"Use the following retrieved context to ground your answer:\n{contextText}\n\n" +
            $"Chat history:\n{history}";

        var messages = new List<ChatMessage>
        {
            ChatMessage.CreateSystemMessage(systemContent),
            ChatMessage.CreateUserMessage(userMessage)
        };

        var sw = Stopwatch.StartNew();
        var completion = await ChatClient.CompleteChatAsync(messages, new ChatCompletionOptions
        {
            Temperature = 0.7f,
            MaxOutputTokenCount = 500
        });
        sw.Stop();
        var latencyMs = (int)sw.ElapsedMilliseconds;

        var answer = completion.Value.Content[0].Text;
        var usage = completion.Value.Usage;

        var assistantMetadata = new ChatMessageMetadata
        {
            Model = ChatModel,
            LatencyMs = latencyMs,
            PromptTokens = usage?.InputTokenCount ?? 0,
            CompletionTokens = usage?.OutputTokenCount ?? 0,
            TotalTokens = usage?.TotalTokenCount ?? 0,
            RagHits = hits.Count,
            RetrievedDocIds = hits.Select(h => h.Id).ToArray()
        };
        await SaveChatTurn(sid, MessageRole.Assistant, answer, assistantMetadata);

        return answer;
    }
    #endregion

    #region Step 5
    public async Task Step5()
    {
        Console.WriteLine($"Chatting in session {SessionId}");
        Console.WriteLine("Enter a question, or blank line / 'quit' / 'exit' to end.");
        Console.WriteLine();

        while (true)
        {
            Console.Write("You: ");
            var userMessage = Console.ReadLine()?.Trim();
            if (string.IsNullOrEmpty(userMessage) ||
                userMessage.Equals("quit", StringComparison.OrdinalIgnoreCase) ||
                userMessage.Equals("exit", StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine("(session ended)");
                break;
            }

            var answer = await ChatAgent(SessionId, userMessage);
            Console.WriteLine();
            Console.WriteLine($"Assistant: {answer}");
            Console.WriteLine();
        }

        var finalHistory = await GetRecentMessages(SessionId, 20);
        finalHistory.Reverse();
        Console.WriteLine($"Total messages in session '{SessionId}': {finalHistory.Count}\n");

        foreach (var msg in finalHistory)
        {
            string roleMarker = msg.Role == MessageRole.User ? "\ud83e\uddd1 User" : "\ud83e\udd16 Assistant";
            Console.WriteLine($"{roleMarker}: {msg.Content}");
        }

        Console.WriteLine("\n=== COMPLETE ===");
    }
    #endregion
}
