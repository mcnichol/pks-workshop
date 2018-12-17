#!/usr/bin/env bash

### This section for General Configuration
PROJECT_ID="fe-mmcnichol"
GCLOUD_REGION="us-east1"
GCLOUD_ZONE="$GCLOUD_REGION-b"

### This section for GCP Prep and Configuration
MY_PKS="mcnichol-pks"
PKS_SERVICE_ACCOUNT="pks-service-account"
PKS_IAM_EMAIL="${PKS_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
NETWORK="$MY_PKS-network"
NETWORK_SUBNET_RUNTIME="$MY_PKS-subnet-useast1-runtime"
NETWORK_SUBNET_INFRA="$MY_PKS-subnet-useast1-infra"
NETWORK_SUBNET_SERVICES="$MY_PKS-subnet-useast1-services"

FW_RULE_ALLOW_SSH="$MY_PKS-allow-ssh"
FW_RULE_ALLOW_HTTP="$MY_PKS-allow-http"
FW_RULE_ALLOW_HTTP_8080="$MY_PKS-allow-http-8080"
FW_RULE_ALLOW_HTTPS="$MY_PKS-allow-https"
FW_RULE_ALLOW_PAS_ALL="$MY_PKS-allow-pas-all"
FW_RULE_ALLOW_CF_TCP="$MY_PKS-allow-cf-tcp"
FW_RULE_ALLOW_SSH_PROXY="$MY_PKS-allow-ssh-proxy"

INSTANCE_NAT_NAME="$MY_PKS-nat-gw"

ROUTE_INSTANCE_NAT="$MY_PKS-nat-route"

### This section for K8s Master/Worker Configuration
MASTER_SERVICE_ACCOUNT="pks-master"
MASTER_IAM_EMAIL="$MASTER_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"

WORKER_SERVICE_ACCOUNT="pks-worker"
WORKER_IAM_EMAIL="$WORKER_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"

# Authenticate with gcloud unless already logged in
GCLOUD_CURRENT_AUTHENTICATED="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"

if [ -z $GCLOUD_CURRENT_AUTHENTICATED ]; then
  gcloud auth login
else
  echo "Currently logged in with: $GCLOUD_CURRENT_AUTHENTICATED"
  echo "To logout execute:"
  echo "gcloud auth revoke $GCLOUD_CURRENT_AUTHENTICATED"
fi

