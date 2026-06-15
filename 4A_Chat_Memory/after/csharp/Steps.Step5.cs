namespace Lab4A;

public partial class Steps
{
    public async Task Step5()
    {
        Console.WriteLine($"Chatting in session {SessionId}");
        Console.WriteLine("Enter a question, or blank line / 'quit' / 'exit' to end.");
        Console.WriteLine();

        while (true)
        {
            Console.Write("You: ");
            var userMessage = Console.ReadLine()?.Trim();
            if (string.IsNullOrEmpty(userMessage) ||
                userMessage.Equals("quit", StringComparison.OrdinalIgnoreCase) ||
                userMessage.Equals("exit", StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine("(session ended)");
                break;
            }

            var answer = await ChatAgent(SessionId, userMessage);
            Console.WriteLine();
            Console.WriteLine($"Assistant: {answer}");
            Console.WriteLine();
        }

        var finalHistory = await GetRecentMessages(SessionId, 20);
        finalHistory.Reverse();
        Console.WriteLine($"Total messages in session '{SessionId}': {finalHistory.Count}\n");

        foreach (var msg in finalHistory)
        {
            string roleMarker = msg.Role == MessageRole.User ? "🧑 User" : "🤖 Assistant";
            Console.WriteLine($"{roleMarker}: {msg.Content}");
        }

        Console.WriteLine("\n=== COMPLETE ===");
    }
}
