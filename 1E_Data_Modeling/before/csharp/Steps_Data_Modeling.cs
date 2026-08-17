// Lab 1E: Data Modeling - Consolidated Steps (STUDENT VERSION)

#nullable enable
using System.Text.Json;
using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace Lab1E;

public class Steps_Data_Modeling
{
    #region State
    public string? Endpoint { get; private set; }
    public string? ProvisionedEndpoint { get; private set; }
    public CosmosClient? Client { get; private set; }
    public Database? RefDB { get; private set; }
    public Database? EmbedDB { get; private set; }
    public CosmosClient? ProvisionedClient { get; private set; }
    public Database? ProvisionedDB { get; private set; }

    public const string RefDbName = "ModelingReference";
    public const string EmbedDbName = "ModelingEmbed";
    public const string ProvisionedDbName = "Modeling";

    private const string HotContainerName = "OrdersHot";
    private const string CompositeContainerName = "OrdersComposite";

    private const string PkValue = "default";
    private static readonly PartitionKey Pk = new(PkValue);

    public bool Seeded { get; private set; }
    public bool ReferenceFetchRan { get; private set; }
    public bool EmbedFetchRan { get; private set; }
    public bool AddressUpdateRan { get; private set; }
    public bool UsagePatternsRan { get; private set; }
    public bool HotSeeded { get; private set; }
    public bool CompositeVerified { get; private set; }
    public bool CompositeSeeded { get; private set; }

