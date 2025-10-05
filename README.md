# bettersoftware-assesment
Task:
The goal of the assessment is to deploy Open WebUI in a cloud environment, connect it to Ollama running a lightweight LLM (e.g., Llama 2), and ensure it works end-to-end. Specifically,
 
1. Deploy Open WebUI on a Kubernetes cluster in a cloud environment (AWS, Azure, or GCP) using Terraform, ensuring it is accessible.
2. Connect Ollama with a lightweight LLM (e.g., Llama 2) to the WebUI and verify end-to-end functionality.
3. Debug any issues and provide a short README with deployment steps, configuration details, and any problems you solved (optionally include a small automation script).


Choices that are made for this assessment and this complete assessment is done from Windows:

1. Cloud: Azure free tier services - Though GCP and Azure provide free services to complete this assessment, I chose Azure as I am more familiar with it.
	- AKS for kubernetes services
	- ARM for resource creation using terraform
	- For AKS Cluster nodes, a single B2ms Azure VM is used to efficiently use the free credits( 2vCPUs and 8GB RAM)
	- A princial service account with RBAC contributor role to allow terraform to access the services in the subscription

2. Terraform: 
	- Used environmental variables to pass sensitive info like password, tenant id, etc
	- Used Azure service principal account for better authentication and authorization from terraform
	
3. Kubernetes:
	- The cluster is madeup of a single node just to efficiently use the Azure free credits
	- 2 different pods for openwebUI and ollama for better scalability. 
	- Deployment for OpenwebUI as it is stateless
	- To access OpenwebUI from internet a load balancer type service is used
	- Stateful sets for Ollama to persist the model cache and data even after pod restarts
	- A service is also created for Ollama to expose the pod to the cluster so that OpenwebUI can access it
	- A PVC to persist the cache and data of LLM model even when Ollama pod restarts

4. LLM model:
	- The LLM model used here is tinyllama which is widely used only for testing purposes
	- It is lightweight and is compatible with B2ms Azure VM
	

Prerequisites: Powershell commandline is used for the entire task

1. An Azure free tier account

2. Azure cli: 
	- Download azure cli using: winget install --exact --id Microsoft.AzureCLI
	
ref: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget
	- After successful installation do: az version
	
3. Terraform:
	- Download terraform using the windows binary package from the website - https://developer.hashicorp.com/terraform/install. Extract the downloaded package and set the environmental variable for the extracted path. 
	- Then run the command terraform -v to check if its installed successfully
	
4. Kubectl:
	- Download kubectl using the website https://kubernetes.io/releases/download/#binaries
	Set the environment path variable for kubectl and test it using: kubectl version --client


Steps to achieve the goal:

1. Perform az login and choose the default directory and subscription 1 by clicking Enter

2. Now setup service principal account in azure for security purposes:
	- To get the subscription ID for the azure account: az account show --query id -o tsv
	- Now create a service principal account with subscription id with the following command:
	az ad sp create-for-rbac --name "tf-aks-sp" --role "Contributor" --scopes /subscriptions/<Subscription_ID>

3. The output includes credentials that you must protect. Be sure that you do not include these credentials in your code or check the credentials into your source control.
	{
	  "appId": "",
	  "displayName": "",
	  "password": "",
	  "tenant": ""
	}

4. Set below environmental variables in the powershell so that terraform uses it during runtime
	$Env:ARM_SUBSCRIPTION_ID = ""
	$Env:ARM_CLIENT_ID       = "<appID>"
	$Env:ARM_CLIENT_SECRET   = "<password>"
	$Env:ARM_TENANT_ID       = ""


5. Now use the terraform files from the repo and run the below command from the terraform directory
	terraform validate - to validate the syntax
	terraform init - to initialize the current working directory and download require modules
	terraform plan -out plan.tfplan - creates a plan without actually applying it
	terraform apply "plan.tfplan" - applies the changes and displays the mentioned output from outputs.tf file
		aks_name = "aks-openwebui"
		resource_group = "rg-openwebui"

6. Once the resources are created using terraform, to access the kubernetes cluster from local kubectl, fetch the kubeconfig from the AKS using the below command:
	az aks get-credentials --resource-group <resource-group-name> --name <aks-cluster-name>

7. Use the kubernetes manifests for openwebui and ollama from the repo and run the below commands from kubernetes directory
	kubectl apply -f openwebui.yaml
	kubectl apply -f ollama.yaml
	
8. Now that the deployment is successful, get into the ollama pod and pull the tinyllama model using the below command:
	kubectl exec -it <ollama-pod-name> -- /bin/bash
	ollama pull tinyllama - pull the LLM model
	ollama serve - Start the API so that OpenWeb UI can use it
	
9. Now that all setups are done successfully, type the command kubectl get svc and get the openwebui public cluster IP and use the Clusterip:<port> to access openweb UI in browser

10. Ask a questions and it should give you a response. There you go, your goal is completed.

	
Issues faced:

The pods, services and deployments got successfully rolledout. But when I tried accessing the openwebUI using the public cluster IP and prompted in the chat, the model was not loading despite pulling the model in the ollama container. I troubleshooted the following areas:
	- Checked if ollama url is accessible from openwebui container - it was working and listing the model
	- Checked the openweb UI pod logs for the issue and found that it was trying to access ollama using the url, host.docker.internal:11434 and the error was 
	2025-10-05 09:59:52.845 | ERROR | open_webui.routers.ollama:send_get_request:106 - Connection error: Cannot connect to host host.docker.internal:11434 ssl:default [Name or service not known] 2025-10-05 09:59:52.848 | ERROR | open_webui.routers.ollama:send_get_request:106 - Connection error: Cannot connect to host host.docker.internal:11434 ssl:default [Name or service not known] 2025-10-05 09:59:53.130 | INFO | uvicorn.protocols.http.httptools_impl:send:476 - 10.224.0.4:59881 - "GET /api/models HTTP/1.1" 200
	- After multiple trial and error methods, updating the environmental variable - name: OLLAMA_BASE_URL with value: "http://ollama:11434" in the openwebui.yaml file fixed the problem. Earlier it was by default taking the value as /ollama and hence the issue.
	- Additionally the environmental variable - name: DEFAULT_MODEL was assigned with the value: "tinyllama:latest" as we have used that model for this assessment. By adding this openwebUI by default uses this model when prompted.

Technical debts:
	1. Using a B series model is not recommended for LLM models as it has insufficient resources
	2. Tinyllama model is specifically used only for testing purposes and is not recommended for prod use
	3. The environment variables in kubernetes manifests can be configured using configMaps for loading the enviornments during runtime. Here for every change in env, the deployment has to be restarted
	4. The RBAC contributor role for service principal account has been assigned to entire subscription to avoid any access issues from terraform
	5. A single node is used in the AKS cluster which will not support multiple LLM models due to less resources
	6. An ingress controller with a domain name has to be used to expose the openweb UI url to internet, but a public cluster IP is used here using a load balancer service
	7. No specific namespaces were created, but a default namespace is used for the pods which is not recommended








