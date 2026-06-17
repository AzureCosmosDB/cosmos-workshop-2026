# Lab 2F: Evaluation in C#

**Time**: ~20 min  
**Environment**: .NET 10 terminal

In this exercise you will evaluate a RAG pipeline using the LLM-as-judge pattern.

The lab uses a single project in the `2F_Evaluation` directory. Running `dotnet run` walks through each step in sequence, pausing for **Enter** between steps. Each step builds on the previous one, so you must complete them in order.

## Prerequisites

You must have .NET 10 installed and an Azure AI Foundry endpoint configured for chat completions. This lab focuses on the LLM-as-judge scoring loop; retrieval is mocked with a plain Cosmos query, so no embeddings client is needed (real embedding + vector search is covered in Labs 2D and 2E).

```bash
dotnet --version
```

## Setup

1. Open a terminal in the `2F_Evaluation` directory:

   ```bash
   cd 2F_Evaluation
   ```

Chat completions go through an Azure AI Foundry endpoint with Entra ID auth.

2. Set required environment variables:

   ```bash
   export COSMOS_ENDPOINT="https://YOUR_ACCOUNT.documents.azure.com:443"
   export FOUNDRY_ENDPOINT="https://YOUR_FOUNDRY.openai.azure.com"
   export COMPLETIONS_MODEL="phi-4-mini-instruct"
   export EVAL_MODEL="phi-4-mini-instruct"  # optional, defaults to COMPLETIONS_MODEL
   ```

## Evaluation Operations

Run the project. It executes each step in order, pausing for **Enter** between steps:

```bash
dotnet run
```

### Step 0: Initialize Connection

Set up the Cosmos client connection and Azure OpenAI clients.

### Step 1: Create Evaluation Dataset (STUDENT EXERCISE)

Create a set of evaluation test cases with questions and ground truth answers.

### Step 2: Score RAG Outputs (STUDENT EXERCISE)

Use the LLM-as-judge pattern to score the relevance of RAG outputs against ground truth answers.

### Step 3: Summarize Results

Review the average relevance score and recommendations for the RAG pipeline.

## Lab Complete!

You have completed the evaluation exercise in C#. You:
- Set up RAG pipeline with Cosmos DB and Azure OpenAI
- Created an evaluation dataset
- Scored RAG outputs using LLM-as-judge pattern
- Summarized evaluation results