#!/bin/bash
# addchefrecipe.sh - This script is to add a single recipe to the run_list of a node.
# Prerequisite:
#   - Local system must have already been bootstrapped to a Chef server.
#   - Chef recipe must be exist on Chef server. 
#
# Usage: addrecipe <recipe name>
#
# Arguments:
#   - $1: the name of the recipe to be added to the runlist
#
# Returns:
#   - 0: Successful
#   - Non-zero: Unsuccessful
#######################################

readonly ROOT_UID=0 # Only users with $UID 0 have root privileges.
readonly E_NOTROOT=87 # Non-root exit error.
readonly NODENAME=$(hostname -s) 
readonly RECIPE=$1

trap "rm -rf /etc/chef/.chef" EXIT # cleanup when exiting

error() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

if [ "$UID" -ne "$ROOT_UID" ]
then
  error "Must be root to run this script." 
  exit $E_NOTROOT
fi

if [ -z "${RECIPE}" ]; then
  err "No recipe name specifid."
  exit 1
fi

# Generate the knife config file on-the-fly
echo "Generating knife.rb"
[[ -d /etc/chef ]] &&  mkdir /etc/chef/.chef || (error "Error in creating .chef"; exit 1;)
cd /etc/chef
readonly CHEF_SERVER_URL=$(grep chef_server_url /etc/chef/client.rb)
echo "
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                \"${NODENAME}\"
client_key               \"/etc/chef/client.pem\"
${CHEF_SERVER_URL}
cookbook_path            [\"#{current_dir}/../cookbooks\"]
" > ./.chef/knife.rb


if ! knife cookbook show ${RECIPE}  >/dev/null 2>&1 ; then
  error "Recipe ${RECIPE} not found. Exiting."
  exit 1
fi

if knife node run_list add $NODENAME recipe[$RECIPE] ; then
  echo "${RECIPE} has been added to the runlist"
else
  error "Failed to add ${RECIPE} to the runlist"
  exit 1
fi

exit 0