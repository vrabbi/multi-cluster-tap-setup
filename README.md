# Production Ready Multi Cluster TAP Setup - On vSphere using TKGm
An easy way to setup Multi Cluster TAP on TKGm vSphere

What the script does:
1. Deploys 5 TKGm clusters (View, Build, Dev, QA, Prod)
2. Generates the TAP config files for each cluster with the appropriate profile data
3. Creates Contour TLS delegation CRDs to make sure all deployed apps are TLS secured by default
4. Deploys TAP in a multi cluster deployment
5. Configures TAP GUI and the Metadata Store for multi cluster support
6. Prepares the Default namespace in all clusters for TAP workloads
7. Applies overlays to give better experience with TAP including:
   * set HTTPS as default scheme for App URLs
   * Set HTTP to Redirect to HTTPS for App URLs
   * Set Scale to zero time to 15 minutes
   * Add Sidecar to TAP GUI to enable auto rendering of TechDocs
   * Add fix for PR flow bug in TAP 1.2 by changing the name of the PR TaskRun objects
  
Pre Reqs:
1. You need the TKGm 1.5.x Tanzu CLI installed with the TAP plugins added as well.
2. jq and yq must be installed
3. this currently requires to be run from a linux machine and not MacOS
4. a TKGm Management Cluster already exists
5. A Harbor registry or equivilant registry already exists for relocating packages and images to

Resource Requirements:  
* CPU: 144 vCPU
* RAM: 288 GB
* Storage: 1320 GB
  
Preperation:
1. Clone this repo
2. Copy the values.yaml.example to a new file values.yaml
   ```bash
   cp values.yaml.example values.yaml
   ```
3. fill in all of the fields in the values.yaml file as per the comments in the example file
4. make sure the script is executable
   ```bash
   chmod +x ./deploy-tap-multi-cluster.sh
   ```
5. run the script
   ```bash
   ./deploy-tap-multi-cluster.sh
   ```
