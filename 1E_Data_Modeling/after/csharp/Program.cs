// Lab 1E: Data Modeling

using Lab1E;

var steps = new Steps_Data_Modeling();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Init();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Seed data with hot partition ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Inspect composite-key container ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: Re-seed with composite partition key ==========");
await steps.Step3();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: Query denormalized fan-out ==========");
await steps.Step4();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: Inspect TTL container ==========");
await steps.Step5();
Console.WriteLine("\n--- Press Enter to continue to Step 6 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 6: Compare RU distribution ==========");
await steps.Step6();
