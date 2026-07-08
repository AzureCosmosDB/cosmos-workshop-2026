// Lab 2D: Vector Search

using Lab2D;

var steps = new Steps_Vector_Search();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Step0();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Generate and store embeddings ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Vector similarity search ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Full-text search ==========");
await steps.Step3();