Example Output:
```
##################################################
##################################################
################# Create Folders #################
##################################################
##################################################

Created Directory: /home/k8s/tap/tap-config-files/templates/tkg-cluster-configs
Created Directory: /home/k8s/tap/tap-config-files/templates/tap-cluster-configs
Created Directory: /home/k8s/tap/tap-config-files/templates/tkg-kubeconfigs
Created Directory: /home/k8s/tap/tap-config-files/templates/helper-files

##################################################
##################################################
################# Extract Values #################
##################################################
##################################################

Cluster names to be created: vrabbi-view, vrabbi-build, vrabbi-dev, vrabbi-qa, vrabbi-prod

##################################################
##################################################
############## Login To Registries ###############
##################################################
##################################################

WARNING! Your password will be stored unencrypted in /home/k8s/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
WARNING! Your password will be stored unencrypted in /home/k8s/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

##################################################
##################################################
################ Relocate TAP Repo ###############
##################################################
##################################################

Skipping as the repo already exists in the target registry

##################################################
##################################################
######### Render TKG Cluster Config Files ########
##################################################
##################################################

Cluster config files generated in the folder: /home/k8s/tap/tap-config-files/templates/tkg-cluster-configs/

##################################################
##################################################
############## Create TKG Clusters ###############
##################################################
##################################################

Validating configuration...
Validating configuration...
Creating workload cluster 'vrabbi-view'...
Creating workload cluster 'vrabbi-build'...
Waiting for cluster to be initialized...
cluster control plane is still being initialized: WaitingForControlPlane
Waiting for cluster to be initialized...
cluster control plane is still being initialized: WaitingForControlPlane
cluster control plane is still being initialized: ScalingUp
cluster control plane is still being initialized: ScalingUp
Waiting for cluster nodes to be available...
Waiting for cluster autoscaler to be available...
Waiting for addons installation...
Waiting for packages to be up and running...

Workload cluster 'vrabbi-build' created

Validating configuration...
Creating workload cluster 'vrabbi-dev'...
Waiting for cluster nodes to be available...
Waiting for cluster to be initialized...
cluster control plane is still being initialized: WaitingForControlPlane
cluster control plane is still being initialized: ScalingUp
Waiting for cluster autoscaler to be available...
Waiting for addons installation...
Waiting for packages to be up and running...

Workload cluster 'vrabbi-view' created

Validating configuration...
Creating workload cluster 'vrabbi-qa'...
Waiting for cluster to be initialized...
cluster control plane is still being initialized: WaitingForControlPlane
cluster control plane is still being initialized: ScalingUp
Waiting for cluster nodes to be available...
Waiting for cluster autoscaler to be available...
Waiting for addons installation...
Waiting for packages to be up and running...

Workload cluster 'vrabbi-dev' created

Validating configuration...
Creating workload cluster 'vrabbi-prod'...
Waiting for cluster to be initialized...
cluster control plane is still being initialized: WaitingForControlPlane
cluster control plane is still being initialized: ScalingUp
Waiting for cluster nodes to be available...
Waiting for cluster autoscaler to be available...
Waiting for addons installation...
Waiting for packages to be up and running...

Workload cluster 'vrabbi-qa' created

Waiting for cluster nodes to be available...
Waiting for cluster autoscaler to be available...
Waiting for addons installation...
Waiting for packages to be up and running...

Workload cluster 'vrabbi-prod' created

All TKG Clusters have been created

##################################################
##################################################
######## Retrieve TKG Cluster Kubeconfigs ########
##################################################
##################################################
Credentials of cluster 'vrabbi-view' have been saved
You can now access the cluster by running 'kubectl config use-context vrabbi-view-admin@vrabbi-view' under path 'tkg-kubeconfigs/view.kubeconfig'
Credentials of cluster 'vrabbi-build' have been saved
You can now access the cluster by running 'kubectl config use-context vrabbi-build-admin@vrabbi-build' under path 'tkg-kubeconfigs/build.kubeconfig'
Credentials of cluster 'vrabbi-dev' have been saved
You can now access the cluster by running 'kubectl config use-context vrabbi-dev-admin@vrabbi-dev' under path 'tkg-kubeconfigs/dev.kubeconfig'
Credentials of cluster 'vrabbi-qa' have been saved
You can now access the cluster by running 'kubectl config use-context vrabbi-qa-admin@vrabbi-qa' under path 'tkg-kubeconfigs/qa.kubeconfig'
Credentials of cluster 'vrabbi-prod' have been saved
You can now access the cluster by running 'kubectl config use-context vrabbi-prod-admin@vrabbi-prod' under path 'tkg-kubeconfigs/prod.kubeconfig'

##################################################
##################################################
################ Get Cert Details ################
##################################################
##################################################

Cert files have been built based on values.yaml config

##################################################
##################################################
############ Create Wildcard Secrets #############
##################################################
##################################################

secret/wildcard created
secret/wildcard created
secret/wildcard created
secret/wildcard created
secret/wildcard created

##################################################
##################################################
######### Create Installation Namespace ##########
##################################################
##################################################

namespace/tap-install created
namespace/tap-install created
namespace/tap-install created
namespace/tap-install created
namespace/tap-install created

##################################################
##################################################
############# Create Registry Secret #############
##################################################
##################################################

Warning: By choosing --export-to-all-namespaces, given secret contents will be available to ALL users in ALL namespaces. Please ensure that included registry credentials allow only read-only access to the registry with minimal necessary scope.


| Adding registry secret 'tap-registry'...
 Added registry secret 'tap-registry' into namespace 'tap-install'
 Exported registry secret 'tap-registry' to all namespaces
Warning: By choosing --export-to-all-namespaces, given secret contents will be available to ALL users in ALL namespaces. Please ensure that included registry credentials allow only read-only access to the registry with minimal necessary scope.


| Adding registry secret 'tap-registry'...
 Added registry secret 'tap-registry' into namespace 'tap-install'
 Exported registry secret 'tap-registry' to all namespaces
Warning: By choosing --export-to-all-namespaces, given secret contents will be available to ALL users in ALL namespaces. Please ensure that included registry credentials allow only read-only access to the registry with minimal necessary scope.


| Adding registry secret 'tap-registry'...
 Added registry secret 'tap-registry' into namespace 'tap-install'
 Exported registry secret 'tap-registry' to all namespaces
Warning: By choosing --export-to-all-namespaces, given secret contents will be available to ALL users in ALL namespaces. Please ensure that included registry credentials allow only read-only access to the registry with minimal necessary scope.


| Adding registry secret 'tap-registry'...
 Added registry secret 'tap-registry' into namespace 'tap-install'
 Exported registry secret 'tap-registry' to all namespaces
Warning: By choosing --export-to-all-namespaces, given secret contents will be available to ALL users in ALL namespaces. Please ensure that included registry credentials allow only read-only access to the registry with minimal necessary scope.


| Adding registry secret 'tap-registry'...
 Added registry secret 'tap-registry' into namespace 'tap-install'
 Exported registry secret 'tap-registry' to all namespaces

##################################################
##################################################
############# Add Package Repository #############
##################################################
##################################################


 Adding package repository 'tanzu-tap-repository'

 Validating provided settings for the package repository

 Creating package repository resource

Added package repository 'tanzu-tap-repository' in namespace 'tap-install'

 Adding package repository 'tanzu-tap-repository'

 Validating provided settings for the package repository

 Creating package repository resource

Added package repository 'tanzu-tap-repository' in namespace 'tap-install'

 Adding package repository 'tanzu-tap-repository'

 Validating provided settings for the package repository

 Creating package repository resource

Added package repository 'tanzu-tap-repository' in namespace 'tap-install'

 Adding package repository 'tanzu-tap-repository'

 Validating provided settings for the package repository

 Creating package repository resource

Added package repository 'tanzu-tap-repository' in namespace 'tap-install'

 Adding package repository 'tanzu-tap-repository'

 Validating provided settings for the package repository

 Creating package repository resource

Added package repository 'tanzu-tap-repository' in namespace 'tap-install'

##################################################
##################################################
########### Get TKG Cluster Endpoints ############
##################################################
##################################################

Cluster Endpoints are:
  View Cluster: https://10.100.232.19:6443
  Build Cluster: https://10.100.232.20:6443
  Dev Cluster: https://10.100.232.21:6443
  QA Cluster: https://10.100.232.22:6443
  Prod Cluster: https://10.100.232.24:6443

##################################################
##################################################
############### Update Values File ###############
##################################################
##################################################

Added Cluster Endpoints to the values.yaml file

##################################################
##################################################
############ Create TAP GUI Namespace ############
##################################################
##################################################

namespace/tap-gui created
namespace/tap-gui created
namespace/tap-gui created
namespace/tap-gui created

##################################################
##################################################
####### Create TAP GUI Multi Cluster RBAC ########
##################################################
##################################################

serviceaccount/tap-gui-viewer created
clusterrolebinding.rbac.authorization.k8s.io/tap-gui-read-k8s created
clusterrole.rbac.authorization.k8s.io/k8s-reader created
serviceaccount/tap-gui-viewer created
clusterrolebinding.rbac.authorization.k8s.io/tap-gui-read-k8s created
clusterrole.rbac.authorization.k8s.io/k8s-reader created
serviceaccount/tap-gui-viewer created
clusterrolebinding.rbac.authorization.k8s.io/tap-gui-read-k8s created
clusterrole.rbac.authorization.k8s.io/k8s-reader created
serviceaccount/tap-gui-viewer created
clusterrolebinding.rbac.authorization.k8s.io/tap-gui-read-k8s created
clusterrole.rbac.authorization.k8s.io/k8s-reader created

##################################################
##################################################
##### Get TAP GUI Multi Cluster Auth Tokens ######
##################################################
##################################################

Retrieved Service Account tokens from build and run clusters for TAP GUI integration

##################################################
##################################################
############### Update Values File ###############
##################################################
##################################################

Build and Run cluster Service Account tokens have been added to the values.yaml file.

##################################################
##################################################
############# Render TAP Config Files ############
##################################################
##################################################

TAP values files have been rendered for each cluster under the folder: /home/k8s/tap/tap-config-files/templates/tap-cluster-configs/

##################################################
##################################################
### Wait For Package Repository Reconciliation ###
##################################################
##################################################

packagerepository.packaging.carvel.dev/tanzu-tap-repository condition met
packagerepository.packaging.carvel.dev/tanzu-tap-repository condition met
packagerepository.packaging.carvel.dev/tanzu-tap-repository condition met
packagerepository.packaging.carvel.dev/tanzu-tap-repository condition met
packagerepository.packaging.carvel.dev/tanzu-tap-repository condition met

##################################################
##################################################
########## Install TAP in View Cluster ###########
##################################################
##################################################


 Installing package 'tap.tanzu.vmware.com'

 Getting package metadata for 'tap.tanzu.vmware.com'

 Creating service account 'tap-tap-install-sa'

 Creating cluster admin role 'tap-tap-install-cluster-role'

 Creating cluster role binding 'tap-tap-install-cluster-rolebinding'

 Creating secret 'tap-tap-install-values'

 Creating package resource


 Added installed package 'tap'
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP
Waiting for Contour to be given an IP

##################################################
##################################################
########## Prompt for User confirmation ##########
##################################################
##################################################

To Proceed you must register the View Cluster Wildcard DNS record with the following details:
Domain Name: *.tkg.vrabbi.cloud
IP Address: 10.100.232.25
Press any key to continue once the record is created
waiting for the keypress
waiting for the keypress
waiting for the keypress
waiting for the keypress
waiting for the keypress

##################################################
##################################################
##### Retrieve Metadata Store Cert and Token #####
##################################################
##################################################

Retrieved Auth Token and CA Cert of Metadata store from View Cluster

##################################################
##################################################
#### Add Metadata Store Creds to Build Cluster ###
##################################################
##################################################

namespace/metadata-store-secrets created
secret/store-ca-cert created
secret/store-auth-token created

##################################################
##################################################
###### Create Metadata Store Secret Exports ######
##################################################
##################################################

secretexport.secretgen.carvel.dev/store-ca-cert created
secretexport.secretgen.carvel.dev/store-auth-token created

##################################################
##################################################
#### Begin TAP Install on Remaining Clusters #####
##################################################
##################################################


 Installing package 'tap.tanzu.vmware.com'

 Getting package metadata for 'tap.tanzu.vmware.com'

 Creating service account 'tap-tap-install-sa'

 Creating cluster admin role 'tap-tap-install-cluster-role'

 Creating cluster role binding 'tap-tap-install-cluster-rolebinding'

 Creating secret 'tap-tap-install-values'

 Creating package resource


 Added installed package 'tap'

 Installing package 'tap.tanzu.vmware.com'

 Getting package metadata for 'tap.tanzu.vmware.com'

 Creating service account 'tap-tap-install-sa'

 Creating cluster admin role 'tap-tap-install-cluster-role'

 Creating cluster role binding 'tap-tap-install-cluster-rolebinding'

 Creating secret 'tap-tap-install-values'

 Creating package resource


 Added installed package 'tap'

 Installing package 'tap.tanzu.vmware.com'

 Getting package metadata for 'tap.tanzu.vmware.com'

 Creating service account 'tap-tap-install-sa'

 Creating cluster admin role 'tap-tap-install-cluster-role'

 Creating cluster role binding 'tap-tap-install-cluster-rolebinding'

 Creating secret 'tap-tap-install-values'

 Creating package resource


 Added installed package 'tap'

 Installing package 'tap.tanzu.vmware.com'

 Getting package metadata for 'tap.tanzu.vmware.com'

 Creating service account 'tap-tap-install-sa'

 Creating cluster admin role 'tap-tap-install-cluster-role'

 Creating cluster role binding 'tap-tap-install-cluster-rolebinding'

 Creating secret 'tap-tap-install-values'

 Creating package resource


 Added installed package 'tap'

##################################################
##################################################
##### Create TLS Delegation in Run Clusters ######
##################################################
##################################################

Waiting for Contour CRDs to be present in the clusters to proceed

tlscertificatedelegation.projectcontour.io/wildcards created
tlscertificatedelegation.projectcontour.io/wildcards created
tlscertificatedelegation.projectcontour.io/wildcards created

##################################################
##################################################
###### Waiting For TAP Install to Complete #######
##################################################
##################################################

packageinstall.packaging.carvel.dev/tap condition met
packageinstall.packaging.carvel.dev/tap condition met
packageinstall.packaging.carvel.dev/tap condition met
packageinstall.packaging.carvel.dev/tap condition met
packageinstall.packaging.carvel.dev/tap condition met

##################################################
##################################################
### Prepare Default NS for TAP in All Clusters ###
##################################################
##################################################

| Adding registry secret 'registry-credentials'...
 Added registry secret 'registry-credentials' into namespace 'default'
/ Adding registry secret 'registry-credentials'...
 Added registry secret 'registry-credentials' into namespace 'default'
- Adding registry secret 'registry-credentials'...
 Added registry secret 'registry-credentials' into namespace 'default'
/ Adding registry secret 'registry-credentials'...
 Added registry secret 'registry-credentials' into namespace 'default'
secret/tap-registry created
Warning: resource serviceaccounts/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
serviceaccount/default configured
role.rbac.authorization.k8s.io/default created
rolebinding.rbac.authorization.k8s.io/default created
secret/tap-registry created
Warning: resource serviceaccounts/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
serviceaccount/default configured
role.rbac.authorization.k8s.io/default created
rolebinding.rbac.authorization.k8s.io/default created
secret/tap-registry created
Warning: resource serviceaccounts/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
serviceaccount/default configured
role.rbac.authorization.k8s.io/default created
rolebinding.rbac.authorization.k8s.io/default created
secret/tap-registry created
Warning: resource serviceaccounts/default is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
serviceaccount/default configured
role.rbac.authorization.k8s.io/default created
rolebinding.rbac.authorization.k8s.io/default created

##################################################
##################################################
####### Multi Cluster TAP Install Complete #######
##################################################
##################################################

Script Runtime: 0:35:52 (hh:mm:ss)
```
