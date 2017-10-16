Control Repo for Simple Cyber Range
===================================

  * [Pre-deploy steps](#pre-deploy-steps)
  * [Deploy](#deploy)

# Pre-deply steps

Create certificates with the [Sensu SSL tool](https://sensuapp.org/docs/latest/reference/ssl.html)
```
cd /tmp
wget http://sensuapp.org/docs/1.1/files/sensu_ssl_tool.tar
tar -xvf sensu_ssl_tool.tar
cd sensu_ssl_tool
./ssl_certs.sh clean
./ssl_certs.sh generate
cp sensu_ca/cacert.pem ~/gits/control-repo-cr/site/profile/files/certs/borgca.crt
cp server/cert.pem ~/gits/control-repo-cr/site/profile/files/certs/rabbitmq.cert.pem
cp client/cert.pem ~/gits/control-repo-cr/site/profile/files/certs/sensu.cert.pem
echo 'profile::sensu::rabbitmq_key: |' >> ~/gits/control-repo-cr/hieradata/nodes/monitor.borg.trek.yaml
cat server/key.pem | sed -e 's/^/  /' >> ~/gits/control-repo-cr/hieradata/nodes/monitor.borg.trek.yaml
# private key in common.yaml :)
echo 'profile::sensu::sensu_key: |' >> ~/gits/control-repo-cr/hieradata/common.yaml
cat server/key.pem | sed -e 's/^/  /' >> ~/gits/control-repo-cr/hieradata/common.yaml
# delete old entries:
vi ~/gits/control-repo-cr/hieradata/nodes/monitor.borg.trek.yaml
vi ~/gits/control-repo-cr/hieradata/common.yaml
```


# Deploy

.
