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

# new CA (should join with Sensu setup above really) for ELK
# Be your own 'BORG CA', generate a private key:
openssl genrsa -out borgca.key 2048
# generate a self signed certificate for the BORG CA:
openssl req -new -x509 -days 7300 -subj '/O=BORG CA' -key borgca.key -out borgca.crt
cp borgca.crt "$old_working_dir/site/profile/files/certs/cacert.pem"
# ELK KEYPAIR: create a certificate request:
openssl req -nodes -new -subj '/CN=logs.borg.trek' -out logs.borg.trek.csr
# sign it with our Borg CA:
openssl x509 -req -in logs.borg.trek.csr -CA borgca.crt -CAkey borgca.key -CAcreateserial -out logs.borg.trek.crt
cp logs.borg.trek.crt "$old_working_dir/site/profile/files/certs/cert.pem"
# convert private key to pkcs8
openssl pkcs8 -in privkey.pem -topk8 -nocrypt -out logs.borg.trek.p8
echo 'profile::elk::key: |' >>  "$old_working_dir/hieradata/nodes/logs.borg.trek.yaml"
sed -e 's/^/  /' logs.borg.trek.p8 >> "$old_working_dir/hieradata/nodes/logs.borg.trek.yaml"
# FILEBEAT KEYPAIR (should change use of manager hostname): create a certificate request:
openssl req -nodes -new -subj '/CN=manager.borg.trek' -out manager.borg.trek.csr
# sign it with our Borg CA:
openssl x509 -req -in manager.borg.trek.csr -CA borgca.crt -CAkey borgca.key -CAcreateserial -out manager.borg.trek.crt
cp manager.borg.trek.crt "$old_working_dir/site/profile/files/certs/filebeat.cert.pem"
# convert private key to pkcs8
openssl pkcs8 -in privkey.pem -topk8 -nocrypt -out manager.borg.trek.p8
echo 'profile::filebeat::key: |' >>  "$old_working_dir/hieradata/common.yaml"
sed -e 's/^/  /' manager.borg.trek.p8 >> "$old_working_dir/hieradata/common.yaml"

#echo "Really ugly quick fix to Erlang module:"
#head -n 32  /etc/puppetlabs/code/environments/production/modules/erlang/manifests/repo/apt.pp > /etc/puppetlabs/code/environments/production/modules/erlang/manifests/repo/apt.pp_tmp
#mv  /etc/puppetlabs/code/environments/production/modules/erlang/manifests/repo/apt.pp_tmp /etc/puppetlabs/code/environments/production/modules/erlang/manifests/repo/apt.pp
#cat <<EOF >> /etc/puppetlabs/code/environments/production/modules/erlang/manifests/repo/apt.pp
#  apt::source { 'erlang':
#    key         => {
#                     id      => \$key_signature,
#                     source  => \$remote_repo_key_location,
#                   },
#    location    => \$remote_repo_location,
#    repos       => \$repos,
#  }
#}
#EOF
