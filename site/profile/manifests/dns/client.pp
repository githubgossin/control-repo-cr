class profile::dns::client {

  # Export an A record for your hostname
  @@dns::record::a { $::hostname:
    zone => 'borg.trek',
    data => $::ipaddress,
  }

}
