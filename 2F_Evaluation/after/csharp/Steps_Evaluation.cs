// Lab 2F: Evaluation - Consolidated Steps

#nullable enable
using System.Text.Json;
using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using OpenAI.Chat;

namespace Lab2F;

public class Steps_Evaluation
{
    #region State
    public string? Endpoint { get; private set; }
    public string DbName { get; private set; } = "WorkshopData";
    public string ContainerName { get; private set; } = "Docs";
    public CosmosClient? CosmosClient { get; private set; }
    public Database? DB { get; private set; }
    public Container? Container { get; private set; }
    public AzureOpenAIClient? OpenAIClient { get; private set; }
    public string? FoundryEndpoint { get; private set; }
    public string? CompletionsModel { get; private set; }
    public string? EvalModel { get; private set; }

    public List<int> ConsoleOutput { get; private set; } = new();

    private static readonly List<Dictionary<string, string>> EvalDataset = new()
    {
        new Dictionary<string, string> {
            { "question", "What is Azure Cosmos DB?" },
            { "ground_truth", "Azure Cosmos DB is a globally distributed, multi-model database service from Microsoft." }
        },
        new Dictionary<string, string> {
            { "question", "What types of indexes does Cosmos DB support?" },
            { "ground_truth", "Range, spatial, composite, vector, and full-text indexes." }
        },
        new Dictionary<string, string> {
            { "question", "How do vector indexes differ from range indexes?" },
            { "ground_truth", "Vector indexes enable semantic similarity search on embeddings, while range indexes optimize numeric/string equality and ordering queries." }
        }
    };
    #endregion

    #region Init
    public async Task Init()
    {
        Console.WriteLine("\n=== Step 0: Setup (Connection) ===\n");

        var cosmosEndpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
            ?? throw new InvalidOperationException("COSMOS_ENDPOINT environment variable is required.");
        var foundryEndpoint = Environment.GetEnvironmentVariable("FOUNDRY_ENDPOINT")
            ?? throw new InvalidOperationException("FOUNDRY_ENDPOINT environment variable is required.");

        var credential = new DefaultAzureCredential();

        CosmosClient = new CosmosClient(cosmosEndpoint, credential, new CosmosClientOptions
        {
            SerializerOptions = new CosmosSerializationOptions { PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase }
        });

        DB = CosmosClient.GetDatabase(DbName);
        Container = DB.GetContainer(ContainerName);
        Endpoint = cosmosEndpoint;

        OpenAIClient = new AzureOpenAIClient(new Uri(foundryEndpoint), credential);
        FoundryEndpoint = foundryEndpoint;

        CompletionsModel = Environment.GetEnvironmentVariable("COMPLETIONS_MODEL") ?? "gpt41";
        EvalModel = Environment.GetEnvironmentVariable("EVAL_MODEL") ?? CompletionsModel;

        Console.WriteLine($"  endpoint: {cosmosEndpoint}");
        Console.WriteLine($"  database: {DbName}");
        Console.WriteLine($"  container: {ContainerName}");
        Console.WriteLine($"  connected: {cosmosEndpoint}/{DbName}/{ContainerName}");
    }
    #endregion

