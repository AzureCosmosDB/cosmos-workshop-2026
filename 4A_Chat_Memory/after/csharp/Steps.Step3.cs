using Microsoft.Azure.Cosmos;

namespace Lab4A;

public partial class Steps
{
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
}
