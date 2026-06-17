// Lab 1D1: Query Language

using CosmosLabs.C1;

var steps = new Steps_Query_Language();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Init();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Verify connection ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Seed sample data ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Query for all fruits ==========");
await steps.Step3();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: Point read vs query cost ==========");
await steps.Step4();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: Parameterized query ==========");
await steps.Step5();
Console.WriteLine("\n--- Press Enter to continue to Step 6 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 6: JSON properties + system functions ==========");
await steps.Step6();
Console.WriteLine("\n--- Press Enter to continue to Step 7 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 7: Subquery over a nested array ==========");
await steps.Step7();
