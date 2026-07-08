namespace Lab1E;

public class Customer
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string Name { get; set; }
}

public class Address
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string CustomerId { get; set; }
    public string Street { get; set; }
    public string City { get; set; }
    public string State { get; set; }
    public string ZipCode { get; set; }
}

public class Product
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string Name { get; set; }
    public decimal Price { get; set; }
    public string CategoryId { get; set; }
}

public class ProductCategory
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string Category { get; set; }
}

public class Order
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string CustomerId { get; set; }
    public string AddressId { get; set; }
    public DateTime OrderDate { get; set; }
    public decimal TotalAmount { get; set; }
}

public class OrderItem
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string OrderId { get; set; }
    public string ProductId { get; set; }
    public int Quantity { get; set; }
    public decimal LineTotal { get; set; }
}
