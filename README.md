# PKS Worshop

This script is for setting up a PKS Workshop in the "Let's bake a cake in 5 minutes" demo style where things are in various key stages of configuration to show configuration but not require we wait for it to "do-the-thing" and complete an actual installation.

## TODO - What's on the Roadmap
* Map IP's which can be seen at `gcloud compute addresses list` and implement them in chosen registry.
* Integrate NAT properly
* Iterate through all instances and delete during destroy-gcp (possibly scorch-gcp)
* Step-by-Step guide on configuring/uploading OpsmanVM as a base
* Make commands brief by default and add -vvv for raw
* Allow running pks-workshop command folder agnostic
* Curl for OPSMAN secrets
* Curl for OPSMAN CMDLINE CREDENTIALS
* DNS Entries
  * userX.opsman.mcnichol.rocks
  * api.userX.pks.mcnichol.rocks
  * userX.cluster.mcnichol.rocks
  * userX.harbor.mcnichol.rocks
