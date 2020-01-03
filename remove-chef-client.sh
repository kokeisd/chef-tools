#!/bin/bash
# remove-chef-client.sh - This script cleanly uninstalls the Chef agent and unregister node info from the Chef server.
#
# Prerequisite:
#   - Local system must have already been bootstrapped to a Chef server.
#
# Usage: remove-chef-client.sh
#
# Returns:
#   - 0: Successful
#   - Non-zero: Unsuccessful
#######################################

readonly ROOT_UID=0 # Only users with $UID 0 have root privileges.
readonly E_NOTROOT=87 # Non-root exit error.
readonly NODENAME=$(hostname -s) 

trap "[[ -f /etc/chef/.chef ]] && rm -rf /etc/chef/.chef" EXIT # cleanup when exiting

error() {
  local message=$@
  [[ -z "$message" ]] && message="Died"    
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: $message." >&2
}

die() {
  local message=$@
  [ -z "$message" ] && message="Died"
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: $message." >&2
  exit 1
}

if [ "$UID" -ne "$ROOT_UID" ] ; then
  error "Must be root to run this script." 
  exit $E_NOTROOT
fi

# Exit if the OS is not Ubuntu or Redhat
[[ grep -i -q redhat /proc/version ]] || [ grep -i -q ubuntu /proc/version ]] || die "Operating System not supported supported"

# Stop and disable chef-client service
systemctl stop chef-client || error "Unable to stop the chef-client service"
systemctl disable chef-client || error "Unable to disable the chef-client service"
rm /etc/systemd/system/chef-client.service || error "Unable to remove the chef-client.service"
systemctl daemon-reload
systemctl reset-failed

# Unregister the current node from the Chef server

echo "Generating knife.rb"
[[ ! -d /etc/chef/.chef ]] &&  mkdir /etc/chef/.chef
readonly CHEFSERVERURL=$(grep chef_server_url /etc/chef/client.rb)
echo "
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                \"${NODENAME}\"
client_key               \"/etc/chef/client.pem\"
${CHEFSERVERURL}
cookbook_path            [\"#{current_dir}/../cookbooks\"]
" > /etc/chef/.chef/knife.rb

echo "Deleting node from Chef server ${CHEFSERVERURL}"
knife node delete ${NODENAME} -y -c /etc/chef/.chef/knife.rb >/dev/null 2>&1 \
  || die "Error deleting node ${NODENAME} "

echo "Deleting client from Chef server ${CHEFSERVERURL}"  
knife client delete ${NODENAME} -y -c /etc/chef/.chef/knife.rb >/dev/null 2>&1  \
  || die "Error deleting client ${NODENAME} "

echo "Deleting client key"
rm -rf /etc/chef/client.pem || die "Error deleting client key "

# Uninstall the Chef infra client(aka Chef client) package
if grep -i -q redhat /proc/version; then
  rpm -e $(rpm -qa|grep -i chef-) -y
elif grep -i -q ubuntu /proc/version; then
  apt remove chef -y
fi