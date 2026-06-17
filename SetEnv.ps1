# Workshop Environment Setup
# Sets the User-scope environment variables used across all labs in this repo.
# Update the values below with the outputs from your Bicep deployment, then run
# this script. Restart VS Code or the terminal afterwards to pick up the changes.

# ---- Cosmos DB ----
# Serverless account — used by most labs (1B, 1D1, 1D2, 2*, 4A).
[string]$COSMOS_ENDPOINT = "https://YOUR_SERVERLESS_ACCOUNT.documents.azure.com:443/"
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT', $COSMOS_ENDPOINT, 'User')

# Provisioned-autoscale account — used by Lab 1E (Data Modeling) so Azure Monitor
# reports per-partition RU consumption for the hot-partition vs composite-key demo.
[string]$COSMOS_ENDPOINT_PROVISIONED = "https://YOUR_PROVISIONED_ACCOUNT.documents.azure.com:443/"
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT_PROVISIONED', $COSMOS_ENDPOINT_PROVISIONED, 'User')

# ---- Azure AI Foundry (chat completions, Entra ID auth) ----
# Used by Lab 4A and the 2x AI-pipeline labs.
[string]$FOUNDRY_ENDPOINT = "https://YOUR_FOUNDRY.services.ai.azure.com/"
[System.Environment]::SetEnvironmentVariable('FOUNDRY_ENDPOINT', $FOUNDRY_ENDPOINT, 'User')

# ---- Azure OpenAI Embeddings (API-key auth) ----
# The v1 embeddings surface does not yet support Entra ID, so we pass a key.
[string]$EMBEDDINGS_ENDPOINT = "https://YOUR_OPENAI.cognitiveservices.azure.com/"
[string]$EMBEDDINGS_KEY = "YOUR_EMBEDDINGS_KEY"
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_ENDPOINT', $EMBEDDINGS_ENDPOINT, 'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_KEY',      $EMBEDDINGS_KEY,      'User')

# ---- Model deployment names ----
[string]$COMPLETIONS_MODEL = "Phi-4-mini-instruct"
[string]$EMBEDDINGS_MODEL  = "text-embedding-3-small"
[System.Environment]::SetEnvironmentVariable('COMPLETIONS_MODEL', $COMPLETIONS_MODEL, 'User')
[System.Environment]::SetEnvironmentVariable('EMBEDDINGS_MODEL',  $EMBEDDINGS_MODEL,  'User')

Write-Output "Done."
Write-Output "  COSMOS_ENDPOINT             = $COSMOS_ENDPOINT"
Write-Output "  COSMOS_ENDPOINT_PROVISIONED = $COSMOS_ENDPOINT_PROVISIONED"
Write-Output "  FOUNDRY_ENDPOINT            = $FOUNDRY_ENDPOINT"
Write-Output "  EMBEDDINGS_ENDPOINT         = $EMBEDDINGS_ENDPOINT"
Write-Output "  EMBEDDINGS_KEY              = ***"
Write-Output "  COMPLETIONS_MODEL           = $COMPLETIONS_MODEL"
Write-Output "  EMBEDDINGS_MODEL            = $EMBEDDINGS_MODEL"
Write-Output "Restart VS Code / your terminal to pick up the new environment variables."
