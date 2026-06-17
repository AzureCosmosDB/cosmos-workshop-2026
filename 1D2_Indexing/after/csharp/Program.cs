// Lab 1D2: Indexing Policy

using CosmosLabs;

var steps = new Steps_Indexing();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Step0Async();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Inspect default-indexing container ==========");
await steps.Step1Async();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Inspect custom-indexing container ==========");
await steps.Step2Async();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: RU comparison — largeBlob only ==========");
await steps.Step3Async();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: RU comparison — metadata only ==========");
await steps.Step4Async();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: RU comparison — combined ==========");
await steps.Step5Async();
Console.WriteLine("\n--- Lab complete ---\n");
