# should look like "lab-dev01"
$RESOURCE_GROUP = "lab-dev1"
# should look like "cosmoslab4gdfbg7q2o4ki"
$ACCT_NAME = "cosmoslab4gdfbg7q2o4ki"
$ACCT_NAME_PROVISIONED = "cosmoslab4gdfbg7q2o4ki-provisioned"
# Azure AI Foundry account (chat completions, Entra ID auth) — used by labs 2C, 2E, 2F, 4A.
$FOUNDRY_ACCT_NAME = "YOUR_FOUNDRY_ACCOUNT_NAME"

az login --allow-no-subscriptions
az account set --subscription "LaPST"

$USER_ID=$(az ad signed-in-user show --query id -o tsv)
$SUBSCRIPTION_ID=$(az account show --query id -o tsv)
Write-Output "Current user ID: $USER_ID"

az cosmosdb sql role assignment create --resource-group $RESOURCE_GROUP --account-name $ACCT_NAME --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id $USER_ID --scope "/"
Write-Output "Role assignment created for user $USER_ID on Cosmos DB account $ACCT_NAME"

az cosmosdb sql role assignment create --resource-group $RESOURCE_GROUP --account-name $ACCT_NAME_PROVISIONED --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id $USER_ID --scope "/"
Write-Output "Role assignment created for user $USER_ID on Cosmos DB account $ACCT_NAME_PROVISIONED"

# Foundry data-plane access for chat completions via Entra ID.
# "Cognitive Services OpenAI Contributor" includes the chat/completions data action
$FOUNDRY_SCOPE = "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_ACCT_NAME"
az role assignment create --assignee $USER_ID --role "Cognitive Services Contributor" --scope $FOUNDRY_SCOPE
Write-Output "Role assignment created for user $USER_ID on Foundry account $FOUNDRY_ACCT_NAME"

# set current user system environment variables for SDK usage
$endpoint = "https://$ACCT_NAME.documents.azure.com:443/"
$endpointProvisioned = "https://$ACCT_NAME_PROVISIONED.documents.azure.com:443/"
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT', $endpoint, 'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ACCOUNT_NAME', $ACCT_NAME, 'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ACCOUNT_NAME_PROVISIONED', $ACCT_NAME_PROVISIONED, 'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT_PROVISIONED', $endpointProvisioned, 'User')

