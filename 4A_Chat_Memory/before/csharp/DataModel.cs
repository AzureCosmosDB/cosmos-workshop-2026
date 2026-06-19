namespace Lab4A;

public enum MessageRole { System, User, Assistant }

record ChatStoreMessage(
    string Id,
    string SessionId,
    MessageRole Role,
    string Content,
    DateTime Timestamp,
    ChatMessageMetadata? Metadata = null
);

record ChatMessageMetadata(
    string Model = "",
    int LatencyMs = 0,
    int PromptTokens = 0,
    int CompletionTokens = 0,
    int TotalTokens = 0,
    int RagHits = 0,
    string[] RetrievedDocIds = null!
); 

record RagDocument(
    string Id,
    string PartitionKey,
    string Title,
    string Text,
    float[] Embedding
); 

record RagHit(
    string Id,
    string Title,
    string Text,
    double Score
);