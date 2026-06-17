// Lab 1D2: Indexing Policy

using Lab1D2;

var steps = new Steps_Indexing();

Console.WriteLine("\n========== STEP 0: Initialize connection ==========");
await steps.Step0();
Console.WriteLine("\n--- Press Enter to continue to Step 1 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 1: Inspect default-indexing container ==========");
await steps.Step1();
Console.WriteLine("\n--- Press Enter to continue to Step 2 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 2: Inspect custom-indexing container ==========");
await steps.Step2();
Console.WriteLine("\n--- Press Enter to continue to Step 3 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 3: RU comparison — largeBlob only ==========");
await steps.Step3();
Console.WriteLine("\n--- Press Enter to continue to Step 4 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 4: RU comparison — metadata only ==========");
await steps.Step4();
Console.WriteLine("\n--- Press Enter to continue to Step 5 ---");
await Console.In.ReadLineAsync();

Console.WriteLine("\n========== STEP 5: RU comparison — combined ==========");
await steps.Step5();
Console.WriteLine("\n--- Lab complete ---\n");
