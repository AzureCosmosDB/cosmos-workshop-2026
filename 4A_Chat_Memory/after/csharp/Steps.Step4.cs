using System.Diagnostics;
using OpenAI.Chat;

namespace Lab4A;

public partial class Steps
{
    public async Task Step4()
    {
        var userMessage = "How does vector search work in Cosmos DB?";
        var answer = await ChatAgent(SessionId, userMessage);
        Console.WriteLine();
        Console.WriteLine($"Assistant: {answer}");
        Console.WriteLine();
    }

    private async Task<string> ChatAgent(string sid, string userMessage)
    {
        const string baseSystemPrompt = "You are a helpful assistant specializing in Azure Cosmos DB.";

        await SaveChatTurn(sid, MessageRole.User, userMessage);

        var context = await GetRecentMessages(sid, 10);
        var ordered = context.AsEnumerable().Reverse().ToList();
        var window = ordered.Skip(Math.Max(0, ordered.Count - 6));
        var history = string.Join("\n", window.Select(m => $"{m.Role}: {m.Content}"));

        var hits = await RetrieveRelevant(userMessage, topK: 3);
        var contextText = string.Join("\n\n", hits.Select(h => $"{h.Title}: {h.Text}"));

        var systemContent =
            $"{baseSystemPrompt}\n\n" +
            $"Use the following retrieved context to ground your answer:\n{contextText}\n\n" +
            $"Chat history:\n{history}";

        var messages = new List<ChatMessage>
        {
            ChatMessage.CreateSystemMessage(systemContent),
            ChatMessage.CreateUserMessage(userMessage)
        };

        var sw = Stopwatch.StartNew();
        var completion = await ChatClient.CompleteChatAsync(messages, new ChatCompletionOptions
        {
            Temperature = 0.7f,
            MaxOutputTokenCount = 500
        });
        sw.Stop();
        var latencyMs = (int)sw.ElapsedMilliseconds;

        var answer = completion.Value.Content[0].Text;
        var usage = completion.Value.Usage;

        var assistantMetadata = new ChatMessageMetadata
        {
            Model = ChatModel,
            LatencyMs = latencyMs,
            PromptTokens = usage?.InputTokenCount ?? 0,
            CompletionTokens = usage?.OutputTokenCount ?? 0,
            TotalTokens = usage?.TotalTokenCount ?? 0,
            RagHits = hits.Count,
            RetrievedDocIds = hits.Select(h => h.Id).ToArray()
        };
        await SaveChatTurn(sid, MessageRole.Assistant, answer, assistantMetadata);

        return answer;
    }
}
