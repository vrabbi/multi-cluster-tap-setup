#!/bin/bash
start=`date +%s`
cp values.yaml values.yaml.original
echo "##################################################"
echo "##################################################"
echo "################# Create Folders #################"
echo "##################################################"
echo "##################################################"
mkdir tkg-cluster-configs
mkdir tap-cluster-configs
mkdir tkg-kubeconfigs
mkdir helper-files
echo ""
echo "Created Directory: `pwd`/tkg-cluster-configs"
echo "Created Directory: `pwd`/tap-cluster-configs"
echo "Created Directory: `pwd`/tkg-kubeconfigs"
echo "Created Directory: `pwd`/helper-files"
echo ""
echo "##################################################"
echo "##################################################"
echo "################# Extract Values #################"
echo "##################################################"
echo "##################################################"
VIEW_CLS_NAME=`cat values.yaml | yq .clusters.view_cluster.k8s_info.name`
BUILD_CLS_NAME=`cat values.yaml | yq .clusters.build_cluster.k8s_info.name`
DEV_CLS_NAME=`cat values.yaml | yq .clusters.dev_cluster.k8s_info.name`
QA_CLS_NAME=`cat values.yaml | yq .clusters.qa_cluster.k8s_info.name`
PROD_CLS_NAME=`cat values.yaml | yq .clusters.prod_cluster.k8s_info.name`

HARBOR_REGISTRY=`cat values.yaml | yq .harbor.fqdn`
HARBOR_PROJECT=`cat values.yaml | yq .harbor.system_project`
TAP_VERSION=`cat values.yaml | yq .version`
HARBOR_USER=`cat values.yaml | yq .harbor.user`
HARBOR_PASSWORD=`cat values.yaml | yq .harbor.password`
TANZUNET_USER=`cat values.yaml | yq .tanzunet.user`
TANZUNET_PASSWORD=`cat values.yaml | yq .tanzunet.password`
echo ""
echo "Cluster names to be created: $VIEW_CLS_NAME, $BUILD_CLS_NAME, $DEV_CLS_NAME, $QA_CLS_NAME, $PROD_CLS_NAME"
echo ""
echo "##################################################"
echo "##################################################"
echo "############## Login To Registries ###############"
echo "##################################################"
echo "##################################################"
echo ""
echo $HARBOR_PASSWORD | docker login --username $HARBOR_USER --password-stdin $HARBOR_REGISTRY
echo $TANZUNET_PASSWORD | docker login --username $TANZUNET_USER --password-stdin registry.tanzu.vmware.com
echo ""
echo "##################################################"
echo "##################################################"
echo "################ Relocate TAP Repo ###############"
echo "##################################################"
echo "##################################################"
echo ""
docker manifest inspect $HARBOR_REGISTRY/$HARBOR_PROJECT/tap-packages:$TAP_VERSION > /dev/null 2>/dev/null
if [[ $? == 0 ]]; then
  echo "Skipping as the repo already exists in the target registry"
else
  echo "Relocating TAP Packages and images now to: $HARBOR_REGISTRY/$HARBOR_PROJECT/tap-packages:$TAP_VERSION"
  imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION --to-repo $HARBOR_REGISTRY/$HARBOR_PROJECT/tap-packages
