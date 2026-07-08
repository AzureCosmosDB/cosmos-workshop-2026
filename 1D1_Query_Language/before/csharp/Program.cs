// Lab 1D1: Query Language

using Lab1D1;

var steps = new Steps_Query_Language();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Init();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Seed sample data ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Query for all fruits ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Point read vs query cost ==========");
await steps.Step3();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: Parameterized query ==========");
await steps.Step4();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: JSON properties + system functions ==========");
await steps.Step5();
Console.WriteLine("\n--- Press Enter to continue to Step 6 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 6: Subquery over a nested array ==========");
await steps.Step6();
