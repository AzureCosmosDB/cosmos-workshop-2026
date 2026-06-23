# Trainer Guide

> **Purpose:** this guide focuses on delivery (content, demos, troubleshooting) and assumes a provisioned cohort. **Environment provisioning lives in [TrainerEnvironmentSetup.md](TrainerEnvironmentSetup.md)**

This guide is for instructors delivering the Cosmos DB + Foundry workshop. It covers:

1. [Workshop overview](#workshop-overview)
2. [Pre-workshop preparation](#pre-workshop-preparation)
3. [Student setup](#student-setup)
4. [Content Notes](#content-notes)
5. [General Troubleshooting](#general-troubleshooting) including auth, RBAC, throttling, network, model availability
6. [References](#references)

---

## Workshop overview

### Target Audience

- Some general cloud experience preferred
- Comfortable reading Python and/or C#; all labs provide both options
- No prior Cosmos DB or Foundry experience assumed
- Students don't need anything installed on their own machines other than RDP client; Lab VM is provided for running all labs

### Scheduling

The course is designed as a single day. If running short on time, the safest lab to drop is **2F Evaluation**. The 2E RAG pipeline already demonstrates the pattern, and 2F's LLM-as-judge content is a "nice to have" rather than core to the workshop narrative. Fabric content in Part 3 and lab **4B Analyzing History Using Fabric Mirror** have also been pushed to the end to allow for time savings by trimming from the end without losing out on the core Cosmos DB content.

---

## Pre-workshop preparation

Provision the cohort at least 24 hours before class using [TrainerEnvironmentSetup.md](TrainerEnvironmentSetup.md), then run the single-student smoke-test from that same doc end-to-end to identify any environment issues in advance.

---

## Student setup

Self directed VM and account setup steps for students can be found in [StudentEnvironmentSetup.md](StudentEnvironmentSetup.md). The most common blocker will likely be the first-time Entra sign-in: students are forced to change their temp password and may be prompted to enroll MFA, so extra time may be needed for the slowest students.

---

## Content Notes

### Part 1: Azure Cosmos DB Fundamentals

#### 1A: Resource Model (Deck, 15 min)

- **Key points:** account -> database -> container -> item; partition key is required at container creation and cannot be changed; NoSQL API is the focus for this course and should be the one used for all new development, other API modes are being phased out.
- **Demo hook:** Open Azure Portal -> workshop Cosmos account -> Data Explorer. Show the database/container tree and one document. This can quickly make the hierarchy concrete and introduce the Portal tools that can be used later in labs.
- **Common questions:**
  - *"Can I change the partition key path later?"* No, it's immutable. Create a new container and migrate data.
  - *"Are Cosmos containers like Docker containers?"* Same name, different concept. Containers in Cosmos are more like tables in a SQL database.

#### 1B: SDK Basics (Lab, 10 min)

- **Files:** [1B_SDK_CRUD/](../1B_SDK_CRUD/), `before/python/`, `before/csharp/` (lab steps in `before/csharp/Instructions.md`)
- **Pre-flight:** Students must have run `1B_Account_Access.ps1` to apply RBAC data-plane roles for their accounts. The lab will 403 otherwise.
- **Key points:** `DefaultAzureCredential` flow means no keys; `create_item` / `read_item` / `upsert_item` / `delete_item` are the common CRUD methods; item data structures require `id` and partition key value
- **Demo hook:** Run the `before/` project as-is first to show the student-exercise stub output, then implement Step 1 live to model the workflow.
- **Common questions:**
  - *"Why `partitionKey` and not `/partitionKey`?"* The slash form is the partition key *path* declaration on the container; the value in the document is just the property.
  - *"Why does upsert sometimes return 201 vs 200?"* 201 = created, 200 = replaced existing.
- **Troubleshooting:**
  - **403 Forbidden on create step:** Data-plane RBAC missing. Run `1B_Account_Access.ps1`.
  - **`COSMOS_ENDPOINT` empty:** User env var didn't propagate to process; restart VS Code / terminal.

#### 1C: Cosmos Database Design Concepts (Deck, 20 min)

> The deck splits 1C around the labs: the **RU + Indexing** half plays before Lab 1D, and the **Data Modeling + Partitioning** half plays after 1D and before Lab 1E. Plan the transitions accordingly.

- **Key points:**
  - **RU:** the currency; serverless vs provisioned with optional autoscale; cost depends on item size, path depth, indexed paths, query complexity; RU limits cause 429 responses; database-level throughput is rarely used.
  - **Indexing:** all paths indexed by default; tune via included/excluded paths to cut write RU on large/unused fields; focus on common query paths.
  - **Data Modeling:** different than relational DB design; model around access patterns, not normalization; embed vs reference tradeoff; duplication is sometimes the right answer.
  > **Data Modeling section should be a key emphasis of the workshop**
  - **Partitioning:** partition key required at container create time, immutable; cardinality / even distribution / query-scope selection criteria; hot partitions; HPK for additional partition flexibility.
- **Demo hook:** Open the [Cosmos DB Capacity Calculator](https://cosmos.azure.com/capacitycalculator/) for a small workload during the RU half to help ground abstract RU pricing concepts in a real example.
- **Common questions:**
  - *"How do I choose RU settings?"* Start with Serverless or autoscale and monitor usage through normalized RU % and 429 metrics (covered in labs).
  - *"Can I query multiple containers?"* Separate containers require multiple queries. Consider fan-out requirements with one-to-many relationships and design data model to avoid.
  - *"How can I keep embedded data up to date?"* Cosmos Change Data Capture produces the Change Feed which can be used trigger execution of Azure Functions to apply new data from primary containers to nested data in other containers.
  - *"How do I pick a partition key?"* Walk through the cardinality / distribution / query-scope checklist with their actual workload if anyone volunteers one.
  - *"What if my query crosses partitions?"* It works but costs more, quantified in lab 1D.
- **Watch for:** Confusion between "physical partition" (Cosmos-managed, 50 GB / 10k RU) and "logical partition" (partition-key value, 20 GB). Name them explicitly and focus on logical as the user facing concept.

#### 1D: Querying / Indexing (Lab, 30 min)

> Includes 2 parts: **1D-1 Query Language** + **1D-2 Indexing Policy**

- **Files:** [1D1_Query_Language/](../1D1_Query_Language/), [1D2_Indexing/](../1D2_Indexing/)
- **Key points:** parameterized SQL queries; cross-partition queries cost more; point read is cheapest; indexing policy excluded paths reduce write RU on large/unused fields.
- **Demo hook:** Run a query against `WorkshopData.Catalog` in Data Explorer and show the **Query Stats** panel with the request charge / retrieved document count displayed.
- **Common questions:**
  - *"Do I need `enable_cross_partition_query=True`?"* Required when the query doesn't include the partition key. Always show the partition-scoped variant alongside for contrast.
  - *"Are all properties indexed by default?"* Yes, that's why excluded paths matter for write-heavy workloads. The current policy can be viewed on any container.
- **Troubleshooting:**
  - **Query errors or no results:** syntax is subtly different from T-SQL; watch for missing `FROM c` clause, missing `c.` prefix on property names, inexact property name matches: `_` separators vs camelCase, case sensitive.
  - **Indexing changes don't appear immediately:** Indexing policy updates are async. Re-read the container or wait ~30s.
  - **`x-ms-request-charge` not visible in Python:** It's on `container.client_connection.last_response_headers` after the call.

#### 1E: Data Modeling / Partition Keys (Lab, 60 min)

- **Files:** [1E_Data_Modeling/](../1E_Data_Modeling/)
- **Key points:** model around access patterns, not normalization; embed when read together, reference when updated separately; composite or hierarchical partition keys (HPK) for avoiding hot partitions.
- **Demo hook:** Focus on how the example SQL JOIN does not work conceptually in Cosmos with a multi-container reference model.
- **Common questions:**
  - *"How is HPK different from a composite/synthetic key?"* HPK is a first-class Cosmos feature including SDK support, limited to three paths but uses property values directly. Synthetic keys (`f"{a}#{b}"`) are a simplified pattern that fits in existing containers without needing to redefine partition key paths.
  - *"Why aren't multiple partitions shown in portal metrics?"* Lab uses small data volume that fits within one physical partition so all logical partitions are grouped within same bucket. Containers over 10k RU start to split and show the concentrating effect of hot partitions directly in the metrics.
- **Troubleshooting:**
  - **Portal metric shows nothing:** Lag of 1–5 min after writes. Tell students to wait and continue with the next cell.

#### 1F: Replication and Security (Deck, 10 min)

- **Key points:** multi-region replication and single- vs multi-write regions; five consistency levels but Session is the default and is right for most apps; control vs data plane RBAC; managed identity over keys.
- **Demo hook:** In a **cosmos-provisioned** account, Portal -> Cosmos DB -> Settings -> **Replicate data globally** and **Default consistency** blades to show multi-region options.
- **Common questions:**
  - *"When would I use multiple regions?"* Primary use case is to reduce latency by reading from local regions. RU scale is also per-region so can help spread loads.
  - *"Why don't data-plane roles show in the Portal IAM blade?"* By design they live in `az cosmosdb sql role assignment`. This is the answer to "I added Contributor but I still get 403." Refer back to the `1B_Account_Access.ps1` script.

#### 1G: Monitoring and Troubleshooting (Deck, 30 min)

- **Key points:** common errors (429, 404, 409/412); Azure Monitor metrics out of the box; key metrics (status codes, normalized RU, data size); diagnostic settings needed for log categories.
- **Common questions:**
  - *"What is a 429 error?"* `Too Many Requests` which indicates hitting RU limits. Infrequent 429s can be handled by retry but avoid rapid retries compounding the problem. Patterns of frequent 429s indicate need to reduce query cost or increase RUs.
  - *"What's normalized RU consumption?"* Per-second utilization across partitions, used for autoscale decisions. A sustained value above ~80% is scale-up signal.
  - *"How do I find which query is expensive?"* Diagnostic logs include the query text and RU charge. Requires a diagnostic setting pointed at Log Analytics.

### Part 2: Microsoft Foundry Fundamentals

> **Deck and lab order:** 2A intro (Foundry / setup modes / BYO thread storage) -> **Lab 2C** -> **Lab 2D** -> concept slides (RAG, Security & Governance, Observability & Guardrails, Models & Pricing) -> **Lab 2E** -> **Lab 2F** -> **2B Model Catalog slides** -> **Lab 4A**.

#### 2A (part 1): Foundry + Cosmos DB for Agents and RAG (Deck, ~7 min)

- **Key points:** Foundry as the unified PaaS for agents/models/tools; three setup modes (Basic / Standard / Standard+Private); BYO thread storage in Cosmos DB (`enterprise_memory` database, three containers: `thread-message-store`, `system-thread-message-store`, `agent-entity-store`).
- **Demo hook:** Open <https://ai.azure.com>, show the workshop project, and click into the **Agents** tab if it's enabled. Even 30 seconds of "this is the surface we're targeting" anchors the rest of Part 2.
- **Common questions:**
  - *"What's the difference between Foundry and Azure OpenAI?"* Foundry is the broader unified resource; Azure OpenAI is one of the model surfaces inside it.
  - *"Do I have to use Cosmos DB for thread storage?"* For Standard setup with BYO, yes — that's the supported store today.

#### 2C: Chat Completions and Embeddings (Lab, 20 min target / 25 min actual)

- **Files:** [2C_Completions_Embeddings/](../2C_Completions_Embeddings/)
- **Key points:** `AzureOpenAI` client construction; basic chat call shape (system/user messages, temperature, max_tokens); streaming via `stream=True`; embeddings shape and dimensionality.
- **Demo hook:** Run a chat completion with `stream=True` and a long prompt — the token-by-token reveal sells streaming better than any slide.
- **Common questions:**
  - *"Why does the embedding have 1536 numbers?"* That's the model's output dimensionality; explain it's the "fingerprint" used for similarity later in 2D.
  - *"Why two different endpoints?"* Lab 4 uses Entra for chat, but embeddings v1 still needs a key. This is current-state, not by design.
- **Troubleshooting:**
  - **404 on chat completion:** `COMPLETIONS_MODEL` doesn't match the deployment name in Foundry. Verify in ai.azure.com -> Deployments.
  - **Rate limit (429):** Per-student Foundry capacity is small. If a student's cell bursts, expect occasional throttling — re-run usually clears it.

#### 2D: Vector Search (Lab, 25 min)

- **Files:** [2D_Vector_Search/](../2D_Vector_Search/)
- **Pre-flight:** Uses the `WorkshopData.Docs` container — confirm vector embedding policy and DiskANN index are in place.
- **Key points:** generate embeddings -> store with the document -> query with `VectorDistance(...)`; compare against `FullTextContains(...)` to motivate semantic vs keyword.
- **Demo hook:** After running the vector query, swap the search phrase to something the keyword search would miss (e.g., "how reliable is Cosmos" vs full-text on `cosmos db`). The semantic hit lands as a visceral "ahh".
- **Common questions:**
  - *"Why TOP N with ORDER BY VectorDistance?"* That's how nearest-neighbor is expressed — there's no dedicated `VECTOR_SEARCH` syntax.
  - *"Cosine vs dot product?"* Embeddings are normalized, so cosine and dot give the same ranking. We use cosine.

#### 2A (part 2): RAG, Security and Governance, Observability and Guardrails, Models and Pricing (Deck, ~13 min)

> Slides 44–47 in the deck. They land *between* Lab 2D and Lab 2E so that the RAG concept arrives just before students build the pipeline in 2E.

- **Key points:**
  - **RAG pattern overview:** chunk -> embed -> store -> retrieve -> generate; Cosmos DB serves as both operational store and vector store, removing the need for a separate search service.
  - **Security & Governance for Agents:** Entra Agent ID gives each agent a first-class directory identity; Administrator / Project Manager / Project User RBAC roles; customer-managed keys for sensitive data.
  - **Observability & Guardrails:** built-in evaluation, OpenTelemetry tracing, Azure Monitor + Aspire dashboards; Azure AI Content Safety (Prompt Shields, PII detection, Task Adherence).
  - **Models & Pricing:** broad family lineup (GPT-5/4.1/4o/o-series, Claude/Grok/Mistral/DeepSeek/Phi-4/Llama, audio/image/video); platform is free, you pay for what you deploy.
- **Demo hook:** ai.azure.com -> **Evaluation** / **Tracing** tab on the workshop project (skip if it requires enabling) — even a glance at the surface sets up 2F.
- **Watch for:** Specific model names on the Models & Pricing slide change fast — sanity-check the catalog the morning of class.

#### 2E: Retrieval-Augmented Generation (RAG) Pipeline (Lab, 45 min target / 60 min actual)

- **Files:** [2E_RAG_Pipeline/](../2E_RAG_Pipeline/)
- **Key points:** chunk -> embed -> store -> retrieve -> generate; chunking strategy matters (sentence boundaries via `nltk`); retrieved chunks become part of the system prompt.
- **Demo hook:** Show a "before / after" — same question against the raw model vs against the RAG pipeline. Pick a question whose answer is in your docs but not the model's pretraining (recent product behavior).
- **Common questions:**
  - *"How big should chunks be?"* 200–1000 tokens is typical; ~512 chars is what the lab uses for simplicity. Tradeoff: too big = noisy retrieval, too small = lost context.
  - *"Why not just feed the whole doc?"* Token budget. And quality suffers — relevant context gets diluted.
- **Troubleshooting:**
  - **`nltk.tokenize` import error:** Need `nltk.download('punkt_tab')` (or `'punkt'` on older nltk). The install cell in the lab covers this, but if students skip it, that's the symptom.
  - **Empty retrieval results:** Check that embeddings were actually upserted — `SELECT VALUE COUNT(1) FROM c WHERE IS_ARRAY(c.embedding)` should match the chunk count.

#### 2F: Evaluation of RAG Outputs (Lab, 25 min target / 35 min actual)

- **Files:** [2F_Evaluation/](../2F_Evaluation/)
- **Key points:** evaluation as a first-class step; ground-truth dataset; LLM-as-judge with a scoring prompt; aggregate scoring; thresholds for action.
- **Demo hook:** Show a clearly-wrong answer being scored low by the judge — then improve the retrieval (more chunks, better question) and re-run. The score going up sells the iteration loop.
- **Common questions:**
  - *"Isn't LLM-as-judge biased?"* Yes; in production, pair with human review or use a different model family as the judge. We're using it for tractability.
  - *"Why only 1–5?"* Smaller scale = more consistent judge output. Higher resolution scales drift.

#### 2B: Model Catalog (Deck, 20 min)

> Deck slides 50–54. The rearranged deck plays this **after** Labs 2C–2F — by then students have called the SDK and have a frame of reference for "which model, what deployment shape."

- **Key points:** Azure Direct vs Partner/Community billing; model families (GPT-5/4.1/4o/o-series, embeddings, Claude/Grok/Mistral/etc.); fine-tuning options (SFT/DPO/RFT per family); deployment types (Instant, GlobalStandard, GlobalProvisionedManaged, GlobalBatch, DataZone variants, Standard, DeveloperTier); managed identity preferred over keys.
- **Demo hook:** ai.azure.com -> Model Catalog filter sidebar. Toggle filters to show how a real customer would narrow from ~1,900 models to 3.
- **Common questions:**
  - *"When do I pick Catalog vs an Azure OpenAI resource?"* Catalog = flexible per-invocation usage; AOAI resource = dedicated capacity with stronger SLAs.
  - *"What's the difference between Instant and GlobalStandard?"* Instant skips deployment entirely (pay-per-token, preview); GlobalStandard is the highest-quota pay-per-token deployment.
- **Watch for:** Slides may name specific models that change quickly — sanity-check the catalog the morning of class for any deprecations.

#### Bridge to Part 4: Lab 4A following close of Part 2

> Deck slide 55. Scheduling **Lab 4A (Conversational History / Agent Memory)** immediately after 2B slides, before the Part 3 section divider, can help reinforce the agent-memory pattern while Foundry is still fresh and break up the slide sections. This also allows for cutting Fabric content for time if needed. 4A can also still be run following Part 3 if that order is preferred for a given class session.

### Part 3: Unify Data Estate

#### 3A: Microsoft Fabric Overview (Deck + Demo, 15 min)

- **Key points:** Fabric as unified SaaS analytics across 10 workloads; OneLake (tenant-wide ADLS Gen2) + OneLake Catalog; Lakehouse (Spark) vs Warehouse (T-SQL); Real-Time Hub for data-in-motion; Cosmos DB Mirror for HTAP (Hybrid Transactional/Analytical Processing) without ETL.
- **Demo hook:** Open the workshop Fabric workspace. Show the **OneLake Catalog** and open or create a Notebook to introduce the UI.
- **Common questions:**
  - *"What's the lag?"* Near-real-time; typically seconds, occasionally tens of seconds under load.
  - *"What if I update a doc in Cosmos?"* Reflected on the mirror within seconds; the analytics endpoint reads the latest version.

### Part 4: End-to-End App

> **Deck placement note:** the deck order starts the Part 4 labs before Part 3 but this ordering is optional and won't affect the order of other slide content. **Lab 4A** can follow Part 2 or Part 3. **Lab 4B** either closes Part 3 or can follow **Lab 4A**. The Part 4 grouping is preserved here because the labs share a narrative arc (build the agent, produce data, then analyze the history).

#### 4A: Conversational History / Agent Memory (Lab, 60 min)

- **Files:** [4A_Chat_Memory/](../4A_Chat_Memory/)
- **Pre-flight:** `Conversations.Messages` container exists with `/sessionId` partition key. Foundry chat deployment reachable via Entra ID (not key — different from 2C).
- **Key points:** chat message schema (`id`, `sessionId`, `role`, `content`, `timestamp`, `metadata`); `save_chat_turn` and `get_recent_messages` helpers; sliding-window context strategy; layering RAG retrieval from 2E into the prompt.
- **Demo hook:** Run two turns where the second references the first ("What is Cosmos DB?" then "Tell me about its consistency levels"). Show that the second answer treats the first as known context. Then show the resulting documents in Data Explorer.
  > Note that C# version uses a command line chat loop while Python takes list of questions as input inside a Notebook cell that can be altered and run repeatedly. Chat sessions are started in early steps so creating multiple sessions of data to query requires re-running early steps followed by later chat steps.
- **Common questions:**
  - *"How do I trim by token budget instead of count?"* Use `tiktoken` open source library to count tokens on each historical turn and pop oldest until under budget. The lab uses less granular count-based trimming for simplicity.
  - *"Why save user and assistant turns separately?"* Each is independently queryable, and the audit trail is cleaner. Storing as a transcript blob makes analytics harder.
- **Troubleshooting:**
  - **Auth failure on Foundry chat:** Lab 4 expects Entra; Confirm user's Foundry endpoints and `Cognitive Services Contributor` role on Foundry account to support `DefaultAzureCredential`. Role is set from student run `1B_Account_Access.ps1` script.
  

#### 4B: Analyzing History Using Fabric Mirror (Lab, 40 min)

- **Files:** [4B_Fabric_Mirror_Analytics/](../4B_Fabric_Mirror_Analytics/)
- **Pre-flight:** Student workspace created in Fabric and accessible. Some 4A chat data already written so the queries have rows to aggregate.
- **Key points:** SQL analytics endpoint exposes the mirrored `Messages` table in T-SQL; schema handling (new columns added, missing fields null, renamed shows both); nested JSON via `JSON_VALUE` / `JSON_QUERY` / `OPENJSON`; T-SQL aggregations over mirrored `Messages` for per-day / per-role / per-session / token-spend / latency-percentile breakdowns; **zero RU impact on the live agent** is the headline.
- **Demo hook:** Split-screen Fabric SQL endpoint and Cosmos Normalized RU chart while running aggregations. Then switch to the agent notebook from 4A and send a chat turn; show the RU bump from that single write to make the contrast visceral.
- **Troubleshooting:**
  - **Mirroring connection setup fails with auth error:** Student account may be missing required RBAC permissions for mirroring that are set by `Set-CosmosMirroringRbac.ps1` during provisioning. Retry the script, or as a failsafe fallback use key based auth by copying key from the Cosmos account to get the student unstuck.
  - **"Mirroring not started" error:** Cosmos account is missing one of: continuous backup, system identity, single-write region. Fix in the Cosmos account, then re-create the mirror.
  - **No data in mirrored table:** Check Replication status on the mirror item. If "Running" but empty, give it a minute - initial snapshot is in progress.
- **Common questions:**
  - *"Can I write back to Cosmos from Fabric?"* Mirroring is read-only on the Fabric side. For write-back you'd use a separate pipeline.
  - *"Do I write queries using Cosmos NoSQL API SQL syntax?"* No, T-SQL or Spark SQL queries use standard SQL over table structures and also support JOINs.

---

## General Troubleshooting

These come up regardless of section.

### Authentication and RBAC

| Symptom | Most likely cause | Fix |
|---|---|---|
| `Forbidden (403)` on first Cosmos call | Data-plane role not assigned to the signed-in user | Run `1B_Account_Access.ps1` with workshop-correct names |
| `AADSTS50058` or login pops repeatedly | `DefaultAzureCredential` falling through credential chain | `az login` in a terminal, then restart VS Code |
| Foundry chat returns 401 in lab 4A | Lab 4 uses Entra, not key | Confirm `az login` succeeded and the Foundry role is assigned |
| Embeddings call 401 in any 2x lab | Embeddings v1 endpoint requires `EMBEDDINGS_KEY`, not Entra | Confirm `EMBEDDINGS_KEY` is set in the student's env vars |

### Throttling and capacity

- **Cosmos 429s during a lab:** Serverless containers have per-partition RU ceilings. If a lab loop is hammering one partition, back off or move to a provisioned container.
- **Foundry 429s:** Capacity is 1 unit on the workshop Foundry account. With a full class, bursty cells can throttle. If you anticipate this, bump capacity the day before as costs are low when idle.
- **Fabric "capacity paused":** F-SKU capacity auto-pauses with inactivity. Resume it from the Fabric admin portal before class.

### Model availability

- **`DeploymentNotFound` (Foundry):** Deployment name in `COMPLETIONS_MODEL` doesn't match. Open ai.azure.com -> Deployments to confirm the actual name. Name is case sensitive.
- **Model deprecation:** Model catalog changes faster than course content. If configured model is gone, swap to the closest equivalent and call it out.

### Environment variables on the VM

- Variables set with `[System.Environment]::SetEnvironmentVariable(..., 'User')` require a restart of VS Code and Terminal/Powershell to appear in new processes.
- Check `$env:COSMOS_ENDPOINT` in fresh PowerShell window and Control Panel -> System -> Environment Variables to verify scripts are correctly applied.

### Lab language selection

- **C#/Python parity:** Most labs use the same steps and resources for both languages but there are some minor differences due to language and SDK constructs and the difference in execution environments (Notebook vs application). Students should be free to choose either or both languages but may notice some minor differences if switching back and forth.

---

## References

- [TrainerEnvironmentSetup.md](TrainerEnvironmentSetup.md) — pre-class environment provisioning (Bicep, scripts, roster CSV, smoke-test, cost & cleanup)
- [StudentEnvironmentSetup.md](StudentEnvironmentSetup.md) — student-facing first-15-minutes walkthrough
- Azure Cosmos DB Capacity Calculator — <https://cosmos.azure.com/capacitycalculator/>
- Fabric portal — <https://app.fabric.microsoft.com/>
- Foundry portal — <https://ai.azure.com>
