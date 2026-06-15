# should look like "lab-dev01"
$RESOURCE_GROUP = "lab-dev1"
# should look like "cosmoslab4gdfbg7q2o4ki"
$ACCT_NAME = "cosmoslab4gdfbg7q2o4ki"

az login --allow-no-subscriptions
az account set --subscription "LaPST"

$USER_ID=$(az ad signed-in-user show --query id -o tsv)
Write-Output "Current user ID: $USER_ID"

az cosmosdb sql role assignment create --resource-group $RESOURCE_GROUP --account-name $ACCT_NAME --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id $USER_ID --scope "/"
Write-Output "Role assignment created for user $USER_ID on Cosmos DB account $ACCT_NAME"

# set current user system environment variables for SDK usage
$endpoint = "https://$ACCT_NAME.documents.azure.com:443/"
[System.Environment]::SetEnvironmentVariable('COSMOS_ENDPOINT', $endpoint, 'User')
[System.Environment]::SetEnvironmentVariable('COSMOS_ACCOUNT_NAME', $ACCT_NAME, 'User')

