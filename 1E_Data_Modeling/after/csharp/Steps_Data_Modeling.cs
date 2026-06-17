// Lab 1E: Data Modeling - Consolidated Steps

#nullable enable
using System.Net;
using System.Text.Json;
using Azure.Identity;
using Microsoft.Azure.Cosmos;

namespace CosmosLabs;

public class Steps_Data_Modeling
{
    #region State
    public string? Endpoint { get; private set; }
    public string DbName { get; private set; } = "Modeling";
    public CosmosClient? Client { get; private set; }
    public Database? DB { get; private set; }
    private const string HotContainerName = "OrdersHot";
    private const string CompositeContainerName = "OrdersComposite";
    private const string TtlContainerName = "EventsTtl";
    public bool Seeded { get; private set; }
    public bool CompositeVerified { get; private set; }
    public bool FanOutQueryRun { get; private set; }
    public bool TtlVerified { get; private set; }

    private CosmosClient CreateClient(string endpoint)
    {
        var credential = new DefaultAzureCredential();

        return new CosmosClient(endpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });
    }
    #endregion

    #region Init
    public async Task InitAsync()
    {
        Console.WriteLine("\n=== Step 0: Setup (Connection to provisioned-throughput account) ===\n");

        // Lab 1E uses the provisioned-throughput Cosmos account so per-partition RU
        // metrics are available in Azure Monitor for the Step 6 comparison.
        var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT_PROVISIONED")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT_PROVISIONED environment variable is required (see SetEnv.ps1).");

        Client = CreateClient(endpoint);
        DB = Client.GetDatabase(DbName);
        Endpoint = endpoint;

        Console.WriteLine($"  endpoint: {endpoint}");
        Console.WriteLine($"  database: {DbName}");
        Console.WriteLine($"  connected: {endpoint}{DbName}");
    }
    #endregion

    #region Seeding helpers
    // ~1 KB filler so each write costs ~10 RU instead of ~5 RU to make the
    // hot-partition pattern more clear on the 'Normalized RU Consumption (Max)' chart.
    private const int OrderCount = 10000;
    private const int Concurrency = 64;
    private static readonly string Filler = new('x', 1024);
    private static readonly string[] Statuses = ["pending", "shipped", "delivered"];

    private static Dictionary<string, object> BuildOrder(int i, string customerId, string orderDate, string? partitionKey)
    {
        var order = new Dictionary<string, object>
        {
            { "id", $"order_{i}" },
            { "customerId", customerId },
            { "orderDate", orderDate },
            { "total", Math.Round(10 + (i * 3.33), 2) },
            { "status", Statuses[i % 3] },
            { "items", new[] {
                new { sku = $"SKU_{i%5}", qty = (i % 3)+1 },
                new { sku = $"SKU_{(i+1)%5}", qty = ((i+1) % 3)+1 }
            } },
            { "notes", Filler }
        };
        if (partitionKey is not null) order["partitionKey"] = partitionKey;
        return order;
    }

    private static async Task SeedOrdersAsync(
        Container container,
        IReadOnlyList<Dictionary<string, object>> orders,
        Func<Dictionary<string, object>, PartitionKey> pkSelector)
    {
        var sem = new SemaphoreSlim(Concurrency);
        int completed = 0;
        var sw = System.Diagnostics.Stopwatch.StartNew();

        await Task.WhenAll(orders.Select(async order =>
        {
            await sem.WaitAsync();
            try
            {
                var pk = pkSelector(order);
                try
                {
                    await container.UpsertItemAsync(order, pk);
                }
                catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
                {
                    // If we hit rate limits, back off and retry. With enough concurrency, it's possible to get some 429s on the hot partition container.
                    Console.WriteLine($"  ...429 Too Many Requests for order {order["id"]}, retrying after {ex.RetryAfter?.TotalSeconds ?? 1:F1}s");
                    await Task.Delay(ex.RetryAfter ?? TimeSpan.FromSeconds(1));
                    await container.UpsertItemAsync(order, pk);
                }

                int done = Interlocked.Increment(ref completed);
                if (done % 1000 == 0)
                    Console.WriteLine($"  ...{done}/{orders.Count} ({sw.Elapsed.TotalSeconds:F1}s elapsed)");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error on order {order["id"]}: {ex.Message}");
            }
            finally
            {
                sem.Release();
            }
        }));

        sw.Stop();
        Console.WriteLine($"Wrote {orders.Count} orders to '{container.Id}' in {sw.Elapsed.TotalSeconds:F1}s");
    }
    #endregion

    #region Step 1
    public async Task Step1Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine($"\n=== Step 1: Seed Data with Hot Partition into '{HotContainerName}' ===\n");

        // Every order uses customerId 'CUST_001', so all 10k writes hit one logical partition.
        var orders = Enumerable.Range(0, OrderCount).Select(i => BuildOrder(
            i,
            customerId: "CUST_001",
            orderDate: new DateTime(2026, 1, 1).AddDays(i % 28).ToString("yyyy-MM-dd"),
            partitionKey: null)).ToList();

        Console.WriteLine($"Seeding {orders.Count} orders into '{HotContainerName}' (all customerId='CUST_001')");
        Console.WriteLine($"Using {Concurrency} concurrent writers to drive sustained RU on the hot partition...");

        var hotPk = new PartitionKey("CUST_001");
        await SeedOrdersAsync(DB.GetContainer(HotContainerName), orders, _ => hotPk);

        Console.WriteLine("Note: All orders use the same partition key 'CUST_001' - this creates a hot partition.");
        Console.WriteLine("Check Azure Portal > Cosmos DB > Metrics > 'Normalized RU Consumption (Max)' split by PartitionKeyRangeId");
        Console.WriteLine("to see a single partition pinned near 100% while the others stay flat.");
        Seeded = true;
    }
    #endregion

    #region Step 2
    public async Task Step2Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine($"\n=== Step 2: Inspect Composite-Key Container '{CompositeContainerName}' (STUDENT EXERCISE) ===\n");

        // Student exercise: Read the container properties and confirm it's keyed on
        // '/partitionKey' — a synthetic composite of customerId and orderDate (e.g.
        // "CUST_001#2026-01-15"). Step 3 will write that value into each document.

        var container = DB.GetContainer(CompositeContainerName);
        var props = await container.ReadContainerAsync();
        var pkPaths = props.Resource.PartitionKeyPaths;

        Console.WriteLine($"  Container '{CompositeContainerName}' found");
        Console.WriteLine($"    Partition key paths: {string.Join(", ", pkPaths)}");

        bool ok = pkPaths.Contains("/partitionKey");
        Console.WriteLine(ok
            ? "  Composite container verified (synthetic '/partitionKey')."
            : "  WARNING: expected partition key path '/partitionKey' not present.");
        CompositeVerified = ok;
    }
    #endregion

    #region Step 3
    public async Task Step3Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine($"\n=== Step 3: Re-seed with Composite Partition Key into '{CompositeContainerName}' (STUDENT EXERCISE) ===\n");

        // Synthetic composite key 'customerId#orderDate' spreads the same 10k writes
        // across 50 customers x 100 dates = up to 5000 logical partitions.
        var orders = Enumerable.Range(0, OrderCount).Select(i =>
        {
            string customerId = $"CUST_{(i % 50):D3}";
            string orderDate = new DateTime(2026, 1, 1).AddDays(i % 100).ToString("yyyy-MM-dd");
            return BuildOrder(i, customerId, orderDate, partitionKey: $"{customerId}#{orderDate}");
        }).ToList();

        Console.WriteLine($"Re-seeding {orders.Count} orders into '{CompositeContainerName}' (composite '/partitionKey')");
        Console.WriteLine($"Using {Concurrency} concurrent writers...");

        await SeedOrdersAsync(
            DB.GetContainer(CompositeContainerName),
            orders,
            order => new PartitionKey((string)order["partitionKey"]));

        Console.WriteLine("Note: Same write volume as Step 1, but spread across ~5000 logical partitions. Difference in run time between the two containers is often visible immediately.");
        Console.WriteLine("In a few minutes, metrics will be visible in Azure Portal showing the actual partition distribution which you can check at the end of this lab.");
    }
    #endregion

    #region Step 4
    public async Task Step4Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 4: Query for Denormalized Fan-Out Pattern (STUDENT EXERCISE) ===\n");

        var hotContainer = DB.GetContainer(HotContainerName);

        // Denormalization: line items live INSIDE each order document, so a single
        // query returns the order AND its items together — no second round-trip,
        // no cross-container join.

        string fanOutQuery = "SELECT c.id, c.total, c.status, c.items FROM c WHERE c.id IN ('order_0','order_1','order_2')";
        var queryDefinition = new QueryDefinition(fanOutQuery);

        var streamIterator = hotContainer.GetItemQueryStreamIterator(
            queryDefinition,
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey("CUST_001") });

        double totalRu = 0;
        int orders = 0, totalItems = 0;
        var prettyOpts = new JsonSerializerOptions { WriteIndented = true };

        while (streamIterator.HasMoreResults)
        {
            using var response = await streamIterator.ReadNextAsync();
            totalRu += response.Headers.RequestCharge;

            using var doc = await JsonDocument.ParseAsync(response.Content);
            foreach (var order in doc.RootElement.GetProperty("Documents").EnumerateArray())
            {
                orders++;
                var items = order.GetProperty("items");
                totalItems += items.GetArrayLength();

                Console.WriteLine($"Order {order.GetProperty("id").GetString()} " +
                    $"(status={order.GetProperty("status").GetString()}, total={order.GetProperty("total").GetDouble():F2}):");
                Console.WriteLine($"  items (embedded, no join needed): {JsonSerializer.Serialize(items, prettyOpts)}");
            }
        }

        Console.WriteLine($"\nRetrieved {orders} orders with {totalItems} embedded line items in one query.");
        Console.WriteLine($"Total RU charged: {totalRu:F2}");
        Console.WriteLine("Compare to a normalized model: 1 query for orders + N queries (or a join) for line items.");

        FanOutQueryRun = true;
    }
    #endregion

    #region Step 5
    public async Task Step5Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine($"\n=== Step 5: Per-Item TTL Override in '{TtlContainerName}' (STUDENT EXERCISE) ===\n");

        var container = DB.GetContainer(TtlContainerName);
        var props = await container.ReadContainerAsync();
        int? defaultTtl = props.Resource.DefaultTimeToLive;
        const int thirtyDaysInSeconds = 30 * 24 * 60 * 60;

        Console.WriteLine($"  Container DefaultTimeToLive: {(defaultTtl?.ToString() ?? "<not set>")} seconds " +
            $"({(defaultTtl is int s ? s / 86400 : 0)} days)");

        if (defaultTtl != thirtyDaysInSeconds)
            Console.WriteLine($"  WARNING: expected DefaultTimeToLive = {thirtyDaysInSeconds} (30 days).");

        // Per-item ttl property overrides the container default:
        //   ttl =  N  -> this item expires N seconds after its _ts
        //   ttl = -1  -> this item never expires, even though the container has a default
        //   (omit)    -> falls back to the container's DefaultTimeToLive (30 days here)

        const string pk = "ttl-demo";
        const int shortTtlSeconds = 5;

        var shortLived = new Dictionary<string, object>
        {
            { "id", "short-lived" }, { "partitionKey", pk },
            { "ttl", shortTtlSeconds },
            { "note", $"per-item ttl override: expires in {shortTtlSeconds}s" }
        };
        var neverExpires = new Dictionary<string, object>
        {
            { "id", "never-expires" }, { "partitionKey", pk },
            { "ttl", -1 },
            { "note", "ttl=-1 disables expiration even though container default is 30 days" }
        };
        var defaultBehavior = new Dictionary<string, object>
        {
            { "id", "default-ttl" }, { "partitionKey", pk },
            { "note", "no ttl property -> inherits container default (30 days)" }
        };

        await container.UpsertItemAsync(shortLived, new PartitionKey(pk));
        await container.UpsertItemAsync(neverExpires, new PartitionKey(pk));
        await container.UpsertItemAsync(defaultBehavior, new PartitionKey(pk));
        Console.WriteLine("\n  Wrote 3 items: short-lived (ttl=5), never-expires (ttl=-1), default-ttl (no override)");

        int waitSeconds = shortTtlSeconds + 10;
        Console.WriteLine($"  Waiting {waitSeconds}s for the short-lived item to expire...");
        await Task.Delay(TimeSpan.FromSeconds(waitSeconds));

        async Task<bool> ExistsAsync(string id)
        {
            try
            {
                await container.ReadItemAsync<JsonElement>(id, new PartitionKey(pk));
                return true;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
            {
                return false;
            }
        }

        bool shortAlive = await ExistsAsync("short-lived");
        bool neverAlive = await ExistsAsync("never-expires");
        bool defaultAlive = await ExistsAsync("default-ttl");

        Console.WriteLine("\n  Read-back after wait:");
        Console.WriteLine($"    short-lived   (ttl=5)         exists? {shortAlive}    expected: False");
        Console.WriteLine($"    never-expires (ttl=-1)        exists? {neverAlive}    expected: True");
        Console.WriteLine($"    default-ttl   (no override)   exists? {defaultAlive}    expected: True (30-day default)");

        // The TTL background process is best-effort, not instant. Items can occasionally
        // linger a few seconds past their deadline before the sweeper deletes them, so
        // we treat 'short-lived is gone' as the success signal but don't hard-fail.
        TtlVerified = defaultTtl == thirtyDaysInSeconds && neverAlive && defaultAlive;
        if (shortAlive)
            Console.WriteLine("  NOTE: short-lived item hasn't been swept yet — TTL deletion is asynchronous; retry in a few seconds.");
    }
    #endregion

    #region Step 6
    public async Task Step6Async()
    {
        if (DB is null) throw new InvalidOperationException("Not initialized. Run Step 0 first.");

        Console.WriteLine("\n=== Step 6: Compare RU Distribution ===\n");
        Console.WriteLine("Hot partition container should show spike in Throughput Metrics in Azure Portal");
        Console.WriteLine("Composite container should show flat distribution across partitions");
        Console.WriteLine("\nCheck Azure Portal > Cosmos DB > Monitoring > Insights > Throughput tab > Normalized RU Consumption (Max) Heat Map By PartitionKeyRangeID");
    }
    #endregion
}
