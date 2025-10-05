# ==========================================
# PowerShell Automation Script for Open WebUI + Ollama Deployment
# ==========================================

# -------------------------------
# Step 1: Azure Login
# -------------------------------
Write-Host "Logging into Azure and select the default directory and subscription when prompted."
az login

# -------------------------------
# Step 2: Set Azure Subscription ID
# -------------------------------
$subscriptionId = az account show --query id -o tsv
Write-Host "Your subscription ID is: $subscriptionId"

# -------------------------------
# Step 3: Create Service Principal (if not already created)
# -------------------------------
# Uncomment this block if SP doesn't exist yet
$spName = "tf-aks-sp"
# Write-Host "Creating Service Principal: $spName"
$sp = az ad sp create-for-rbac --name $spName --role "Contributor" --scopes "/subscriptions/$subscriptionId" | ConvertFrom-Json
Write-Host "Service Principal created:"
$sp | Format-List

# -------------------------------
# Step 4: Set Environment Variables for Terraform
# -------------------------------
Write-Host "Setting environment variables for Terraform..."
$Env:ARM_SUBSCRIPTION_ID = "<YOUR_SUBSCRIPTION_ID>"
$Env:ARM_CLIENT_ID       = "<YOUR_APP_ID>"
$Env:ARM_CLIENT_SECRET   = "<YOUR_PASSWORD>"
$Env:ARM_TENANT_ID       = "<YOUR_TENANT_ID>"

# -------------------------------
# Step 5: Terraform Commands
# -------------------------------
$terraformDir = "C:\Path\To\Terraform\Directory"
Set-Location $terraformDir

Write-Host "Validating Terraform files..."
terraform validate

Write-Host "Initializing Terraform..."
terraform init

Write-Host "Creating Terraform plan..."
terraform plan -out plan.tfplan

Write-Host "Applying Terraform plan..."
terraform apply "plan.tfplan"

# Fetch outputs (aks_name and resource_group)
$aksName = terraform output -raw aks_name
$resourceGroup = terraform output -raw resource_group
Write-Host "AKS Cluster Name: $aksName"
Write-Host "Resource Group: $resourceGroup"

# -------------------------------
# Step 6: Configure kubectl
# -------------------------------
Write-Host "Fetching AKS credentials for kubectl..."
az aks get-credentials --resource-group $resourceGroup --name $aksName

# -------------------------------
# Step 7: Deploy Kubernetes Manifests
# -------------------------------
$k8sDir = "C:\Path\To\Kubernetes\Manifests"
Set-Location $k8sDir

Write-Host "Deploying OpenWebUI manifest..."
kubectl apply -f openwebui.yaml

Write-Host "Deploying Ollama manifest..."
kubectl apply -f ollama.yaml

# -------------------------------
# Step 8: Pull LLM Model and Serve Ollama
# -------------------------------
# Get Ollama pod name
$ollamaPod = kubectl get pods -l app=ollama -o jsonpath="{.items[0].metadata.name}"
Write-Host "Ollama Pod Name: $ollamaPod"

Write-Host "Pulling tinyllama model inside Ollama pod..."
kubectl exec -it $ollamaPod -- /bin/bash -c "ollama pull tinyllama"

Write-Host "Starting Ollama server..."
kubectl exec -it $ollamaPod -- /bin/bash -c "ollama serve &"

# -------------------------------
# Step 9: Display OpenWebUI Service Info
# -------------------------------
Write-Host "Getting OpenWebUI public service details..."
kubectl get svc openwebui -o wide

Write-Host "Deployment automation completed successfully!"
Write-Host "Access OpenWebUI using the EXTERNAL-IP:<PORT> displayed above."
