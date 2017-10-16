class profile::dns::server {

  include dns::server

  # Forwarders
  dns::server::options { '/etc/bind/named.conf.options':
    forwarders => [ '129.241.0.201', ],
  }

  dns::zone { 'borg.trek':
    soa         => 'manager.borg.trek',
    soa_email   => 'admin.borg.trek',
    nameservers => [ 'manager' ],
  }

  # Collect all the records from other nodes
  Dns::Record::A <<||>> 

}
