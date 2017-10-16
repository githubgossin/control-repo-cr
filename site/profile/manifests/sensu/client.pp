class profile::sensu::client {

  $rabbitmq_password = lookup('profile::sensu::rabbitmq_password')
  $sensu_key         = lookup('profile::sensu::sensu_key')

  $sensu_dependency  = ['ruby-json', 'ruby', 'g++', 'make']
  $sensu_server_fqdn = 'monitor.borg.trek'

  package { $sensu_dependency:
    ensure => present,
  }

  file {"/etc/sensu/ssl/${::hostname}.cert.pem":
    ensure => file,
    owner  => 'sensu',
    group  => 'sensu',
    mode   => '0444',
    source => 'puppet:///modules/profile/certs/sensu.cert.pem',
  }

  file {"/etc/sensu/ssl/${::hostname}.key.pem":
    ensure  => file,
    owner   => 'sensu',
    group   => 'sensu',
    mode    => '0400',
    content => "$sensu_key",
  }

  class { 'sensu':
    install_repo             => true,
    rabbitmq_user            => 'sensu',
    rabbitmq_password        => $rabbitmq_password,
    rabbitmq_host            => "$sensu_server_fqdn",
    rabbitmq_port            => '5671',
    rabbitmq_vhost           => '/sensu',
    rabbitmq_ssl_private_key => "/etc/sensu/ssl/${::hostname}.key.pem",
    rabbitmq_ssl_cert_chain  => "/etc/sensu/ssl/${::hostname}.cert.pem",
    safe_mode                => true,
    use_embedded_ruby        => true,
    sensu_plugin_provider    => 'sensu_gem',
    require                  => Package[$sensu_dependency]
  }

  include ::profile::sensu::plugins
}
