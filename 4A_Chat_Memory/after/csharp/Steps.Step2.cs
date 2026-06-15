using System.Text.Json;
using Microsoft.Azure.Cosmos;

namespace Lab4A;

public partial class Steps
{
    public async Task Step2()
    {
        Console.WriteLine("\n=== Step 2: Chat store message schema ===");

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

        Console.WriteLine(JsonSerializer.Serialize(sampleChatStoreMessage, new JsonSerializerOptions { WriteIndented = true }));
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
}
