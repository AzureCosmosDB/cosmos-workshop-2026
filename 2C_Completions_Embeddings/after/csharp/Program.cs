// Lab 2C: Completions + Embeddings

using CosmosLabs;

var steps = new Steps_Completions_Embeddings();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.InitAsync();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Chat completions ==========");
await steps.Step1Async();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Streaming response ==========");
await steps.Step2Async();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Embeddings and cosine similarity ==========");
await steps.Step3Async();