    private static CosmosClient CreateClient(string endpoint)
    {
        var credential = new AzureCliCredential();
        return new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private static async Task<JsonElement> LoadSeed(string fileName)
    {
        var path = Path.Combine(AppContext.BaseDirectory, fileName);
        await using var stream = File.OpenRead(path);
        var doc = await JsonDocument.ParseAsync(stream);
        return doc.RootElement.Clone();
    }

    private static List<T> Section<T>(JsonElement root, string name) =>
        root.GetProperty(name).Deserialize<List<T>>(JsonOpts)
            ?? throw new InvalidOperationException($"Failed to deserialize section '{name}'");
    #endregion

    #region Init
    public async Task Init()
    {
        Console.WriteLine("\n=== Step 0: Setup — Seed Reference and Embed Databases ===\n");

        var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required (see SetEnv.ps1).");

        Client = CreateClient(endpoint);
        Endpoint = endpoint;
        RefDB = Client.GetDatabase(RefDbName);
        EmbedDB = Client.GetDatabase(EmbedDbName);

        Console.WriteLine($"  serverless endpoint: {endpoint}");
        Console.WriteLine($"  reference DB:        {RefDbName}");
        Console.WriteLine($"  embed DB:            {EmbedDbName}\n");

        await SeedReference();
        await SeedEmbed();

        Seeded = true;
    }

    private async Task SeedReference()
    {
        Console.WriteLine($"Seeding '{RefDbName}' (one container per entity) ...");
        var root = await LoadSeed("seed-reference.json");
        await UpsertAll(RefDB!.GetContainer("Customers"),         Section<Customer>(root, "customers"),         c => c.Id);
        await UpsertAll(RefDB!.GetContainer("Addresses"),         Section<Address>(root, "addresses"),          a => a.Id);
        await UpsertAll(RefDB!.GetContainer("ProductCategories"), Section<ProductCategory>(root, "productCategories"), c => c.Id);
        await UpsertAll(RefDB!.GetContainer("Products"),          Section<Product>(root, "products"),           p => p.Id);
        await UpsertAll(RefDB!.GetContainer("Orders"),            Section<Order>(root, "orders"),               o => o.Id);
        await UpsertAll(RefDB!.GetContainer("OrderItems"),        Section<OrderItem>(root, "orderItems"),       i => i.Id);
    }

    private async Task SeedEmbed()
    {
        Console.WriteLine($"Seeding '{EmbedDbName}' (denormalized — addresses on customer, lines on order) ...");
        var root = await LoadSeed("seed-embed.json");
        await UpsertAll(EmbedDB!.GetContainer("Customers"), Section<CustomerDocument>(root, "customers"), c => c.Id);
        await UpsertAll(EmbedDB!.GetContainer("Products"),  Section<ProductDocument>(root, "products"),   p => p.Id);

        var ordersContainer = EmbedDB!.GetContainer("Orders");
        foreach (var doc in root.GetProperty("orders").EnumerateArray())
        {
            var docType = doc.GetProperty("docType").GetString();
            var id = doc.GetProperty("id").GetString();
            if (docType == "order")
            {
                var order = doc.Deserialize<OrderDocument>(JsonOpts)!;
                await ordersContainer.UpsertItemAsync(order, Pk);
            }
            else
            {
                var invoice = doc.Deserialize<ServiceInvoice>(JsonOpts)!;
                await ordersContainer.UpsertItemAsync(invoice, Pk);
            }
            Console.WriteLine($"    upserted Orders/{id} ({docType})");
        }
    }

    private static async Task UpsertAll<T>(Container container, IEnumerable<T> items, Func<T, string> idSelector)
    {
        int count = 0;
        foreach (var item in items)
        {
            await container.UpsertItemAsync(item, Pk);
            Console.WriteLine($"    upserted {container.Id}/{idSelector(item)}");
            count++;
        }
        Console.WriteLine($"  -> {count} docs in {container.Id}");
    }
    #endregion

    #region Step 1 — Reference model: assemble a complete order
    public async Task Step1()
    {
        if (RefDB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 1: Fetch a Complete Order — REFERENCE Model ===\n");
        Console.WriteLine("Walking references across six containers; each hop is its own round-trip.\n");

        const string targetOrderId = "order_001";
        double totalRu = 0;
        int roundTrips = 0;

        var orders = RefDB.GetContainer("Orders");
        var orderItems = RefDB.GetContainer("OrderItems");
        var products = RefDB.GetContainer("Products");
        var categories = RefDB.GetContainer("ProductCategories");
        var customers = RefDB.GetContainer("Customers");
        var addresses = RefDB.GetContainer("Addresses");

        var orderResp = await orders.ReadItemAsync<Order>(targetOrderId, Pk);
        roundTrips++; totalRu += orderResp.RequestCharge;
        var order = orderResp.Resource;
        Console.WriteLine($"  [1] Read Orders/{order.Id}                              {orderResp.RequestCharge,5:F2} RU");

        var itemsQuery = new QueryDefinition("SELECT * FROM c WHERE c.orderId = @orderId").WithParameter("@orderId", order.Id);
        var items = new List<OrderItem>();
        using (var iter = orderItems.GetItemQueryIterator<OrderItem>(itemsQuery, requestOptions: new QueryRequestOptions { PartitionKey = Pk }))
        {
            while (iter.HasMoreResults)
            {
                var batch = await iter.ReadNextAsync();
                roundTrips++; totalRu += batch.RequestCharge;
                items.AddRange(batch);
                Console.WriteLine($"  [2] Query OrderItems WHERE orderId='{order.Id}'    {batch.RequestCharge,5:F2} RU ({batch.Count} rows)");
            }
        }

        foreach (var item in items)
        {
            var prodResp = await products.ReadItemAsync<Product>(item.ProductId, Pk);
            roundTrips++; totalRu += prodResp.RequestCharge;
            var product = prodResp.Resource;
            Console.WriteLine($"  [3] Read Products/{item.ProductId}                          {prodResp.RequestCharge,5:F2} RU  ({product.Name})");

            var catResp = await categories.ReadItemAsync<ProductCategory>(product.CategoryId, Pk);
            roundTrips++; totalRu += catResp.RequestCharge;
            Console.WriteLine($"  [4] Read ProductCategories/{product.CategoryId}              {catResp.RequestCharge,5:F2} RU  ({catResp.Resource.Category})");
        }

        var custResp = await customers.ReadItemAsync<Customer>(order.CustomerId, Pk);
        roundTrips++; totalRu += custResp.RequestCharge;
        Console.WriteLine($"  [5] Read Customers/{order.CustomerId}                         {custResp.RequestCharge,5:F2} RU  ({custResp.Resource.Name})");

        var addrResp = await addresses.ReadItemAsync<Address>(order.AddressId, Pk);
        roundTrips++; totalRu += addrResp.RequestCharge;
        var address = addrResp.Resource;
        Console.WriteLine($"  [6] Read Addresses/{order.AddressId}                          {addrResp.RequestCharge,5:F2} RU  ({address.Street}, {address.City})");

        Console.WriteLine();
        Console.WriteLine($"  Totals: {roundTrips} round-trips, {totalRu:F2} RU");

        ReferenceFetchRan = true;
    }
    #endregion

    #region Step 2 — Embed model: one read returns the whole order (STUDENT EXERCISE)
    public async Task Step2()
    {
        if (EmbedDB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 2: Fetch a Complete Order — EMBED Model (STUDENT EXERCISE) ===\n");
        Console.WriteLine("Customer snapshot and line items are already on the order doc — one point read returns everything.\n");

        const string targetOrderId = "order_001";
        var orders = EmbedDB.GetContainer("Orders");

        // STUDENT EXERCISE: replace the placeholder below with a single ReadItemAsync<OrderDocument>
        // call for targetOrderId in the embed Orders container. See Instructions.md Step 2.
        var resp = new { Resource = new OrderDocument { Id = "(placeholder)" }, RequestCharge = 0.0 };
        var order = resp.Resource;

        Console.WriteLine($"  Read Orders/{order.Id}                              {resp.RequestCharge,5:F2} RU");
        Console.WriteLine($"    customer:   {order.CustomerName} <{order.CustomerId}>");
        Console.WriteLine($"    ship to:    {order.CustomerStreet}, {order.CustomerCity}, {order.CustomerState} {order.CustomerZipCode}");
        Console.WriteLine($"    date/total: {order.Date:yyyy-MM-dd}   ${order.TotalAmount:F2}");
        Console.WriteLine($"    lines:");
        foreach (var line in order.Lines)
            Console.WriteLine($"      - {line.Quantity} x {line.ProductName,-22} ({line.ProductCategory,-12}) @ ${line.ProductPrice,6:F2} = ${line.LineTotal,7:F2}");

        Console.WriteLine();
        Console.WriteLine($"  Totals: 1 round-trip, {resp.RequestCharge:F2} RU");

        EmbedFetchRan = true;
    }
    #endregion

    #region Step 3 — Updating a customer address: write tradeoffs
    public async Task Step3()
    {
        if (RefDB is null || EmbedDB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 3: Update a Customer Address — Model Tradeoffs ===\n");
        Console.WriteLine("cust_001 moves: '100 Main St, Seattle WA' -> '555 New Lane, Bellevue WA'.\n");

        const string customerId = "cust_001";
        const string addressId = "addr_001";
        const string newStreet = "555 New Lane";
        const string newCity = "Bellevue";
        const string newState = "WA";
        const string newZip = "98004";

        Console.WriteLine("Reference model — update the single Addresses row; every order resolves it on next read.");
        var refAddresses = RefDB.GetContainer("Addresses");
        var refAddr = (await refAddresses.ReadItemAsync<Address>(addressId, Pk)).Resource;
        refAddr.Street = newStreet; refAddr.City = newCity; refAddr.State = newState; refAddr.ZipCode = newZip;
        var refReplace = await refAddresses.ReplaceItemAsync(refAddr, addressId, Pk);
        Console.WriteLine($"  Replaced Addresses/{addressId}    {refReplace.RequestCharge:F2} RU  (1 write)");

        Console.WriteLine("\nEmbed model — update the customer doc, but past orders still carry the old snapshotted address.");
        var embedCustomers = EmbedDB.GetContainer("Customers");
        var embedOrders = EmbedDB.GetContainer("Orders");

        var cust = (await embedCustomers.ReadItemAsync<CustomerDocument>(customerId, Pk)).Resource;
        var addr = cust.Addresses[0];
        addr.Street = newStreet; addr.City = newCity; addr.State = newState; addr.ZipCode = newZip;
        var custReplace = await embedCustomers.ReplaceItemAsync(cust, customerId, Pk);
        Console.WriteLine($"  Replaced Customers/{customerId}    {custReplace.RequestCharge:F2} RU");

        var staleOrder = (await embedOrders.ReadItemAsync<OrderDocument>("order_001", Pk)).Resource;
        Console.WriteLine($"  order_001 ship-to (still snapshotted): {staleOrder.CustomerStreet}, {staleOrder.CustomerCity}");

        Console.WriteLine("\nFanning out the update — query affected orders, replace each one (the change-feed pattern, inline).");
        var query = new QueryDefinition(
            "SELECT * FROM c WHERE c.docType = 'order' AND c.customerId = @custId"
        ).WithParameter("@custId", customerId);

        double fanOutRu = 0; int updated = 0;
        using (var iter = embedOrders.GetItemQueryIterator<OrderDocument>(query, requestOptions: new QueryRequestOptions { PartitionKey = Pk }))
        {
            while (iter.HasMoreResults)
            {
                var batch = await iter.ReadNextAsync();
                fanOutRu += batch.RequestCharge;
                foreach (var ord in batch)
                {
                    ord.CustomerStreet = newStreet;
                    ord.CustomerCity = newCity;
                    ord.CustomerState = newState;
                    ord.CustomerZipCode = newZip;
                    var r = await embedOrders.ReplaceItemAsync(ord, ord.Id, Pk);
                    fanOutRu += r.RequestCharge;
                    updated++;
                }
            }
        }
        Console.WriteLine($"  Fan-out replaced {updated} order doc(s)    {fanOutRu:F2} RU");

        AddressUpdateRan = true;
    }
    #endregion

    #region Step 4 — Designing by usage patterns: orders by customer name (STUDENT EXERCISE)
    public async Task Step4()
    {
        if (EmbedDB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 4: Designing by Usage Patterns — Orders by Customer Name (STUDENT EXERCISE) ===\n");
        Console.WriteLine("The snapshotted customerName on each order doc makes this a single-container query, no join.\n");

        var orders = EmbedDB.GetContainer("Orders");
        const string customerName = "Alice Anderson";

        // STUDENT EXERCISE: replace the placeholder below with a parameterized query
        // that returns order docs (docType='order') where c.customerName = @name.
        // See Instructions.md Step 4.
        var query = new QueryDefinition(
            "SELECT '(placeholder)' AS id, '(placeholder)' AS date, 0 AS totalAmount"
        ).WithParameter("@name", customerName);

        double ru = 0; int rows = 0;
        using var iter = orders.GetItemQueryIterator<OrderDocument>(query, requestOptions: new QueryRequestOptions { PartitionKey = Pk });
        while (iter.HasMoreResults)
        {
            var batch = await iter.ReadNextAsync();
            ru += batch.RequestCharge;
            foreach (var o in batch)
            {
                rows++;
                Console.WriteLine($"  - {o.Id} on {o.Date:yyyy-MM-dd}   ${o.TotalAmount:F2}");
            }
        }

        Console.WriteLine();
        Console.WriteLine($"  {rows} order(s) for '{customerName}', {ru:F2} RU");

        UsagePatternsRan = true;
    }
    #endregion

    #region Provisioned account helpers (Steps 5–7)
    private void EnsureProvisionedClient()
    {
        if (ProvisionedClient is not null) return;

        var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT_PROVISIONED")
            ?? throw new InvalidOperationException(
                "Steps 5–7 require the provisioned-throughput account. Set COSMOS_ENDPOINT_PROVISIONED " +
                "(see SetEnv.ps1) — Azure Monitor needs per-partition RU metrics that serverless doesn't expose.");

        ProvisionedClient = CreateClient(endpoint);
        ProvisionedEndpoint = endpoint;
        ProvisionedDB = ProvisionedClient.GetDatabase(ProvisionedDbName);
        Console.WriteLine($"  provisioned endpoint: {endpoint}");
        Console.WriteLine($"  modeling DB:          {ProvisionedDbName}\n");
    }

    private const int PartitionDemoCount = 100;

    private record HotOrder(string Id, string CustomerId, string OrderDate, double Total);
    private record CompositeOrder(string Id, string CustomerId, string OrderDate, string PartitionKey, double Total);

    private static async Task<List<string>> GetDistinctPartitionKeyValues(Container container, string field)
    {
        var query = new QueryDefinition($"SELECT DISTINCT VALUE {field} FROM c");
        var values = new List<string>();
        using var iter = container.GetItemQueryIterator<string>(query);
        while (iter.HasMoreResults)
        {
            var batch = await iter.ReadNextAsync();
            values.AddRange(batch);
        }
        return values;
    }
    #endregion

    #region Step 5 — Hot-partition seed
    public async Task Step5()
    {
        Console.WriteLine($"\n=== Step 5: Hot Partition Seed into '{HotContainerName}' ===\n");
        Console.WriteLine("Partitioning by date is a classic anti-pattern: every write 'today' lands on one partition.\n");
        EnsureProvisionedClient();

        var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
        var container = ProvisionedDB!.GetContainer(HotContainerName);
        var hotPk = new PartitionKey(today);

        for (int i = 0; i < PartitionDemoCount; i++)
        {
            var order = new HotOrder($"order_{i}", $"CUST_{(i % 50):D3}", today, Math.Round(10 + (i * 3.33), 2));
            await container.UpsertItemAsync(order, hotPk);
        }

        var distinct = await GetDistinctPartitionKeyValues(container, "c.orderDate");
        Console.WriteLine($"  Seeded {PartitionDemoCount} orders. Distinct /orderDate values across the container: {distinct.Count}");
        foreach (var v in distinct) Console.WriteLine($"    - {v}");

        HotSeeded = true;
    }
    #endregion

    #region Step 6 — Composite-key container and reseed (STUDENT EXERCISE)
    public async Task Step6()
    {
        Console.WriteLine($"\n=== Step 6: Composite Partition Key Seed into '{CompositeContainerName}' (STUDENT EXERCISE) ===\n");
        Console.WriteLine("Same volume, same day — but customerId#date spreads writes across ~50 logical partitions.\n");
        EnsureProvisionedClient();

        var container = ProvisionedDB!.GetContainer(CompositeContainerName);
        var props = await container.ReadContainerAsync();
        CompositeVerified = props.Resource.PartitionKeyPaths.Contains("/partitionKey");
        Console.WriteLine($"  Container '{CompositeContainerName}' partition key paths: {string.Join(", ", props.Resource.PartitionKeyPaths)}");

        var today = DateTime.UtcNow.ToString("yyyy-MM-dd");

        for (int i = 0; i < PartitionDemoCount; i++)
        {
            var customerId = $"CUST_{(i % 50):D3}";

            // STUDENT EXERCISE: replace the placeholder below with a composite of customerId
            // and today so writes spread across ~50 logical partitions. See Instructions.md Step 6.
            var pk = "(placeholder)";

            var order = new CompositeOrder($"order_{i}", customerId, today, pk, Math.Round(10 + (i * 3.33), 2));
            await container.UpsertItemAsync(order, new PartitionKey(pk));
        }

        var distinct = await GetDistinctPartitionKeyValues(container, "c.partitionKey");
        Console.WriteLine($"  Seeded {PartitionDemoCount} orders. Distinct /partitionKey values across the container: {distinct.Count}");

        CompositeSeeded = true;
    }
    #endregion

    #region Step 7 — Distribution summary
    public Task Step7()
    {
        Console.WriteLine("\n=== Step 7: Partition Distribution Summary ===\n");
        Console.WriteLine($"  '{HotContainerName}':       1 distinct partition-key value — all writes pinned to today's date.");
        Console.WriteLine($"  '{CompositeContainerName}': ~50 distinct partition-key values — one per (customer, day).");
        Console.WriteLine();
        Console.WriteLine("At production scale (>10k RU/s with multiple physical partitions) this distribution shows up directly in Azure Monitor:");
        Console.WriteLine("  Cosmos DB > Monitoring > Insights > Throughput > 'Normalized RU Consumption (Max)' By PartitionKeyRangeId");
        Console.WriteLine("  - hot partitions spike one range while composite spreads across multiple ranges with lower max usage.");
        return Task.CompletedTask;
    }
    #endregion
}
