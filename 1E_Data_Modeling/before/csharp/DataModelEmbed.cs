namespace Lab1E;

public class CustomerDocument
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string Name { get; set; }
    public List<CustomerAddress> Addresses { get; set; } = new();
}

public class CustomerAddress
{
    public string CustomerId { get; set; }
    public string Street { get; set; }
    public string City { get; set; }
    public string State { get; set; }
    public string ZipCode { get; set; }
}

public class ProductDocument
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string Name { get; set; }
    public decimal Price { get; set; }
    public string Category { get; set; }
}

public class OrderDocument
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string DocType { get; set; } = "order";
    public DateTime Date { get; set; }
    public decimal TotalAmount { get; set; }
    public string CustomerId { get; set; }
    public string CustomerName { get; set; }
    public string CustomerStreet { get; set; }
    public string CustomerCity { get; set; }
    public string CustomerState { get; set; }
    public string CustomerZipCode { get; set; }

    public List<OrderLine> Lines { get; set; } = new();
}

public class ServiceInvoice
{
    public string Id { get; set; }
    public string PartitionKey { get; set; } = "default";
    public string DocType { get; set; } = "invoice";
    public DateTime Date { get; set; }
    public decimal TotalAmount { get; set; }
    public string Description { get; set; }
}

public class OrderLine
{
    public string ProductId { get; set; }
    public string ProductName { get; set; }
    public decimal ProductPrice { get; set; }
    public string ProductCategory { get; set; }
    public int Quantity { get; set; }
    public decimal LineTotal { get; set; }
}
