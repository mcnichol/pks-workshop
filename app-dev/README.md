## Pivotal Container Service Workshop
This is a sample SpringBoot application that performs Geo Bounded queries against an Elasticsearch instance and plots the data on a map interactively. This application can be run on a workstation or in a cloud environment such as Cloud Foundry. In this example, I will show how to deploy the application on a running Cloud Foundry instance.
<!-- TOC depthFrom:3 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [1. Install and Setup CLIs](#1-install-and-setup-clis)
	- [Install PKS CLI](#install-pks-cli)
	- [Install kubectl CLI](#install-kubectl-cli)
- [2. Lab Exercise: Set Environment Variables](#2-lab-exercise-set-environment-variables)
- [3. Cluster Access and Validation](#3-cluster-access-and-validation)
	- [Get Cluster Credentials](#get-cluster-credentials)
	- [Validating your Cluster](#validating-your-cluster)
	- [Accessing the Dashboard](#accessing-the-dashboard)
- [4. Lab Exercise: Deploy a Spring Boot application with an Elasticsearch Backend](#4-lab-exercise-deploy-a-springboot-application-with-an-elastic-search-backend)

<!-- /TOC -->
### 1. Install and Setup CLIs
#### Install PKS CLI
In order to install the PKS CLI please follow these instructions: https://docs.pivotal.io/runtimes/pks/1-2/installing-pks-cli.html#windows. Note, you will need to register with network.pivotal.io in order to download the CLI.

Download from: https://network.pivotal.io/products/pivotal-container-service/

#### Install kubectl CLI
You can install the kubectl CLI from PivNet as well, https://network.pivotal.io/products/pivotal-container-service

What you download is the executable. After downloading, rename the file to `kubectl`, move it to where you like and make sure it's in your path.

#### Alternatively
You can leverage the pks-cli and kubectl-cli that are in the `bin/` folder of this repository.

### 2. Lab Exercise: Set Environment Variables
Prerequisite: Initialize the environment with required access variables. Please use the account and user that was provided to you for this lab exercise.

Unix/Mac
<pre>
export MY_USER=[ 'userX' that you were supplied with ]
export HARBOR_REGISTRY_URL="$MY_USER.harbor.mcnichol.rocks"
export HARBOR_USERNAME="admin"
export HARBOR_PASSWORD="password"
export HARBOR_EMAIL="admin@example.com"
</pre>

Windows PowerShell
<pre>
$env:MY_USER=[ 'userX' that you were supplied with ]
$env:HARBOR_REGISTRY_URL="$MY_USER.harbor.mcnichol.rocks"
$env:HARBOR_USERNAME="admin"
$env:HARBOR_PASSWORD="password"
$env:HARBOR_EMAIL="admin@example.com"
</pre>

### 3. Cluster Access and Validation
#### Get Cluster Credentials
You will need to retrieve the cluster credentials from PKS. First login using the the PKS credentials that were provided to you for this lab exercise.

<pre>pks login -a api.$MY_USER.pks.mcnichol.rocks -u $MY_USER -p password -k</pre>

Now you can retrive your Kubernetes cluster credentials. Please use the cluster name that was provided to you for this lab exercise.

<pre>pks get-credentials $MY_USER-cluster </pre>

#### Validating your Cluster
Ensure that you can access the API Endpoints on the Master
<pre>kubectl cluster-info</pre>

You should see something similar to the following:
<pre>
Kubernetes master is running at https://userX.cluster.mcnichol.rocks:8443
Heapster is running at https://userX.cluster.mcnichol.rocks:8443/api/v1/namespaces/kube-system/services/heapster/proxy
KubeDNS is running at https://userX.cluster.mcnichol.rocks:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
kubernetes-dashboard is running at https://userX.cluster.mcnichol.rocks:8443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy
monitoring-influxdb is running at https://userX.cluster.mcnichol.rocks:8443/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy
</pre>

#### Accessing the Dashboard

To access Dashboard from your local workstation you must create a secure channel to your Kubernetes cluster. Run the following command:

<pre>kubectl proxy</pre>

Now access the dashboard at:

http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/.

When prompted for choosing either the Kubeconfig or Token, choose Kubeconfig.  You will need to browse to `$HOME/.kube` and select the file named `config`.

*Note 1:* When deciding on a Web Browser you may want to use Firefox or Chrome as we have faced issues with Explorer.
*Note 2:* When using Mac you may need to hit `CMD` + `SHIFT` + `G` and enter `~/.kube/config` to access the hidden dot-folder.

### 4. Lab Exercise: Deploy A Spring Boot application with an Elasticsearch Backend
#### 1. *(Skip this step)* ~~Provision a StorageClass for the Cluster.~~ *This is provisioned at the Kubernetes cluster level and therefore no need to namespace qualify it*

<ul>GCP:
<pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_0_ProvisionStorageClass_GCP.yaml</pre>
</ul>


#### 2. *(Skip this Step)* ~~Create a user defined Namespace. Note: Update the command below to use the namespace that you are going to be delpoying into.~~
<ul>Unix/Mac
<pre>
kubectl create namespace geosearch-$(echo $USER_INDEX)
kubectl config set-context $(kubectl config current-context) --namespace=geosearch-$(echo $USER_INDEX)
</pre>
</ul>

<ul>Windows PowerShell
<pre>kubectl create namespace geosearch-$(echo $env:USER_INDEX)
kubectl config set-context $(kubectl config current-context) --namespace=geosearch-$(echo $env:USER_INDEX)
</pre></ul>


#### 3. Create Harbor Registry Secret. Use the Registry credentials that was provided to you for this step.
<ul>Unix/Mac
<pre>
kubectl create secret docker-registry harborsecret  \
  --docker-server="$HARBOR_REGISTRY_URL"  \
  --docker-username="$HARBOR_USERNAME"    \
  --docker-password="$HARBOR_PASSWORD"    \
  --docker-email="$HARBOR_EMAIL"
</pre>
</ul>

<ul>Windows PowerShell
<pre>
kubectl create secret docker-registry harborsecret    `
  --docker-server="$(echo $env:HARBOR_REGISTRY_URL)"  `
  --docker-username="$(echo $env:HARBOR_USERNAME)"    `
  --docker-password="$(echo $env:HARBOR_PASSWORD)"    `
  --docker-email="$(echo $env:HARBOR_EMAIL)"
</pre>
</ul>

*Note 1*: This can be verified that it was entered correctly using the following command:
<ul>Unix/Mac:
<pre>kubectl get secret harborsecret -o json | jq -r '.data.".dockerconfigjson"' | base64 --decode</pre> (<i>jq</i> is a json query tool which can be installed via homebrew)
</ul>
<ul>Windows PowerShell:
<pre>kubectl get secret harborsecret -o json</pre> (then decrypt the <i>.data.dockerconfigjson</i> section with a base64 decoder
</ul>

#### 4. Create a new Service Account and patch with the secret created in the previous step 
<ul>Unix/Mac
<pre>
kubectl create serviceaccount userserviceaccount
kubectl patch serviceaccount userserviceaccount -p "{\"imagePullSecrets\": [{\"name\": \"harborsecret\"}]}"
</pre>
</ul>

<ul>Windows PowerShell
<pre>
kubectl create serviceaccount userserviceaccount
kubectl patch serviceaccount userserviceaccount -p '{\"imagePullSecrets\": [{\"name\": \"harborsecret\"}]}'
</pre>
</ul>

#### 5. Create the Storage Volume
<ul><pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_1_ProvisionStorage.yaml</pre></ul>

#### 6. Deploy Elasticsearch
<ul><pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_2_DeployElasticsearch.yaml</pre></ul>

#### 7. Expose the Elasticsearch Service
<ul><pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_3_ExposeElasticsearch.yaml</pre></ul>

#### 8. Load the Data via a Job
<ul><pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_4_LoadData.yaml</pre></ul>

#### 9. Deploy the Spring Boot Geosearch Application
<ul><pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_5_DeploySpringBootApp.yaml</pre></ul>

#### 10. Expose the Spring Boot Application. This can be done in a couple of ways. We will look at two ways of doing it in this example.

<ul>Exposing with the LoadBalancer
<pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_6_ExposeSpringBootApp.yaml</pre>
</ul>

<ul>Exposing with the Ingress 
<pre>kubectl create -f https://raw.githubusercontent.com/mcnichol/pks-workshop/master/app-dev/Step_6_ExposeSpringBootAppIngress.yaml</pre>
</ul>

#### 11. Scale the Frontend
<ul><pre>kubectl scale deployment --replicas=3 geosearch</pre></ul>

## Notes:
The application can be seen running with the proxy enabled at:

Get POD_NAME by running the command:  `kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`

The Application POD can be accessed by entering the proxy url: `http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME/proxy/`

You can view logs from the application directly by accessing `kubectl logs $POD_NAME` 
*Note: If there is more than one container running inside a Pod you would need to specify it by name*

If we want to execute commands directly against our Pod we can use the command: `kubectl exec $POD_NAME env`. If you are familiar with Docker and grabbing hold of an interactive terminal, we can do the same thing here with the command: `kubectl exec -ti $POD_NAME sh`
