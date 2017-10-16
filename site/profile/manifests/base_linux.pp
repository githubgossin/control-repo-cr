#
# profile::base_linux
#

class profile::base_linux {

  $root_ssh_key = lookup('base_linux::root_ssh_key')
  $linux_sw_pkg = lookup('base_linux::linux_sw_pkg')

# careful when configuring ntp to avoid misuse (opening for DDOS)

  class { 'ntp':
    servers  => [ 'ntp.ntnu.no' ],
    restrict => [
      'default kod nomodify notrap nopeer noquery',
      '-6 default kod nomodify notrap nopeer noquery',
    ],
  }
  class { 'timezone':
    timezone => 'Europe/Oslo',
  }

  package { $linux_sw_pkg:
    ensure => latest,
  }

# root@manager should be able to ssh without password to all

  file { '/root/.ssh':
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
    ensure => 'directory',
  }
  ssh_authorized_key { 'root@manager':
    user    => 'root',
    type    => 'ssh-rsa',
    key     => $root_ssh_key,
    require => File['/root/.ssh'],
  }

# on all Ubuntu's with two network interfaces, fix routing
  unless $::hostname =~ /(manager|monitor|logs|trends)/ {
    network::routing_table { 'table-ens4':
      table_id => 100,
    }
    network::rule { 'ens4':
      iprule  => ['from 192.168.190.0/24 lookup table-ens4', 'from 172.17.0.0/16 lookup table-ens4', ],
      require => Network::Routing_table['table-ens4'],
    }
    network::route { 'ens4':
      ipaddress => [ '0.0.0.0', '192.168.190.0', '172.17.0.0', ],
      netmask   => [ '0.0.0.0', '255.255.255.0', '255.255.0.0', ],
      gateway   => [ '192.168.190.1', false, false, ],
      table     => [ 'table-ens4', 'table-ens4', 'table-ens4', ],
      require   => Network::Routing_table['table-ens4'],
    }
  }

  unless $::fqdn == 'monitor.borg.trek' {
    include ::profile::sensu::client
  }

  include ::profile::dns::client

}
