#!/bin/bash

# this script does the following:
# - sets new passwords for all hiera entries ending with 'password:'
# - creates a new CA and signed keypairs for Sensu and RabbitMQ 
# TBA improvement: use openssl directly and replace keys in hiera 
# instead of just appending them and relying on manual edit

# save old rabbitmq sensu plugin password
entry="$(grep profile::sensu::rabbitmq_monitoring_password: hieradata/nodes/monitor.borg.trek.yaml)"
old_pw=$(echo "$entry" | grep -oE '[^ ]*$')

# create new passwords for all hiera keys ending with 'password'
while read -r entry
do
  filename=$(echo "$entry" | cut -d ':' -f1)
  key=$(echo "$entry" | cut -d ':' -f1 --complement)
  blank_key=$(echo "$key" | grep -oE '^.*password:')
  sed -i -E "s/($blank_key).*/\1 $(pwgen -s 16 1)/" "$filename"
done < <(grep -rH 'password:' hieradata/*)

# update all hardcoded rabbitmq sensu plugin passwords
entry="$(grep profile::sensu::rabbitmq_monitoring_password: hieradata/nodes/monitor.borg.trek.yaml)"
new_pw=$(echo "$entry" | grep -oE '[^ ]*$')
sed -i -E "s/$old_pw/$new_pw/" hieradata/nodes/monitor.borg.trek.yaml

# new CA and ssl keys with Sensu's SSL tool
old_working_dir=$(pwd)
tmp_ssl_dir=$(mktemp -d /tmp/XXXXXXXXXXXXXXXXXX) || exit 1
cd "$tmp_ssl_dir"
wget http://sensuapp.org/docs/1.1/files/sensu_ssl_tool.tar
tar -xvf sensu_ssl_tool.tar
cd sensu_ssl_tool
./ssl_certs.sh clean
./ssl_certs.sh generate
mkdir -p "$old_working_dir/site/profile/files/certs"
cp sensu_ca/cacert.pem "$old_working_dir/site/profile/files/certs/borgca.crt"
cp server/cert.pem "$old_working_dir/site/profile/files/certs/rabbitmq.cert.pem"
cp client/cert.pem "$old_working_dir/site/profile/files/certs/sensu.cert.pem"
echo 'profile::sensu::rabbitmq_key: |' >> "$old_working_dir/hieradata/nodes/monitor.borg.trek.yaml"
sed -e 's/^/  /' server/key.pem >> "$old_working_dir/hieradata/nodes/monitor.borg.trek.yaml"
# private key in common.yaml :)
echo 'profile::sensu::sensu_key: |' >> "$old_working_dir/hieradata/common.yaml"
sed -e 's/^/  /' client/key.pem >> "$old_working_dir/hieradata/common.yaml"

echo "*"
echo "*"
echo "Please run the following command to check if you have multiple entries in Hiera:"
echo "(if you have, remove the top one, since the new one is appended at the end)"
echo " grep profile::sensu::rabbitmq_key: $old_working_dir/hieradata/nodes/monitor.borg.trek.yaml"
echo " grep profile::sensu::sensu_key: $old_working_dir/hieradata/common.yaml"

