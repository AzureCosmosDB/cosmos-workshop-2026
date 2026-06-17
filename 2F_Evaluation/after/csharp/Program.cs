// Lab 2F: Evaluation

using Lab2F;

var steps = new Steps_Evaluation();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Init();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Create evaluation dataset ==========");
steps.CreateEvalDataset();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Score RAG outputs ==========");
await steps.ScoreOutputs();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Summarize results ==========");
steps.SummarizeResults();
