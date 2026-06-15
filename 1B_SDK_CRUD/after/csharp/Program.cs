// Lab 1B: SDK Basics / CRUD

using CosmosLabs;

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await Steps.InitAsync();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Create an item ==========");
await Steps.Step1Async();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Read the item ==========");
await Steps.Step2Async();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Upsert the item ==========");
await Steps.Step3Async();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: Delete the item ==========");
await Steps.Step4Async();
