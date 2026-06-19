# Lab 2C: Completions + Embeddings in C#

**Time**: ~30 min  
**Environment**: .NET 10 terminal

In this exercise you will call Azure OpenAI chat completions (non-streaming and streaming) and the embeddings model, then compare two embeddings via cosine similarity.

The lab uses a single project in the `2C_Completions_Embeddings` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- Cosmos DB account endpoint
- Azure AI Foundry endpoint (chat completions, Entra ID auth)
- Azure OpenAI endpoint + key for embeddings (the v1 embeddings surface does not yet support Entra ID)
- Environment variables: `COSMOS_ENDPOINT`, `FOUNDRY_ENDPOINT`, `EMBEDDINGS_ENDPOINT`, `EMBEDDINGS_KEY`, `COMPLETIONS_MODEL` (optional), `EMBEDDINGS_MODEL` (optional)

## Run the lab

```bash
dotnet run
```

The program executes each step in order, pausing for **Enter** between steps.

## Student Exercises

Each step has a `// STUDENT EXERCISE` comment in `Steps_Completions_Embeddings.cs`. The surrounding setup, prints, and error handling are already in place — replace the placeholder line with the SDK call.

### Step 1: Chat Completions (STUDENT EXERCISE)

Replace the placeholder `completion` line in Step 1 with a real `CompleteChatAsync` call:

```csharp
var completion = await chatClient.CompleteChatAsync(messages1, completionsOptions);
```

**Expected output**: Chat response about Cosmos DB partitioning, plus prompt/completion token counts.

### Step 2: Streaming Response (STUDENT EXERCISE)

Replace the placeholder `Console.Write("(placeholder...")` line in Step 2 with a streaming loop:

```csharp
await foreach (var update in chatClient.CompleteChatStreamingAsync(messages2))
{
    foreach (var part in update.ContentUpdate)
        if (!string.IsNullOrEmpty(part.Text)) Console.Write(part.Text);
}
```

**Expected output**: Streaming text output about consistency levels, written one chunk at a time.

### Step 3: Generate Embeddings and Compare (STUDENT EXERCISE)

The `texts` list and cosine similarity comparison are pre-written. Replace the placeholder return in the `GetEmbedding` helper with a real embeddings call:

```csharp
var embeddingClient = EmbeddingsOpenAIClient.GetEmbeddingClient(EmbeddingsModel);
var embedding = embeddingClient.GenerateEmbedding(text);
return embedding.Value.ToFloats().ToArray();
```

**Expected output**: Three embedding dimensions printed, and a cosine similarity score between docs 1 and 3 noticeably higher than would be produced by zero vectors.

## Lab Complete!

You have completed the completions and embeddings exercise in C#. You:
- Called Azure OpenAI chat completions (non-streaming) and printed token usage
- Streamed a chat response chunk-by-chunk
- Generated embeddings for a small set of texts and compared them with cosine similarity

To run the lab again from scratch, run `dotnet run` again to walk through every step in sequence.
