#!/bin/bash
start=`date +%s`
cp values.yaml values.yaml.original
CREATE_BUILD=`cat values.yaml | yq .clusters.build_cluster.enabled`
CREATE_QA=`cat values.yaml | yq .clusters.qa_cluster.enabled`
CREATE_DEV=`cat values.yaml | yq .clusters.dev_cluster.enabled`
CREATE_PROD=`cat values.yaml | yq .clusters.prod_cluster.enabled`
CREATE_ITERATE=`cat values.yaml | yq .clusters.iterate_cluster.enabled`
CREATE_VIEW=`cat values.yaml | yq .clusters.view_cluster.enabled`
if [[ $CREATE_VIEW == false ]]; then
   echo "ERROR: View Cluster is required"
   exit 1
fi
if [[ $CREATE_BUILD == false &&  $CREATE_ITERATE == false ]]; then
   echo "ERROR: Either a build or iterate cluster must be created"
   exit 1
fi
if [[ $CREATE_DEV == false &&  $CREATE_QA == false &&  $CREATE_PROD == false ]]; then
   echo "ERROR: At least one runtime cluster must be created"
   exit 1
fi

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
CLUSTERS_TO_CREATE=""
if [[ $CREATE_VIEW == true ]]; then
  VIEW_CLS_NAME=`cat values.yaml | yq .clusters.view_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $VIEW_CLS_NAME"
fi
if [[ $CREATE_BUILD == true ]]; then
  BUILD_CLS_NAME=`cat values.yaml | yq .clusters.build_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $BUILD_CLS_NAME"
fi
if [[ $CREATE_DEV == true ]]; then
  DEV_CLS_NAME=`cat values.yaml | yq .clusters.dev_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $DEV_CLS_NAME"
fi
if [[ $CREATE_QA == true ]]; then
  QA_CLS_NAME=`cat values.yaml | yq .clusters.qa_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $QA_CLS_NAME"
