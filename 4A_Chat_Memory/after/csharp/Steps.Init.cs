using Azure.Identity;
using Azure.AI.OpenAI;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;
using System.IdentityModel.Tokens.Jwt;

namespace Lab4A;

public partial class Steps
{
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

    public async Task Init()
    {
        // Cosmos DB connection
        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");

        ////////////////////////////////////////////////////////////////////////////
        // This is only for development and should be replaced with DefaultAzureCredential in final lab
        var credential = new InteractiveBrowserCredential(new InteractiveBrowserCredentialOptions
        {
            TenantId = "d3f85f22-2cc4-4aa6-9485-9eb73ab53a1d",
            TokenCachePersistenceOptions = new TokenCachePersistenceOptions
            {
                Name = "CosmosChatAgentTokenCache",
                UnsafeAllowUnencryptedStorage = true,
            }
        });

        string[] scopes = new string[] { "https://graph.microsoft.com/.default" };
        var token = await credential.GetTokenAsync(new Azure.Core.TokenRequestContext(scopes));
        var handler = new JwtSecurityTokenHandler();
        var jsonToken = handler.ReadToken(token.Token) as JwtSecurityToken;
        var upn = jsonToken?.Claims.FirstOrDefault(c => c.Type == "upn")?.Value ?? jsonToken?.Claims.FirstOrDefault(c => c.Type == "email")?.Value;
        Console.WriteLine($"Logging in as {upn}");
        ///////////////////////////////////////////////////////////////////////////

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
}
