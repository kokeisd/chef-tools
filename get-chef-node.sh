#!/bin/bash
#
# get-chef-node.sh - This script downloads the list of Chef client nodes into a csv file from the Chef server
#
# Prerequisite:
#   - Local system must have already been bootstrapped to a Chef server.
#
# Usage: get-chef-node.sh
#
# Arguments:
#   - null
#
# Returns:
#   - 0: Successful
#   - Non-zero: Unsuccessful
#######################################

readonly ROOT_UID=0 # Only users with $UID 0 have root privileges.
readonly E_NOTROOT=87 # Non-root exit error.
readonly NODENAME=$(hostname -s) 

trap "rm -rf /etc/chef/.chef" EXIT # cleanup when exiting

error() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

if [ "$UID" -ne "$ROOT_UID" ]
then
  error "$(basename ${BASH_SOURCE}) must be run with root permission." 
  exit $E_NOTROOT
fi

if [[ ! -f "/etc/chef/client.pem" ]]; then 
  error "This machine is not bootstrapped to Chef."
  exit 1
fi

# Generate the knife config file on-the-fly
echo "Generating knife.rb."
[[ -d /etc/chef ]] && mkdir /etc/chef/.chef || (error "Error in creating .chef"; exit 1;)
readonly CHEFSERVERURL=$(grep chef_server_url /etc/chef/client.rb)
echo "current_dir = File.dirname(__FILE__)
  log_level                :info
  log_location             STDOUT
  node_name                \"${NODENAME}\"
  client_key               \"/etc/chef/client.pem\"
  ${CHEFSERVERURL}
  " > /etc/chef/.chef/knife.rb

echo "Generating Chef node list csv ..."
if ! /usr/bin/knife node list -c /etc/chef/.chef/knife.rb> ./full-list.csv; then
  error "Error in generating Chef node list."
  exit 1
fi

