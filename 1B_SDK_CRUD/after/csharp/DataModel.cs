using System.Text.Json.Serialization;

namespace CosmosLabs;

public class CatalogItemData
{
    public decimal Price { get; set; }
    public string[] Tags { get; set; } = Array.Empty<string>();
}

public class CatalogItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;
    public CatalogItemData Data { get; set; } = new();
    [JsonPropertyName("_etag")]
    public string? ETag { get; set; }
    [JsonPropertyName("_self")]
    public string? SelfLink { get; set; }
    [JsonPropertyName("_ts")]
    public long Timestamp { get; set; }
}
