# PKS Worshop

This script is for setting up a PKS Workshop in the "Let's bake a cake in 5 minutes" demo style where things are in various key stages of configuration to show configuration but not require we wait for it to "do-the-thing" and complete an actual installation.

## TODO - What's on the Roadmap
* ~~Allow running pks-workshop command folder agnostic~~
* ~~Change from Setup to Create~~
* ~~tarball service-keys for sharing~~
* ~~Compress lib files~~
* Map IP's which can be seen at `gcloud compute addresses list` and implement them in chosen registry.
* Iterate through all instances and delete during destroy-gcp (possibly scorch-gcp)
* Step-by-Step guide on configuring/uploading OpsmanVM as a base
* Make commands brief by default and add -vvv for raw
* Curl for OPSMAN secrets
* Curl for OPSMAN CMDLINE CREDENTIALS
* DNS Entries
  * userX.opsman.mcnichol.rocks
  * api.userX.pks.mcnichol.rocks
  * userX.cluster.mcnichol.rocks
  * userX.harbor.mcnichol.rocks
* Get IP from Harbor VM (lookup on keywords/tags)
* Investigate Node Packaging for more informative/interactive CLI
* Kill exits completely instead of failing over to next command
* Remove PAS specific setup (tags, f/w rules)
* Cleanup duplicate vars and values (e.g. $MY_PKS-opsman / $INSTANCE_OPSMAN)
* Create CSV of users, passwords, urls
* Remove references to PAS and make PKS specific
* Get BOSH exports in creds file on opsman 
* Integrate NAT properly

## Notes:

### Created BOSH Commandline Credentials on each Opsman.  User can now:

### Activate permissioned Service Account with appropriate keys
gcloud auth activate-service-account --key-file=$USER-pks-service-account.key.json

### SSH onto Opsman
gcloud compute ssh --project $PROJECT_ID  --zone $ZONE "$USER-pks-opsman"

### eval BOSH env_vars
eval $(cat bosh-creds)

bosh vms || bosh instances --ps || bosh --help

## Create users for Interal UAA

### Target PKS API
MY_USER=userX; uaac target https://api.$MY_USER.pks.mcnichol.rocks:8443 --ca-cert $(echo $BOSH_CA_CERT)

### Get PKS UAA Secret from Opsman > PKS Tile >  Credentials Tab > UAA Management Admin Client  > Link to Creds  > Secret
uaac token client get admin -s $UAA_MGMT_ADMIN_CLIENT_SECRET

### Grant PKS Access
uaac user add $USERNAME --email $EMAIL -p $PASSWORD

### Add Scope to User
uaac member add (pks.clusters.admin | pks.clusters.manage) userX

### Usage ./this-script.sh userX
for POST_FIX in {a..m}; do
  THIS_USER="$1$POST_FIX-admin"
  echo "Adding user: $THIS_USER with Scope: pks.clusters.admin"
  uaac user add "$THIS_USER" --emails $THIS_USER@email.com -p password
  uaac member add pks.clusters.admin $THIS_USER
done

for POST_FIX in {a..m}; do
  THIS_USER="$1$POST_FIX-manage"

  echo "Adding user: $THIS_USER with Scope: pks.clusters.manage"
  uaac user add "$THIS_USER" --emails $THIS_USER@email.com -p password
  uaac member add pks.clusters.manage $THIS_USER
done

# Destroying Compute VMs with GCLOUD - scorched earth
for vm in $(gcloud compute instances list | awk '{print $1}'); do
  gcloud compute instances delete $vm --quiet
done

### All IP's we are working with
* om ip
* lb ip
* harbor ip
* nat ip

## Learnings:

* Do not give anyone credentials....they will break your heart
  * Find a more organized way to get this to them, CSV
  * Group them in clusters to minimize moving parts
* Don't use NAT for demo's
* Make Docs more attractive (Metricbeats Elasticsearch Demo)
