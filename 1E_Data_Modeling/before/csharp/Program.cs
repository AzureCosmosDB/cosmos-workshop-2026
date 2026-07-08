// Lab 1E: Data Modeling

using Lab1E;

var steps = new Steps_Data_Modeling();

Console.WriteLine("\n========== STEP 0: Initialize and seed reference + embed databases ==========");
await steps.Init();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Fetch a complete order — REFERENCE model ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Fetch a complete order — EMBED model ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Update a customer address — model tradeoffs ==========");
await steps.Step3();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: Designing by usage patterns ==========");
await steps.Step4();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: Hot-partition seed (provisioned account) ==========");
await steps.Step5();
Console.WriteLine("\n--- Press Enter to continue to Step 6 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 6: Composite key — inspect and re-seed ==========");
await steps.Step6();
Console.WriteLine("\n--- Press Enter to continue to Step 7 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 7: Compare RU distribution in the portal ==========");
await steps.Step7();