fi
if [[ $CREATE_PROD == true ]]; then
  PROD_CLS_NAME=`cat values.yaml | yq .clusters.prod_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $PROD_CLS_NAME"
fi
if [[ $CREATE_ITERATE == true ]]; then
  ITERATE_CLS_NAME=`cat values.yaml | yq .clusters.iterate_cluster.k8s_info.name`
  CLUSTERS_TO_CREATE="$CLUSTERS_TO_CREATE , $ITERATE_CLS_NAME"
fi

HARBOR_REGISTRY=`cat values.yaml | yq .harbor.fqdn`
HARBOR_PROJECT=`cat values.yaml | yq .harbor.system_project`
TAP_VERSION=`cat values.yaml | yq .version`
HARBOR_USER=`cat values.yaml | yq .harbor.user`
HARBOR_PASSWORD=`cat values.yaml | yq .harbor.password`
TANZUNET_USER=`cat values.yaml | yq .tanzunet.user`
TANZUNET_PASSWORD=`cat values.yaml | yq .tanzunet.password`
echo ""
echo "Cluster names to be created: $CLUSTERS_TO_CREATE"
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
if [[ $CREATE_VIEW == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/view.yaml > tkg-cluster-configs/view.yaml
fi
if [[ $CREATE_BUILD == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/build.yaml > tkg-cluster-configs/build.yaml
fi
if [[ $CREATE_DEV == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/dev.yaml > tkg-cluster-configs/dev.yaml
fi
if [[ $CREATE_QA == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/qa.yaml > tkg-cluster-configs/qa.yaml
fi
if [[ $CREATE_PROD == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/prod.yaml > tkg-cluster-configs/prod.yaml
fi
if [[ $CREATE_ITERATE == true ]]; then
   ytt -f values.yaml -f tkg-cluster-templates/iterate.yaml > tkg-cluster-configs/iterate.yaml
fi
echo "Cluster config files generated in the folder: `pwd`/tkg-cluster-configs/"
echo ""
echo "##################################################"
echo "##################################################"
echo "############## Create TKG Clusters ###############"
echo "##################################################"
echo "##################################################"
echo ""
TKG_CONFIG_PREFIX="tkg-cluster-configs"
TKG_CONFIG_LIST=""
if [[ $CREATE_VIEW == true ]]; then
   TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/view.yaml"
fi
if [[ $CREATE_BUILD == true ]]; then
  TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/build.yaml"
fi
if [[ $CREATE_DEV == true ]]; then
   TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/dev.yaml"
fi
if [[ $CREATE_QA == true ]]; then
   TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/qa.yaml"
fi
if [[ $CREATE_PROD == true ]]; then
   TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/prod.yaml"
fi
if [[ $CREATE_ITERATE == true ]]; then
   TKG_CONFIG_LIST="$TKG_CONFIG_LIST $TKG_CONFIG_PREFIX/iterate.yaml"
fi
echo "$TKG_CONFIG_LIST" | xargs -n 1 -P 2 tanzu cluster create -f
echo "All TKG Clusters have been created"
echo ""
echo "##################################################"
echo "##################################################"
echo "######## Retrieve TKG Cluster Kubeconfigs ########"
echo "##################################################"
echo "##################################################"
if [[ $CREATE_VIEW == true ]]; then
   tanzu cluster kubeconfig get --admin $VIEW_CLS_NAME --export-file tkg-kubeconfigs/view.kubeconfig
   tanzu cluster kubeconfig get --admin $VIEW_CLS_NAME 1>/dev/null 2>/dev/null
fi
if [[ $CREATE_BUILD == true ]]; then
   tanzu cluster kubeconfig get --admin $BUILD_CLS_NAME --export-file tkg-kubeconfigs/build.kubeconfig
   tanzu cluster kubeconfig get --admin $BUILD_CLS_NAME 1>/dev/null 2>/dev/null
fi
if [[ $CREATE_DEV == true ]]; then
   tanzu cluster kubeconfig get --admin $DEV_CLS_NAME --export-file tkg-kubeconfigs/dev.kubeconfig
   tanzu cluster kubeconfig get --admin $DEV_CLS_NAME 1>/dev/null 2>/dev/null
fi
if [[ $CREATE_QA == true ]]; then
   tanzu cluster kubeconfig get --admin $QA_CLS_NAME --export-file tkg-kubeconfigs/qa.kubeconfig
   tanzu cluster kubeconfig get --admin $QA_CLS_NAME 1>/dev/null 2>/dev/null
fi
if [[ $CREATE_PROD == true ]]; then
   tanzu cluster kubeconfig get --admin $PROD_CLS_NAME --export-file tkg-kubeconfigs/prod.kubeconfig
   tanzu cluster kubeconfig get --admin $PROD_CLS_NAME 1>/dev/null 2>/dev/null
fi
if [[ $CREATE_ITERATE == true ]]; then
   tanzu cluster kubeconfig get --admin $ITERATE_CLS_NAME --export-file tkg-kubeconfigs/iterate.kubeconfig
   tanzu cluster kubeconfig get --admin $ITERATE_CLS_NAME 1>/dev/null 2>/dev/null
fi

generate_cert=`cat values.yaml | yq .tls.generate`
if [[ "$generate_cert" == "true" ]]; then
  echo ""
  echo "##################################################"
  echo "##################################################"
  echo "####### Generate Self Signed Wildcard Cert #######"
  echo "##################################################"
  echo "##################################################"
  echo ""
  if [[ $CREATE_VIEW == true ]]; then
     VIEW_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.view_cluster.ingressDomain`
  fi
  if [[ $CREATE_DEV == true ]]; then
     DEV_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.dev_cluster.ingressDomain`
  fi
  if [[ $CREATE_QA == true ]]; then
     QA_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.qa_cluster.ingressDomain`
  fi
  if [[ $CREATE_PROD == true ]]; then
     PROD_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.prod_cluster.ingressDomain`
  fi
  if [[ $CREATE_ITERATE == true ]]; then
     ITERATE_CLS_ING_DOMAIN=`cat values.yaml | yq .clusters.iterate_cluster.ingressDomain`
  fi

  if [[ $CREATE_VIEW == false ]]; then
      if [[ $CREATE_ITERATE == false ]]; then
         if [[ $CREATE_DEV == false ]]; then
            if [[ $CREATE_QA == false ]]; then
                if [[ $CREATE_PROD == false ]]; then
                   echo "Cannot Generate Cert as no clusters have been enabled with cert generation capabilities"
                   exit 1
                else
                   PRIMARY_CN="$PROD_CLS_ING_DOMAIN"
                fi
            else
               PRIMARY_CN="$QA_CLS_ING_DOMAIN"
            fi
         else
            PRIMARY_CN="$DEV_CLS_ING_DOMAIN"
         fi
      else
         PRIMARY_CN="$ITERATE_CLS_ING_DOMAIN"
      fi
  else
     PRIMARY_CN="$VIEW_CLS_ING_DOMAIN"
  fi
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
commonName = *.$PRIMARY_CN
organizationalUnitName = Lab
emailAddress = john.doe@example.com
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
EOF
  i=1
  if [[ $CREATE_VIEW == true ]]; then
     echo "DNS.$i = *.$VIEW_CLS_ING_DOMAIN" >> req.cnf
     ((i++))
  fi
  if [[ $CREATE_DEV == true ]]; then
     echo "DNS.$i = *.$DEV_CLS_ING_DOMAIN" >> req.cnf
     ((i++))
  fi
  if [[ $CREATE_QA == true ]]; then
     echo "DNS.$i = *.$QA_CLS_ING_DOMAIN" >> req.cnf
     ((i++))
  fi
  if [[ $CREATE_PROD == true ]]; then
     echo "DNS.$i = *.$PROD_CLS_ING_DOMAIN" >> req.cnf
     ((i++))
  fi
  if [[ $CREATE_ITERATE == true ]]; then
     echo "DNS.$i = *.$ITERATE_CLS_ING_DOMAIN" >> req.cnf
     ((i++))
  fi
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "wildcard.key" -config req.cnf -out "wildcard.cer" -sha256
  rm req.cnf
  yq -i ".tls.certData = \"`cat wildcard.cer | base64 -w 0`\"" values.yaml
  yq -i ".tls.keyData = \"`cat wildcard.key | base64 -w 0`\"" values.yaml
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
if [[ $CREATE_VIEW == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/view.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/view.kubeconfig -f -
fi
if [[ $CREATE_BUILD == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/build.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/build.kubeconfig -f -
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/dev.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/dev.kubeconfig -f -
fi
if [[ $CREATE_QA == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/qa.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/qa.kubeconfig -f -
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/prod.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/prod.kubeconfig -f -
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl create secret tls wildcard -n kube-system --cert=wildcard.cer --key=wildcard.key --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --dry-run=client -o yaml | kubectl apply --kubeconfig tkg-kubeconfigs/iterate.kubeconfig -f -
fi





echo ""
echo "##################################################"
echo "##################################################"
echo "######### Create Installation Namespace ##########"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/view.kubeconfig --from-file=package-overlays/techdocs-overlay.yaml tap-gui-techdocs-overlay
fi
if [[ $CREATE_BUILD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/build.kubeconfig --from-file=package-overlays/pr-flow-overlay.yaml pr-flow-overlay
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/dev.kubeconfig --from-file=package-overlays/cnrs-overlays.yaml cnrs-overlay
fi
if [[ $CREATE_QA == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/qa.kubeconfig --from-file=package-overlays/cnrs-overlays.yaml cnrs-overlay
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/prod.kubeconfig --from-file=package-overlays/cnrs-overlays.yaml cnrs-overlay
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig create ns tap-install
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --from-file=package-overlays/cnrs-overlays.yaml cnrs-overlay
   kubectl create secret generic -n tap-install --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --from-file=package-overlays/pr-flow-overlay.yaml pr-flow-overlay
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "############# Create Registry Secret #############"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/view.kubeconfig
fi
if [[ $CREATE_BUILD == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/build.kubeconfig
fi
if [[ $CREATE_DEV == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/dev.kubeconfig
fi
if [[ $CREATE_QA == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/qa.kubeconfig
fi
if [[ $CREATE_PROD == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/prod.kubeconfig
fi
if [[ $CREATE_ITERATE == true ]]; then
   tanzu secret registry add tap-registry --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --server "$HARBOR_REGISTRY" --export-to-all-namespaces --yes --namespace tap-install --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "############# Add Package Repository #############"
echo "##################################################"
echo "##################################################"
echo ""
PKGR_URL="$HARBOR_REGISTRY/$HARBOR_PROJECT/tap-packages:$TAP_VERSION"
if [[ $CREATE_VIEW == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/view.kubeconfig
fi
if [[ $CREATE_BUILD == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/build.kubeconfig
fi
if [[ $CREATE_DEV == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/dev.kubeconfig
fi
if [[ $CREATE_QA == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/qa.kubeconfig
fi
if [[ $CREATE_PROD == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/prod.kubeconfig
fi
if [[ $CREATE_ITERATE == true ]]; then
   tanzu package repository add tanzu-tap-repository --url $PKGR_URL --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "########### Get TKG Cluster Endpoints ############"
echo "##################################################"
echo "##################################################"
echo ""
echo "Cluster Endpoints are:"
if [[ $CREATE_VIEW == true ]]; then
   VIEW_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  View Cluster: $VIEW_CLS_ENDPOINT"
fi
if [[ $CREATE_BUILD == true ]]; then
   BUILD_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  Build Cluster: $BUILD_CLS_ENDPOINT"
fi
if [[ $CREATE_DEV == true ]]; then
   DEV_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  Dev Cluster: $DEV_CLS_ENDPOINT"
fi
if [[ $CREATE_QA == true ]]; then
   QA_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  QA Cluster: $QA_CLS_ENDPOINT"
fi
if [[ $CREATE_PROD == true ]]; then
   PROD_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  Prod Cluster: $PROD_CLS_ENDPOINT"
fi
if [[ $CREATE_ITERATE == true ]]; then
   ITERATE_CLS_ENDPOINT=`kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig config view -o json | jq -r .clusters[0].cluster.server`
   echo "  Iterate Cluster: $ITERATE_CLS_ENDPOINT"
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "############### Update Values File ###############"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   yq -i '.clusters.view_cluster.k8s_info.url = "'$VIEW_CLS_ENDPOINT'"' values.yaml
fi
if [[ $CREATE_BUILD == true ]]; then
   yq -i '.clusters.build_cluster.k8s_info.url = "'$BUILD_CLS_ENDPOINT'"' values.yaml
fi
if [[ $CREATE_DEV == true ]]; then
   yq -i '.clusters.dev_cluster.k8s_info.url = "'$DEV_CLS_ENDPOINT'"' values.yaml
fi
if [[ $CREATE_QA == true ]]; then
   yq -i '.clusters.qa_cluster.k8s_info.url = "'$QA_CLS_ENDPOINT'"' values.yaml
fi
if [[ $CREATE_PROD == true ]]; then
   yq -i '.clusters.prod_cluster.k8s_info.url = "'$PROD_CLS_ENDPOINT'"' values.yaml
fi
if [[ $CREATE_ITERATE == true ]]; then
   yq -i '.clusters.iterate_cluster.k8s_info.url = "'$ITERATE_CLS_ENDPOINT'"' values.yaml
fi

echo "Added Cluster Endpoints to the values.yaml file"
echo ""
echo "##################################################"
echo "##################################################"
echo "############ Create TAP GUI Namespace ############"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_BUILD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create ns tap-gui
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create ns tap-gui
fi
if [[ $CREATE_QA == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create ns tap-gui
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create ns tap-gui
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig create ns tap-gui
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "####### Create TAP GUI Multi Cluster RBAC ########"
echo "##################################################"
echo "##################################################"
echo ""
cat << EOF > tap-gui-viewer-service-account-rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
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
  resources: ['pods', 'pods/log', 'services', 'configmaps']
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
  - mavenartifacts
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.carto.run']
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
if [[ $CREATE_BUILD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
fi
if [[ $CREATE_QA == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig create -f tap-gui-viewer-service-account-rbac.yaml
fi

mv tap-gui-viewer-service-account-rbac.yaml helper-files/
echo ""
echo "##################################################"
echo "##################################################"
echo "##### Get TAP GUI Multi Cluster Auth Tokens ######"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_BUILD == true ]]; then
   BUILD_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig  -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/build.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
   yq -i '.clusters.build_cluster.k8s_info.saToken = "'$BUILD_CLS_SA_TOKEN'"' values.yaml
fi
if [[ $CREATE_DEV == true ]]; then
   DEV_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
   yq -i '.clusters.dev_cluster.k8s_info.saToken = "'$DEV_CLS_SA_TOKEN'"' values.yaml
fi
if [[ $CREATE_QA == true ]]; then
   QA_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
   yq -i '.clusters.qa_cluster.k8s_info.saToken = "'$QA_CLS_SA_TOKEN'"' values.yaml
fi
if [[ $CREATE_PROD == true ]]; then
   PROD_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
   yq -i '.clusters.prod_cluster.k8s_info.saToken = "'$PROD_CLS_SA_TOKEN'"' values.yaml
fi
if [[ $CREATE_ITERATE == true ]]; then
   ITERATE_CLS_SA_TOKEN=`kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig -n tap-gui get secret $(kubectl --kubeconfig tkg-kubeconfigs/iterate.kubeconfig -n tap-gui get sa tap-gui-viewer -o json | jq -r '.secrets[0].name') -o=json | jq -r '.data["token"]' | base64 --decode`
   yq -i '.clusters.iterate_cluster.k8s_info.saToken = "'$ITERATE_CLS_SA_TOKEN'"' values.yaml
fi

echo "Retrieved Service Account tokens from all clusters for TAP GUI integration and updated the values file."

echo ""
echo "##################################################"
echo "##################################################"
echo "############# Render TAP Config Files ############"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   ytt -f values.yaml -f tap-config-templates/view.yaml > tap-cluster-configs/view.yaml
fi
if [[ $CREATE_BUILD == true ]]; then
   ytt -f values.yaml -f tap-config-templates/build.yaml > tap-cluster-configs/build.yaml
fi
if [[ $CREATE_DEV == true ]]; then
   ytt -f values.yaml -f tap-config-templates/dev.yaml > tap-cluster-configs/dev.yaml
fi
if [[ $CREATE_QA == true ]]; then
   ytt -f values.yaml -f tap-config-templates/qa.yaml > tap-cluster-configs/qa.yaml
fi
if [[ $CREATE_PROD == true ]]; then
   ytt -f values.yaml -f tap-config-templates/prod.yaml > tap-cluster-configs/prod.yaml
fi
if [[ $CREATE_ITERATE == true ]]; then
   ytt -f values.yaml -f tap-config-templates/iterate.yaml > tap-cluster-configs/iterate.yaml
fi

echo "TAP values files have been rendered for each cluster under the folder: `pwd`/tap-cluster-configs/"

echo ""
echo "##################################################"
echo "##################################################"
echo "### Wait For Package Repository Reconciliation ###"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/view.kubeconfig --timeout=5m
fi
if [[ $CREATE_BUILD == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/build.kubeconfig --timeout=5m
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/dev.kubeconfig --timeout=5m
fi
if [[ $CREATE_QA == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/qa.kubeconfig --timeout=5m
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/prod.kubeconfig --timeout=5m
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl wait pkgr --for condition=ReconcileSucceeded=True -n tap-install tanzu-tap-repository --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --timeout=5m
fi
if [[ $CREATE_ITERATE == true || $CREATE_BUILD == true ]]; then
   if [[ $CREATE_BUILD == true ]]; then
      TBS_PKG_NAME=buildservice.tanzu.vmware.com
      TBS_VERSIONS=($(tanzu package available list "$TBS_PKG_NAME" -n tap-install --kubeconfig tkg-kubeconfigs/build.kubeconfig -o json | jq -r ".[].version" | sort -t "." -k1,1n -k2,2n -k3,3n))
      TBS_VERSION=${TBS_VERSIONS[-1]}
   else
      TBS_PKG_NAME=buildservice.tanzu.vmware.com
      TBS_VERSIONS=($(tanzu package available list "$TBS_PKG_NAME" -n tap-install--kubeconfig tkg-kubeconfigs/iterate.kubeconfig -o json | jq -r ".[].version" | sort -t "." -k1,1n -k2,2n -k3,3n))
      TBS_VERSION=${TBS_VERSIONS[-1]}
   fi
   echo "Relocating TBS Images for TBS version $TBS_VERSION"
   docker manifest inspect $HARBOR_REGISTRY/$HARBOR_PROJECT/tbs-full-deps:$TBS_VERSION > /dev/null 2>/dev/null
   if [[ $? == 0 ]]; then
      echo "Skipping as the repo already exists in the target registry"
   else
      echo "Relocating TAP Packages and images now to: $HARBOR_REGISTRY/$HARBOR_PROJECT/tbs-full-deps:$TBS_VERSION"
      imgpkg copy -b registry.tanzu.vmware.com/build-service/full-tbs-deps-package-repo:$TBS_VERSION --to-repo $HARBOR_REGISTRY/$HARBOR_PROJECT/tbs-full-deps
   fi
   if [[ $CREATE_BUILD == true ]]; then
      tanzu package repository add tbs-full-deps-repository --url $HARBOR_REGISTRY/$HARBOR_PROJECT/tbs-full-deps:$TBS_VERSION --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/build.kubeconfig
   fi
   if [[ $CREATE_ITERATE == true ]]; then
      tanzu package repository add tbs-full-deps-repository --url $HARBOR_REGISTRY/$HARBOR_PROJECT/tbs-full-deps:$TBS_VERSION --namespace tap-install --wait=false --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
   fi
fi
if [[ $CREATE_VIEW == true ]]; then
  echo ""
  echo "##################################################"
  echo "##################################################"
  echo "########## Install TAP in View Cluster ###########"
  echo "##################################################"
  echo "##################################################"
  echo ""
  helm repo add bitnami https://charts.bitnami.com/bitnami
  kubectl create namespace tap-gui-backend --kubeconfig tkg-kubeconfigs/view.kubeconfig
  helm install tap-gui-db bitnami/postgresql -n tap-gui-backend --set auth.postgresPassword="VMware1!" --set auth.username="tapuser" --set auth.password="VMware1!" --kubeconfig tkg-kubeconfigs/view.kubeconfig
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
  while ! kubectl get namespace metadata-store --kubeconfig tkg-kubeconfigs/view.kubeconfig; do sleep 10; done
  CA_CERT=$(kubectl get secret --kubeconfig tkg-kubeconfigs/view.kubeconfig -n metadata-store ingress-cert -o json | jq -r ".data.\"ca.crt\"")
  AUTH_TOKEN=$(kubectl --kubeconfig tkg-kubeconfigs/view.kubeconfig get secrets -n metadata-store -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='metadata-store-read-write-client')].data.token}" | base64 -d)
  echo "Retrieved Auth Token and CA Cert of Metadata store from View Cluster"
  echo ""
  echo "##################################################"
  echo "##################################################"
  echo "##### Update TAP GUI for CVE Scan Visibility #####"
  echo "##################################################"
  echo "##################################################"
  echo ""
  cat << EOF > cve-viewer-tap-gui-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metadata-store-ready-only
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metadata-store-read-only
subjects:
- kind: ServiceAccount
  name: metadata-store-read-client
  namespace: metadata-store
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metadata-store-read-client
  namespace: metadata-store
automountServiceAccountToken: false
EOF
  kubectl apply -f cve-viewer-tap-gui-rbac.yaml --kubeconfig tkg-kubeconfigs/view.kubeconfig
  mv cve-viewer-tap-gui-rbac.yaml helper-files/cve-viewer-tap-gui-rbac.yaml
  CVE_VIEW_TOKEN=`kubectl get secret --kubeconfig tkg-kubeconfigs/view.kubeconfig $(kubectl get sa -n metadata-store metadata-store-read-client -o json --kubeconfig tkg-kubeconfigs/view.kubeconfig | jq -r '.secrets[0].name') -n metadata-store -o json | jq -r '.data.token' | base64 -d`
  yq -i '.tap_gui.app_config.proxy./metadata-store.target="https://metadata-store-app.metadata-store:8443/api/v1"' tap-cluster-configs/view.yaml
  yq -i '.tap_gui.app_config.proxy./metadata-store.changeOrigin=true' tap-cluster-configs/view.yaml
  yq -i '.tap_gui.app_config.proxy./metadata-store.secure=false' tap-cluster-configs/view.yaml
  yq -i '.tap_gui.app_config.proxy./metadata-store.headers.X-Custom-Source="project-star"' tap-cluster-configs/view.yaml
  yq -i '.tap_gui.app_config.proxy./metadata-store.headers.Authorization="Bearer '$CVE_VIEW_TOKEN'"' tap-cluster-configs/view.yaml
  tanzu package installed update -n tap-install tap -f tap-cluster-configs/view.yaml --kubeconfig tkg-kubeconfigs/view.kubeconfig --wait=false
  if [[ $CREATE_ITERATE == true || $CREATE_BUILD == true ]]; then
    echo ""
    echo "##################################################"
    echo "##################################################"
    echo "#####  Add Metadata Store Creds to Clusters  #####"
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
    cat <<EOF > store_secrets_export.yaml
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: store-ca-cert
  namespace: metadata-store-secrets
spec:
  toNamespace: "*"
---
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretExport
metadata:
  name: store-auth-token
  namespace: metadata-store-secrets
spec:
  toNamespace: "*"
EOF
  fi
  if [[ $CREATE_BUILD == true ]]; then
    kubectl create ns metadata-store-secrets --kubeconfig tkg-kubeconfigs/build.kubeconfig
    kubectl apply -f store_ca.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
    kubectl create secret generic store-auth-token --from-literal=auth_token=$AUTH_TOKEN -n metadata-store-secrets --kubeconfig tkg-kubeconfigs/build.kubeconfig
    kubectl apply -f store_secrets_export.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
  fi
  if [[ $CREATE_ITERATE == true ]]; then
    kubectl create ns metadata-store-secrets --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
    kubectl apply -f store_ca.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
    kubectl create secret generic store-auth-token --from-literal=auth_token=$AUTH_TOKEN -n metadata-store-secrets --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
    kubectl apply -f store_secrets_export.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
  fi
  if [[ $CREATE_ITERATE == true || $CREATE_BUILD == true ]]; then
    mv store_ca.yaml helper-files/
    mv store_secrets_export.yaml helper-files/
  fi
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "#### Begin TAP Install on Remaining Clusters #####"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_BUILD == true ]]; then
   tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/build.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig --wait=false
fi
if [[ $CREATE_DEV == true ]]; then
   tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/dev.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig --wait=false
fi
if [[ $CREATE_QA == true ]]; then
   tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/qa.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig --wait=false
fi
if [[ $CREATE_PROD == true ]]; then
   tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/prod.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig --wait=false
fi
if [[ $CREATE_ITERATE == true ]]; then
   tanzu package install tap -n tap-install -p tap.tanzu.vmware.com -v $TAP_VERSION -f tap-cluster-configs/iterate.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --wait=false
fi

echo ""
echo "##################################################"
echo "##################################################"
echo "####### Create TLS Delegation in Clusters ########"
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
if [[ $CREATE_VIEW == true ]]; then
   { sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/view.kubeconfig)
   kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/view.kubeconfig
fi
if [[ $CREATE_DEV == true ]]; then
   { sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/dev.kubeconfig)
   kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig
fi
if [[ $CREATE_QA == true ]]; then
   { sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/qa.kubeconfig)
   kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig
fi
if [[ $CREATE_PROD == true ]]; then
   { sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/prod.kubeconfig)
   kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig
fi
if [[ $CREATE_ITERATE == true ]]; then
   { sed -n /tlscertificatedelegations.projectcontour.io/q; kill $!; } < <(kubectl get crd -w --kubeconfig tkg-kubeconfigs/iterate.kubeconfig)
   kubectl create -f tls-delegation.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
fi
if [[ $CREATE_VIEW == true || $CREATE_DEV == true || $CREATE_QA == true || $CREATE_PROD == true || $CREATE_ITERATE == true ]]; then
   mv tls-delegation.yaml helper-files/
fi
echo ""
echo "##################################################"
echo "##################################################"
echo "###### Waiting For TAP Install to Complete #######"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_VIEW == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/view.kubeconfig --timeout=15m
fi
if [[ $CREATE_BUILD == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/build.kubeconfig --timeout=15m
fi
if [[ $CREATE_DEV == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/dev.kubeconfig --timeout=15m
fi
if [[ $CREATE_QA == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/qa.kubeconfig --timeout=15m
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/prod.kubeconfig --timeout=15m
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl wait pkgi --for condition=ReconcileSucceeded=True -n tap-install tap --kubeconfig tkg-kubeconfigs/iterate.kubeconfig --timeout=15m
fi
if [[ $CREATE_ITERATE == true || $CREATE_BUILD == true ]]; then
   echo "##################################################"
   echo "##################################################"
   echo "####### Deploy TBS Full Dependency Stack  ########"
   echo "##################################################"
   echo "##################################################"
   echo ""
   if [[ $CREATE_BUILD == true ]]; then
      tanzu package install full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v $TBS_VERSION -n tap-install --kubeconfig tkg-kubeconfigs/build.kubeconfig
   fi
   if [[ $CREATE_ITERATE == true ]]; then
      tanzu package install full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v $TBS_VERSION -n tap-install --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
   fi
fi
echo "##################################################"
echo "##################################################"
echo "##### Prepare Default NS for TAP in Clusters #####"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_BUILD == true ]]; then
   tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/build.kubeconfig
   kubectl apply -f dev-ns-prep-files/ --kubeconfig tkg-kubeconfigs/build.kubeconfig -n default
fi
if [[ $CREATE_DEV == true ]]; then
   tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/dev.kubeconfig
   kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig -n default
fi
if [[ $CREATE_QA == true ]]; then
   tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/qa.kubeconfig
   kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig -n default
fi
if [[ $CREATE_PROD == true ]]; then
   tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/prod.kubeconfig
   kubectl apply -f dev-ns-prep-files/rbac.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig -n default
fi
if [[ $CREATE_ITERATE == true ]]; then
   tanzu secret registry add registry-credentials --server "$HARBOR_REGISTRY" --username "$HARBOR_USER" --password "$HARBOR_PASSWORD" --namespace default --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
   kubectl apply -f dev-ns-prep-files/ --kubeconfig tkg-kubeconfigs/iterate.kubeconfig -n default
fi
if [[ $CREATE_ITERATE == true || $CREATE_BUILD == true ]]; then
  if `yq '.maven.enabled' values.yaml` ; then
    echo "Creating Maven Credential secret in default namespace"
    cat << EOF > maven-secret-ytt.yaml
#@ load("@ytt:data", "data")
#@ load("@ytt:base64", "base64")
---
apiVersion: v1
kind: Secret
metadata:
  name: maven-auth
type: Opaque
data:
  username: #@ base64.encode(data.values.maven.auth.user)
  password: #@ base64.encode(data.values.maven.auth.password)
  caFile: ""
EOF
    ytt -f values.yaml -f maven-secret-ytt.yaml > maven-secret.yaml
    if [[ $CREATE_BUILD == true ]]; then
      kubectl apply -f maven-secret.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
    fi
    if [[ $CREATE_ITERATE == true ]]; then
      kubectl apply -f maven-secret.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
    fi
    mv maven-secret-ytt.yaml helper-files/
    mv maven-secret.yaml dev-ns-prep-files/
  fi
fi
if [[ $CREATE_BUILD == true ]]; then
  if `yq '.gitops.enabled' values.yaml` ; then
    echo "Creating Git Auth Secret in default namespace"
    cat << EOF > git-secret-ytt.yaml
#@ load("@ytt:data", "data")
#@ load("@ytt:base64", "base64")
---
apiVersion: v1
kind: Secret
metadata:
  name: git-auth
  annotations:
    tekton.dev/git-0: #@ "https://{}".format(data.values.gitops.server_fqdn)
type: kubernetes.io/basic-auth
data:
  username: #@ base64.encode(data.values.gitops.auth.user)
  password: #@ base64.encode(data.values.gitops.auth.password)
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
  - name: tap-registry
  - name: git-auth
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
EOF
    ytt -f values.yaml -f git-secret-ytt.yaml > git-secret.yaml
    if [[ $CREATE_BUILD == true ]]; then
       kubectl apply -f git-secret.yaml --kubeconfig tkg-kubeconfigs/build.kubeconfig
    fi
    if [[ $CREATE_DEV == true ]]; then
       kubectl apply -f git-secret.yaml --kubeconfig tkg-kubeconfigs/dev.kubeconfig
    fi
    if [[ $CREATE_QA == true ]]; then
       kubectl apply -f git-secret.yaml --kubeconfig tkg-kubeconfigs/qa.kubeconfig
    fi
    if [[ $CREATE_PROD == true ]]; then
       kubectl apply -f git-secret.yaml --kubeconfig tkg-kubeconfigs/prod.kubeconfig
    fi
    if [[ $CREATE_ITERATE == true ]]; then
       kubectl apply -f git-secret.yaml --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
    fi

    mv git-secret-ytt.yaml helper-files/
    mv git-secret.yaml dev-ns-prep-files/
  fi
fi
echo "##################################################"
echo "##################################################"
echo "##### Install RabbitMQ Operator in Clusters ######"
echo "##################################################"
echo "##################################################"
echo ""
if [[ $CREATE_DEV == true ]]; then
   kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --kubeconfig tkg-kubeconfigs/dev.kubeconfig
fi
if [[ $CREATE_QA == true ]]; then
   kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --kubeconfig tkg-kubeconfigs/qa.kubeconfig
fi
if [[ $CREATE_PROD == true ]]; then
   kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --kubeconfig tkg-kubeconfigs/prod.kubeconfig
fi
if [[ $CREATE_ITERATE == true ]]; then
   kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml" --kubeconfig tkg-kubeconfigs/iterate.kubeconfig
fi

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