case $1 in
  gcp-setup)
    gcloud iam service-accounts create $PKS_SERVICE_ACCOUNT
    gcloud iam service-accounts keys create $PKS_SERVICE_ACCOUNT.service-account.key.json --iam-account=$PKS_IAM_EMAIL

    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/iam.serviceAccountUser
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/iam.serviceAccountTokenCreator
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/compute.instanceAdmin.v1
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/compute.networkAdmin
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/compute.storageAdmin
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$PKS_IAM_EMAIL --role=roles/storage.admin

    gcloud compute networks create "$NETWORK" --subnet-mode=custom
    gcloud compute networks subnets create "$NETWORK_SUBNET_RUNTIME"  --network="$NETWORK" --range=192.168.16.0/22  --region="$GCLOUD_REGION"
    gcloud compute networks subnets create "$NETWORK_SUBNET_SERVICES" --network="$NETWORK" --range=192.168.20.0/22  --region="$GCLOUD_REGION"
    gcloud compute networks subnets create "$NETWORK_SUBNET_INFRA"    --network="$NETWORK" --range=192.168.101.0/26 --region="$GCLOUD_REGION"

    # Create NAT Instance
    gcloud compute instances create "$INSTANCE_NAT_NAME" \
      --project "$PROJECT_ID" \
      --zone "$GCLOUD_ZONE" \
      --network-interface private-network-ip=192.168.101.2,network="$NETWORK",subnet="$NETWORK_SUBNET_INFRA" \
        --tags "nat-traverse","$MY_PKS-nat-instance" \
      --machine-type "n1-standard-4" \
        --metadata-from-file startup-script="nat-gw-startup.sh" \
        --image "ubuntu-1404-trusty-v20181203" \
        --image-project "ubuntu-os-cloud" \
        --boot-disk-size "10" \
        --boot-disk-type "pd-standard" \
        --can-ip-forward

    # Create Routes
    gcloud compute routes create $ROUTE_INSTANCE_NAT --destination-range=0.0.0.0/0 --priority=800 --tags $MY_PKS --next-hop-instance=$INSTANCE_NAT_NAME --network=$NETWORK

    # Allow Internal && Director communication over SSH and CLI req'd ports
    gcloud compute firewall-rules create $FW_RULE_ALLOW_SSH       --network=$NETWORK --allow=tcp:22         --source-ranges=0.0.0.0/0   --target-tags="allow-ssh"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_HTTP      --network=$NETWORK --allow=tcp:80         --source-ranges=0.0.0.0/0   --target-tags="allow-http","router"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_HTTPS     --network=$NETWORK --allow=tcp:443        --source-ranges=0.0.0.0/0   --target-tags="allow-https","router"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_HTTP_8080 --network=$NETWORK --allow=tcp:8080       --source-ranges=0.0.0.0/0   --target-tags="router"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_PAS_ALL   --network=$NETWORK --allow=tcp,udp,icmp   --source-tags="$MY_PKS","$MY_PKS-opsman","nat-traverse" --target-tags="$MY_PKS","$MY_PKS-opsman","nat-traverse"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_CF_TCP    --network=$NETWORK --allow=tcp:1024-65535 --source-ranges=0.0.0.0/0  --target-tags="$MY_PKS-cf-tcp"
    gcloud compute firewall-rules create $FW_RULE_ALLOW_SSH_PROXY --network=$NETWORK --allow=tcp:2222       --source-ranges=0.0.0.0/0  --target-tags="$MY_PKS-ssh-proxy","diego-brain"
    ;;

  pks-setup)
    gcloud iam service-accounts create $MASTER_SERVICE_ACCOUNT
    cloud iam service-accounts keys create $MASTER_SERVICE_ACCOUNT.service-account.key.json --iam-account=$MASTER_IAM_EMAIL

    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/compute.instanceAdmin.v1
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/compute.networkAdmin
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/compute.securityAdmin
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/compute.storageAdmin
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/compute.viewer
    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$MASTER_IAM_EMAIL --role=roles/iam.serviceAccountUser

    gcloud iam service-accounts create $WORKER_SERVICE_ACCOUNT
    gcloud iam service-accounts keys create $WORKER_SERVICE_ACCOUNT.service-account.key.json --iam-account=$WORKER_IAM_EMAIL

    gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$WORKER_IAM_EMAIL --role=roles/compute.viewer
    ;;

  gcp-destroy)

    gcloud iam service-accounts delete $PKS_IAM_EMAIL --quiet

    gcloud compute routes delete $ROUTE_INSTANCE_NAT --quiet

    gcloud compute instances delete $INSTANCE_NAT_NAME --quiet

    gcloud compute firewall-rules delete $FW_RULE_ALLOW_SSH --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_HTTP --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_HTTP_8080 --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_HTTPS --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_PAS_ALL --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_CF_TCP --quiet
    gcloud compute firewall-rules delete $FW_RULE_ALLOW_SSH_PROXY --quiet

    gcloud compute networks subnets delete $NETWORK_SUBNET_RUNTIME --quiet
    gcloud compute networks subnets delete $NETWORK_SUBNET_INFRA --quiet
    gcloud compute networks subnets delete $NETWORK_SUBNET_SERVICES --quiet

    gcloud compute networks delete $NETWORK --quiet

    gcloud compute addresses delete $PKS_SERVICE_ACCOUNT --quiet
    ;;
  pks-destroy)
    gcloud iam service-accounts delete $MASTER_IAM_EMAIL --quiet
    gcloud iam service-accounts delete $WORKER_IAM_EMAIL --quiet
    ;;
  *)
    echo "Da fuq?"
    ;;
esac
