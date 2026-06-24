# Lab 2F: Evaluation in C#

**Time**: ~20 min  
**Environment**: .NET 10 terminal

In this exercise you will evaluate a RAG pipeline using the LLM-as-judge pattern.

The lab uses a single project in the `2F_Evaluation` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

- .NET 10 SDK
- Environment variables: `COSMOS_ENDPOINT`, `FOUNDRY_ENDPOINT`, `COMPLETIONS_MODEL` (optional), `EVAL_MODEL` (optional)
- **Lab 2E must have already been run** in this Cosmos account. 2F's mock retrieval reads from the `WorkshopData.Docs` container with `partitionKey = 'rag'`, which is seeded by 2E. Without that data the judge has no context to score against.

This lab focuses on the LLM-as-judge scoring loop; retrieval is mocked with a plain Cosmos query, so no embeddings client is needed (real embedding + vector search is covered in Labs 2D and 2E).

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth.

## Run the lab

```bash
dotnet run
```

The program executes each step in order, pausing for **Enter** between steps.

### Step 0: Initialize Connection

Sets up the Cosmos client connection and Azure OpenAI client.

### Step 1: Create Evaluation Dataset (Prebuilt)

Prints the three Q/A test cases used to evaluate the RAG pipeline. The dataset is hard-coded in `Steps_Evaluation.cs` as `EvalDataset`.

### Step 2: Score RAG Outputs (STUDENT EXERCISE)

The retrieval call, the chat-judge call, the score parser, and the result aggregation are all already wired up. Your job is to write the **judge prompt** that drives the LLM-as-judge pattern — this is what turns a language model into an evaluator.

Replace the placeholder `scoringPrompt` string in `Steps_Evaluation.cs` Step 2 with:

```csharp
var scoringPrompt = $"Rate the answer's relevance to the question on a scale of 1 to 5.\n" +
           $"Respond with ONLY a single digit (1, 2, 3, 4, or 5). No words, no punctuation, no explanation.\n\n" +
           $"Question: {example["question"]}\n" +
           $"Answer: {answer}\n" +
           $"Ground truth: {example["ground_truth"]}\n\n" +
           $"Score (single digit only):";
```

**Expected output**: A 1–5 relevance score printed per question. With the placeholder prompt, the parser will fall through to `Score text could not be parsed` because the model is told to respond with `0`, which is outside the 1–5 range — that's the signal that the placeholder hasn't been replaced.

### Step 3: Summarize Results (Prebuilt)

Averages the scores collected in Step 2 and prints a recommendation thresholded against >4 (good), 3-4 (needs work), <3 (redesign).

## Lab Complete!

You have completed the evaluation exercise in C#. You:
- Saw how a fixed eval dataset drives the loop
- Wrote the LLM-as-judge prompt that scores answers against ground truth
- Saw aggregated scores summarized into a recommendation
