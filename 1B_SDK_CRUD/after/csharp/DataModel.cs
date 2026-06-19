using System.Text.Json.Serialization;

namespace Lab1B;

public class CatalogItemData
{
    public decimal Price { get; set; }
    public string[] Tags { get; set; } = Array.Empty<string>();
}

public class CatalogItem
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string PartitionKey { get; set; } = string.Empty;
    public CatalogItemData Data { get; set; } = new();
}