fi
echo ""
echo "##################################################"
echo "##################################################"
echo "######### Render TKG Cluster Config Files ########"
echo "##################################################"
echo "##################################################"
echo ""
ytt -f values.yaml -f tkg-cluster-templates/view.yaml > tkg-cluster-configs/view.yaml
ytt -f values.yaml -f tkg-cluster-templates/build.yaml > tkg-cluster-configs/build.yaml
ytt -f values.yaml -f tkg-cluster-templates/dev.yaml > tkg-cluster-configs/dev.yaml
ytt -f values.yaml -f tkg-cluster-templates/qa.yaml > tkg-cluster-configs/qa.yaml
ytt -f values.yaml -f tkg-cluster-templates/prod.yaml > tkg-cluster-configs/prod.yaml
echo "Cluster config files generated in the folder: `pwd`/tkg-cluster-configs/"
echo ""
echo "##################################################"
echo "##################################################"
echo "############## Create TKG Clusters ###############"
echo "##################################################"
echo "##################################################"
echo ""
echo 'tkg-cluster-configs/view.yaml tkg-cluster-configs/build.yaml tkg-cluster-configs/dev.yaml tkg-cluster-configs/qa.yaml tkg-cluster-configs/prod.yaml' | xargs -n 1 -P 2 tanzu cluster create -f
echo "All TKG Clusters have been created"
echo ""
echo "##################################################"
echo "##################################################"
echo "######## Retrieve TKG Cluster Kubeconfigs ########"
echo "##################################################"
echo "##################################################"
tanzu cluster kubeconfig get --admin $VIEW_CLS_NAME --export-file tkg-kubeconfigs/view.kubeconfig
tanzu cluster kubeconfig get --admin $BUILD_CLS_NAME --export-file tkg-kubeconfigs/build.kubeconfig
tanzu cluster kubeconfig get --admin $DEV_CLS_NAME --export-file tkg-kubeconfigs/dev.kubeconfig
tanzu cluster kubeconfig get --admin $QA_CLS_NAME --export-file tkg-kubeconfigs/qa.kubeconfig
tanzu cluster kubeconfig get --admin $PROD_CLS_NAME --export-file tkg-kubeconfigs/prod.kubeconfig
tanzu cluster kubeconfig get --admin $VIEW_CLS_NAME 1>/dev/null 2>/dev/null
tanzu cluster kubeconfig get --admin $BUILD_CLS_NAME 1>/dev/null 2>/dev/null
tanzu cluster kubeconfig get --admin $DEV_CLS_NAME 1>/dev/null 2>/dev/null
tanzu cluster kubeconfig get --admin $QA_CLS_NAME 1>/dev/null 2>/dev/null
tanzu cluster kubeconfig get --admin $PROD_CLS_NAME 1>/dev/null 2>/dev/null

generate_cert=`cat values.yaml | yq .tls.generate`
if [[ "$generate_cert" == "true" ]]; then
  echo ""
  echo "##################################################"
  echo "##################################################"
  echo "####### Generate Self Signed Wildcard Cert #######"
  echo "##################################################"
  echo "##################################################"
  echo ""
  VIEW_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.view_cluster.ingressDomain`
  DEV_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.dev_cluster.ingressDomain`
  QA_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.qa_cluster.ingressDomain`
  PROD_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.prod_cluster.ingressDomain`
  cat <<EOF > req.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = IL
ST = IL
O = vRabbi
localityName = Jerusalem
commonName = *.$VIEW_CLS_ING_DOMAIN
organizationalUnitName = Lab
emailAddress = john.doe@example.com
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1   = *.$VIEW_CLS_ING_DOMAIN
DNS.2   = *.$DEV_CLS_ING_DOMAIN
DNS.3   = *.$QA_CLS_ING_DOMAIN
DNS.4   = *.$PROD_CLS_ING_DOMAIN
EOF
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "wildcard.key" -config req.cnf -out "wildcard.cer" -sha256
  rm req.cnf
  yq -i '.tls.certData = "' `cat wildcard.cer | base64 -w 0` '"' values.yaml
  yq -i '.tls.keyData = "' `cat wildcard.key | base64 -w 0` '"' values.yaml
else
  echo ""
  echo "##################################################"
  echo "##################################################"
  echo "################ Get Cert Details ################"
  echo "##################################################"
  echo "##################################################"
  echo ""
  cat values.yaml | yq .tls.certData | base64 --decode > wildcard.cer
  cat values.yaml | yq .tls.keyData | base64 --decode > wildcard.key
  echo "Cert files have been built based on values.yaml config"
