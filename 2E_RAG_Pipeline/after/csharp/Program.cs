// Lab 2E: RAG Pipeline

using CosmosLabs;

var steps = new Steps_RAG_Pipeline();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.InitAsync();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Chunk source documents ==========");
await steps.Step1Async();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Embed and store chunks ==========");
await steps.Step2Async();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: RAG retrieval ==========");
await steps.Step3Async();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: RAG generation ==========");
await steps.Step4Async();