    #region RAG Helper
    // Mock RAG: pull any 3 rows from the seeded 'rag' partition and hand them
    // to the chat model. The point of this lab is the LLM-as-judge scoring loop
    // below — real embedding + vector retrieval is covered in 2D and 2E.
    public async Task<string> GenerateResponse(string question)
    {
        if (Container is null) throw new InvalidOperationException("Container not initialized. Run Step 0 first.");
        if (OpenAIClient is null) throw new InvalidOperationException("OpenAIClient not initialized. Run Step 0 first.");

        var queryDefinition = new QueryDefinition(
            "SELECT TOP 3 c.text FROM c WHERE c.partitionKey = 'rag'");

        var iterator = Container.GetItemQueryIterator<Dictionary<string, object>>(
            queryDefinition,
            null,
            new QueryRequestOptions { PartitionKey = new PartitionKey("rag") }
        );

        var results = new List<Dictionary<string, object>>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        var context = string.Join("\n\n", results.Select(r => (string)r["text"]));
        var systemPrompt = $"You are a helpful assistant. Answer based on: {context}";

        var messages = new List<ChatMessage>
        {
            new SystemChatMessage(systemPrompt),
            new UserChatMessage(question)
        };

        var options = new ChatCompletionOptions
        {
            Temperature = 0.7f,
            MaxOutputTokenCount = 500
        };

        try
        {
            var chatClient = OpenAIClient.GetChatClient(CompletionsModel ?? "gpt41");
            var completion = await chatClient.CompleteChatAsync(messages, options);
            return completion.Value.Content[0].Text;
        }
        catch (Exception ex)
        {
            return $"Error: {ex.Message}";
        }
    }
    #endregion

    #region Step 1
    public void CreateEvalDataset()
    {
        Console.WriteLine("\n=== Step 1: Create evaluation dataset (Prebuilt) ===\n");

        Console.WriteLine($"Created {EvalDataset.Count} evaluation examples:");

        foreach (var example in EvalDataset)
        {
            Console.WriteLine($"  Q: {example["question"]}");
            Console.WriteLine($"  Ground truth: {example["ground_truth"]}\n");
        }
    }
    #endregion

    #region Step 2
    public async Task ScoreOutputs()
    {
        Console.WriteLine("\n=== Step 2: Score RAG outputs ===\n");

        Console.WriteLine("Scoring answers using LLM-as-judge pattern...\n");

        var scores = new List<int>();

        foreach (var example in EvalDataset)
        {
            var answer = await GenerateResponse(example["question"]);

            var scoringPrompt = $"Rate the answer's relevance to the question on a scale of 1 to 5.\n" +
                       $"Respond with ONLY a single digit (1, 2, 3, 4, or 5). No words, no punctuation, no explanation.\n\n" +
                       $"Question: {example["question"]}\n" +
                       $"Answer: {answer}\n" +
                       $"Ground truth: {example["ground_truth"]}\n\n" +
                       $"Score (single digit only):";

            var messages = new List<ChatMessage>
            {
                new UserChatMessage(scoringPrompt)
            };

            var scoringOptions = new ChatCompletionOptions
            {
                Temperature = 0.0f,
                MaxOutputTokenCount = 10
            };

            var evalChatClient = OpenAIClient?.GetChatClient(EvalModel ?? CompletionsModel ?? "gpt41");

            try
            {
                Console.WriteLine($"Q: {example["question"].Substring(0, Math.Min(40, example["question"].Length))}...");
                var completion = await evalChatClient!.CompleteChatAsync(messages, scoringOptions);
                Console.WriteLine($"  Evaluating Answer: {answer.Substring(0, Math.Min(60, answer.Length))}...");
                var scoreText = completion.Value.Content[0].Text.Trim();

                var match = System.Text.RegularExpressions.Regex.Match(scoreText, @"[1-5]");
                if (match.Success && int.TryParse(match.Value, out int score))
                {
                    scores.Add(score);
                    Console.WriteLine($"  Score: {score}/5");
                }
                else
                {
                    Console.WriteLine($"  Score text could not be parsed: {scoreText}");
                    scores.Add(0);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Error scoring: {ex.Message}");
                scores.Add(0);
            }
        }

        ConsoleOutput = scores;
    }
    #endregion

    #region Step 3
    public void SummarizeResults()
    {
        Console.WriteLine("\n=== Step 3: Summarize results ===");

        var scores = ConsoleOutput;

        if (scores.Count > 0)
        {
            var avg = (double)scores.Sum() / scores.Count;
            Console.WriteLine($"Average relevance score: {avg:F2}/5");
            Console.WriteLine("Recommendation: score >4 = good, 3-4 = needs improvement, <3 = redesign RAG pipeline");
        }

        Console.WriteLine("\n=== COMPLETE ===");
    }
    #endregion
}