fi
echo ""
echo "##################################################"
echo "##################################################"
echo "############ Create Wildcard Secrets #############"
echo "##################################################"
echo "##################################################"
echo ""
kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/view.kubeconfig
kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/build.kubeconfig
kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/dev.kubeconfig
kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/qa.kubeconfig
kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/prod.kubeconfig
echo ""
echo "##################################################"
echo "##################################################"
echo "######### Create Installation Namespace ##########"
echo "##################################################"
echo "##################################################"
echo ""
kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig create ns tap-install
kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create ns tap-install
kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create ns tap-install
kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create ns tap-install
kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create ns tap-install
echo ""
echo "##################################################"
echo "##################################################"
echo "############# Create Registry Secret #############"
echo "##################################################"
echo "##################################################"
echo ""
tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/view.kubeconfig
tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/build.kubeconfig
tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/dev.kubeconfig
tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/qa.kubeconfig
tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/prod.kubeconfig
echo ""
echo "##################################################"
echo "##################################################"
echo "############# Add Package Repository #############"
echo "##################################################"
echo "##################################################"
echo ""
PKGR_URL="$HARBOR_REGISTRY/$HARBOR_PROJECT/tap-packages:$TAP_VERSION"
tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/view.kubeconfig
tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/build.kubeconfig
tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/dev.kubeconfig
tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/qa.kubeconfig
tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/prod.kubeconfig
echo ""
echo "##################################################"
echo "##################################################"
echo "########### Get TKG Cluster Endpoints ############"
echo "##################################################"
echo "##################################################"
echo ""
VIEW_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
BUILD_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
DEV_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
QA_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
PROD_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
cat <<EOF 
Cluster Endpoints are:
  View Cluster: $VIEW_CLS_ENDPOINT
  Build Cluster: $BUILD_CLS_ENDPOINT
  Dev Cluster: $DEV_CLS_ENDPOINT
  QA Cluster: $QA_CLS_ENDPOINT
  Prod Cluster: $PROD_CLS_ENDPOINT
EOF
echo ""
echo "##################################################"
echo "##################################################"
echo "############### Update Values File ###############"
echo "##################################################"
echo "##################################################"
echo ""
yq -i '.clusters.view_cluster.k8s_info.url = "'$VIEW_CLS_ENDPOINT'"' values.yaml
yq -i '.clusters.build_cluster.k8s_info.url = "'$BUILD_CLS_ENDPOINT'"' values.yaml
yq -i '.clusters.dev_cluster.k8s_info.url = "'$DEV_CLS_ENDPOINT'"' values.yaml
yq -i '.clusters.qa_cluster.k8s_info.url = "'$QA_CLS_ENDPOINT'"' values.yaml
yq -i '.clusters.prod_cluster.k8s_info.url = "'$PROD_CLS_ENDPOINT'"' values.yaml
echo "Added Cluster Endpoints to the values.yaml file"
echo ""
echo "##################################################"
echo "##################################################"
echo "############ Create TAP GUI Namespace ############"
echo "##################################################"
echo "##################################################"
echo ""
kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create ns tap-gui
kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create ns tap-gui
kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create ns tap-gui
kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create ns tap-gui
echo ""
echo "##################################################"
echo "##################################################"
echo "####### Create TAP GUI Multi Cluster RBAC ########"
echo "##################################################"
echo "##################################################"
echo ""
cat << EOF > tap-gui-viewer-service-account-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
- kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
- apiGroups: ['']
  resources: ['pods', 'services', 'configmaps']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['apps']
  resources: ['deployments', 'replicasets']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['autoscaling']
  resources: ['horizontalpodautoscalers']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.k8s.io']
  resources: ['ingresses']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.internal.knative.dev']
  resources: ['serverlessservices']
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'autoscaling.internal.knative.dev' ]
  resources: [ 'podautoscalers' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['serving.knative.dev']
  resources:
  - configurations
  - revisions
  - routes
  - services
  verbs: ['get', 'watch', 'list']
- apiGroups: ['carto.run']
  resources:
  - clusterconfigtemplates
  - clusterdeliveries
  - clusterdeploymenttemplates
  - clusterimagetemplates
  - clusterruntemplates
  - clustersourcetemplates
  - clustersupplychains
  - clustertemplates
  - deliverables
  - runnables
  - workloads
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.toolkit.fluxcd.io']
  resources:
  - gitrepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.apps.tanzu.vmware.com']
  resources:
  - imagerepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.apps.tanzu.vmware.com']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kpack.io']
  resources:
  - images
  - builds
  verbs: ['get', 'watch', 'list']
- apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
- apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  verbs: ['get', 'watch', 'list']
EOF

kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
mv tap-gui-viewer-service-account-rbac.yaml helper-files/
echo ""
echo "##################################################"
echo "##################################################"
echo "##### Get TAP GUI Multi Cluster Auth Tokens ######"
echo "##################################################"
echo "##################################################"
echo ""
BUILD_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig  -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
DEV_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
QA_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
PROD_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
echo "Retrieved Service Account tokens from build and run clusters for TAP GUI integration"
echo ""
echo "##################################################"
echo "##################################################"
echo "############### Update Values File ###############"
echo "##################################################"
echo "##################################################"
echo ""
yq -i '.clusters.build_cluster.k8s_info.saToken = "'$BUILD_CLS_SA_TOKEN'"' values.yaml
yq -i '.clusters.dev_cluster.k8s_info.saToken = "'$DEV_CLS_SA_TOKEN'"' values.yaml
yq -i '.clusters.qa_cluster.k8s_info.saToken = "'$QA_CLS_SA_TOKEN'"' values.yaml
yq -i '.clusters.prod_cluster.k8s_info.saToken = "'$PROD_CLS_SA_TOKEN'"' values.yaml
echo "Build and Run cluster Service Account tokens have been added to the values.yaml file."
echo ""
echo "##################################################"
echo "##################################################"
echo "############# Render TAP Config Files ############"
echo "##################################################"
echo "##################################################"
echo ""
ytt -f values.yaml -f tap-config-templates/view.yaml > tap-cluster-configs/view.yaml
ytt -f values.yaml -f tap-config-templates/build.yaml > tap-cluster-configs/build.yaml
ytt -f values.yaml -f tap-config-templates/dev.yaml > tap-cluster-configs/dev.yaml
ytt -f values.yaml -f tap-config-templates/qa.yaml > tap-cluster-configs/qa.yaml
ytt -f values.yaml -f tap-config-templates/prod.yaml > tap-cluster-configs/prod.yaml
echo "TAP values files have been rendered for each cluster under the folder: `pwd`/tap-cluster-configs/"
echo ""
echo "##################################################"
echo "##################################################"
echo "### Wait For Package Repository Reconciliation ###"
echo "##################################################"
echo "##################################################"
echo ""
kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/view.kubeconfig --timeout=5m
kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/build.kubeconfig --timeout=5m
kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/dev.kubeconfig --timeout=5m
kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/qa.kubeconfig --timeout=5m
kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/prod.kubeconfig --timeout=5m
echo ""
echo "##################################################"
echo "##################################################"
echo "########## Install TAP in View Cluster ###########"
echo "##################################################"
echo "##################################################"
echo ""
tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/view.yaml --kubeconfig tkg-kubeconfigs/view.kubeconfig --wait=false
until [ -n "$(kubectl get svc -n tanzu-system-ingress envoy --kubeconfig tkg-kubeconfigs/view.kubeconfig -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)" ]; do
    echo "Waiting for Contour to be given an IP"
    sleep 10
done
echo ""
echo "##################################################"
echo "##################################################"
echo "########## Prompt for User confirmation ##########"
echo "##################################################"
echo "##################################################"
echo ""
echo "To Proceed you must register the View Cluster Wildcard DNS record with the following details:"
VIEW_CLS_INGRESS_IP=`kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig get service -n tanzu-system-ingress envoy -o json | jq -r .status.loadBalancer.ingress[0].ip`
VIEW_CLS_INGRESS_DOMAIN=`cat values.yaml | yq .clusters.view_cluster.ingressDomain`
echo "Domain Name: *.$VIEW_CLS_INGRESS_DOMAIN"
echo "IP Address: $VIEW_CLS_INGRESS_IP"
echo "Press any key to continue once the record is created"
while [ true ] ; do
read -t 3 -n 1
if [ $? = 0 ] ; then
break
else
echo "waiting for the keypress"
fi
done
echo ""
echo "##################################################"
echo "##################################################"
echo "##### Retrieve Metadata Store Cert and Token #####"
echo "##################################################"
echo "##################################################"
echo ""
CA_CERT=$(kubectl get secret --kubeconfig tkg-kubeconfigs/view.kubeconfig -n metadata-store ingress-cert -o json | jq -r ".data.\"ca.crt\"")
AUTH_TOKEN=$(kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig get secrets -n metadata-store -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='metadata-store-read-write-client')].data.token}" | base64 -d)
echo "Retrieved Auth Token and CA Cert of Metadata store from View Cluster"
echo ""
echo "##################################################"
echo "##################################################"
echo "#### Add Metadata Store Creds to Build Cluster ###"
echo "##################################################"
echo "##################################################"
echo ""
cat <<EOF > store_ca.yaml
---
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: store-ca-cert
  namespace: metadata-store-secrets
