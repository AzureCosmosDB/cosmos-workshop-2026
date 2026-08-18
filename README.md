---
title: Azure Cosmos DB Workshop
description: Persona-based entry point for students and trainers completing the Cosmos DB, Foundry, RAG, and Fabric workshop.
---

Build an application journey that starts with Azure Cosmos DB for NoSQL and
progresses through Azure AI Foundry, vector search, retrieval-augmented
generation (RAG), conversational memory, and Microsoft Fabric analytics.

The workshop supports C# and Python. A trainer provisions an isolated Azure
environment for each student, and students complete the labs from a preconfigured
Windows VM in a browser.

## Choose your path

| Persona | Start here | What you will do |
|---------|------------|------------------|
| Student | [Student workshop guide](docs/StudentEnvironmentSetup.md) | Connect to your VM, configure access, choose C# or Python, and complete the labs in order |
| Trainer | [Trainer delivery guide](docs/TrainerGuide.md) | Prepare the session, guide the course narrative, deliver each module, and support students |
| Environment administrator | [Trainer environment setup](docs/TrainerEnvironmentSetup.md) | Provision the cohort, validate resources, distribute credentials, control costs, and clean up |

## What the workshop covers

The content follows the sequence in the workshop content outline:

| Part | Topic | Key sections |
|------|-------|--------------|
| 1 | Azure Cosmos DB fundamentals | Resource model, SDK CRUD, request units, querying, indexing, data modeling, partitioning, replication, security, and monitoring |
| 2 | Microsoft Foundry fundamentals | Chat completions, embeddings, vector search, RAG, evaluation, and model selection |
| 3 | Unified analytics with Fabric | OneLake, Cosmos DB mirroring, and analytics without adding request-unit load to the operational database |
| 4 | End-to-end application | Conversational history in Cosmos DB and analysis of that history through Fabric |

## Student journey

1. Receive one credential row from your trainer. The portal and VM passwords
	are the same.
2. Open the Bastion link and sign in to the workshop VM.
3. Run `az login`, configure environment variables, and apply the lab data-plane
	role assignments.
4. Choose C# or Python and work from each lab's `before` folder.
5. Complete the labs in the documented order, using `after` only as a reference.
6. Tell the trainer when you finish so the VM can be deallocated.

See the [student workshop guide](docs/StudentEnvironmentSetup.md) for commands,
lab links, checkpoints, and troubleshooting.

## Trainer journey

1. Review the course sequence and decide which optional sections fit the
	available time.
2. Provision the cohort at least 24 hours before delivery.
3. Smoke-test one complete environment in the same order a student will use it.
4. Send each student only their own credential row and setup guide.
5. Deliver the modules in sequence, checking prerequisites before dependent labs.
6. Deallocate VMs, pause Fabric, and remove the cohort when retention is no
	longer required.

Use the [trainer delivery guide](docs/TrainerGuide.md) for the teaching flow and
the [trainer environment setup](docs/TrainerEnvironmentSetup.md) for Azure
operations.

## Lab order

| Order | Lab | Student outcome |
|-------|-----|-----------------|
| 1 | [1B SDK CRUD](1B_SDK_CRUD/) | Connect with Microsoft Entra ID and perform item CRUD operations |
| 2 | [1D1 Query Language](1D1_Query_Language/) | Write parameterized queries and compare request-unit costs |
| 3 | [1D2 Indexing](1D2_Indexing/) | Compare default and tailored indexing policies |
| 4 | [1E Data Modeling](1E_Data_Modeling/) | Design items and partition keys around access patterns |
| 5 | [2C Completions and Embeddings](2C_Completions_Embeddings/) | Call chat and embedding models through Foundry |
| 6 | [2D Vector Search](2D_Vector_Search/) | Store embeddings and run semantic searches in Cosmos DB |
| 7 | [2E RAG Pipeline](2E_RAG_Pipeline/) | Build a retrieve-and-generate pipeline using Cosmos DB |
| 8 | [2F Evaluation](2F_Evaluation/) | Evaluate grounded responses with an LLM judge (optional) |
| 9 | [4A Chat Memory](4A_Chat_Memory/) | Persist and retrieve multi-turn conversational history |
| 10 | [4B Fabric Mirror Analytics](4B_Fabric_Mirror_Analytics/4B_Fabric_Mirror_Analytics_Instructions.md) | Mirror chat history and analyze it with T-SQL (optional) |

## Repository layout

Most labs use the same structure:

```text
<lab>/
|-- before/              Student starting point
|   |-- csharp/
|   `-- python/
`-- after/               Completed reference solution
	 |-- csharp/
	 `-- python/
```

The C# folder contains an `Instructions.md` file and a runnable project. The
Python folder contains a Jupyter notebook with instructions embedded in its
cells. Lab 4B runs in Microsoft Fabric and therefore has no local code project.

## Supporting documentation

* [Student workshop guide](docs/StudentEnvironmentSetup.md)
* [Trainer delivery guide](docs/TrainerGuide.md)
* [Trainer environment setup](docs/TrainerEnvironmentSetup.md)
* [Lab VM setup reference](docs/LabVmSetup.md)
