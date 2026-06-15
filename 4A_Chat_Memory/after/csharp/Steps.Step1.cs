using System.Text.Json;
using Microsoft.Azure.Cosmos;

namespace Lab4A;

public partial class Steps
{
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

}