data:
  ca.crt: $CA_CERT
  tls.crt: ""
  tls.key: ""
EOF
kubectl create ns metadata-store-secrets --kubeconfig tkg-kubeconfigs/build.kubeconfig
kubectl apply -f store_ca.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
mv store_ca.yaml helper-files/

kubectl create secret generic store-auth-token --from-literal=auth_token=$AUTH_TOKEN -n metadata-store-secrets --kubeconfig tkg-kubeconfigs/build.kubeconfig
echo ""
echo "##################################################"
echo "##################################################"
echo "###### Create Metadata Store Secret Exports ######"
echo "##################################################"
echo "##################################################"
echo ""
cat <<EOF > store_secrets_export.yaml
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: store-ca-cert
  namespace: metadata-store-secrets
spec:
  toNamespace: scan-link-system
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: store-auth-token
  namespace: metadata-store-secrets
spec:
  toNamespace: scan-link-system
EOF
kubectl apply -f store_secrets_export.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
mv store_secrets_export.yaml helper-files/
echo ""
echo "##################################################"
echo "##################################################"
echo "#### Begin TAP Install on Remaining Clusters #####"
echo "##################################################"
echo "##################################################"
echo ""
tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/build.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig --wait=false
tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/dev.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig --wait=false
tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/qa.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig --wait=false
tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/prod.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig --wait=false
echo ""
echo "##################################################"
echo "##################################################"
echo "##### Create TLS Delegation in Run Clusters ######"
echo "##################################################"
echo "##################################################"
echo ""
echo "Waiting for Contour CRDs to be present in the clusters to proceed"
echo ""
cat <<EOF >> tls-delegation.yaml
apiVersion: projectcontour.io/v1
kind: TLSCertificateDelegation
metadata:
  name: wildcards
  namespace: kube-system
spec:
  delegations:
  - secretName: wildcard
    targetNamespaces: ["*"]
EOF

{ sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/dev.kubeconfig)
kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig

{ sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/qa.kubeconfig)
kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig
	
{ sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/prod.kubeconfig)
kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig

mv tls-delegation.yaml helper-files/
echo ""
echo "##################################################"
echo "##################################################"
echo "###### Waiting For TAP Install to Complete #######"
echo "##################################################"
echo "##################################################"
echo ""
kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/view.kubeconfig --timeout=15m
kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/build.kubeconfig --timeout=15m
kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/dev.kubeconfig --timeout=15m
kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/qa.kubeconfig --timeout=15m
kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/prod.kubeconfig --timeout=15m
echo "##################################################"
echo "##################################################"
echo "### Prepare Default NS for TAP in All Clusters ###"
echo "##################################################"
echo "##################################################"
echo ""
tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/build.kubeconfig
tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/dev.kubeconfig
tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/qa.kubeconfig
tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/prod.kubeconfig

kubectl apply -f dev-ns-prep-files/ --kubeconfig tkg-kubeconfigs/build.kubeconfig -n default
kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n default
kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n default
kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n default

echo ""
echo "##################################################"
echo "##################################################"
echo "####### Multi Cluster TAP Install Complete #######"
echo "##################################################"
echo "##################################################"
end=`date +%s`
runtime=$((end-start))
hours=$((runtime / 3600))
minutes=$(( (runtime % 3600) / 60 ))
seconds=$(( (runtime % 3600) % 60 ))
echo ""
echo "Script Runtime: $hours:$minutes:$seconds (hh:mm:ss)"
