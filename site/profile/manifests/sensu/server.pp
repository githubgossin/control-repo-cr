class profile::sensu::server {

  $rabbitmq_password            = lookup('profile::sensu::rabbitmq_password')
  $api_password                 = lookup('profile::sensu::api_password')
  $rabbitmq_monitoring_password = lookup('profile::sensu::rabbitmq_monitoring_password')
  $rabbitmq_key                 = lookup('profile::sensu::rabbitmq_key')
  $sensu_key                    = lookup('profile::sensu::sensu_key')

  $sensu_server_fqdn = "${::fqdn}"
  $graphite_server_fqdn = 'trends.borg.trek'
  $sensu_dependency  = ['ruby-json', 'ruby', 'g++', 'make']

# Rabbitmq dependencies
#  include 'erlang'
  package { ['erlang-nox','socat']:
    ensure => 'latest',
  }

# Sensu dependency json package:
  package { $sensu_dependency:
    ensure => present,
  }

# Sensu dependency redis:
#  class { 'redis': }
# HACK: temp fix for 18.04
# https://github.com/arioch/puppet-redis/issues/225
  file { '/etc/systemd/system/redis-server.service.d/limit.conf':
    ensure => absent,
  }
  class { 'redis':
    ulimit    => false,
    subscribe => File['/etc/systemd/system/redis-server.service.d/limit.conf'],
  }

  file {'/etc/ssl/certs/borgca.crt':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/profile/certs/borgca.crt',
  }

  file {"/etc/rabbitmq/ssl/${::hostname}.cert.pem":
    ensure => file,
    owner  => 'rabbitmq',
    group  => 'rabbitmq',
    mode   => '0444',
    source => 'puppet:///modules/profile/certs/rabbitmq.cert.pem',
  }

  file {"/etc/rabbitmq/ssl/${::hostname}.key.pem":
    ensure  => file,
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0400',
    content => "$rabbitmq_key",
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


# Sensu dependency rabbitmq:
#  include '::rabbitmq::repo::apt'
  class { 'rabbitmq':
    ssl               => true,
    ssl_port          => 5671,
    ssl_cacert        => '/etc/ssl/certs/borgca.crt',
    ssl_cert          => "/etc/rabbitmq/ssl/${::hostname}.cert.pem",
    ssl_key           => "/etc/rabbitmq/ssl/${::hostname}.key.pem",
    management_ssl    => false,
    delete_guest_user => true,
    repos_ensure      => true,
  }

  rabbitmq_user { 'monitoring':
    admin    => false,
    password => "$rabbitmq_monitoring_password",
    tags     => ['monitoring']
  }

  rabbitmq_user_permissions { 'monitoring@/':
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }

  rabbitmq_user { 'sensu' :
    admin    => false,
    password => "$rabbitmq_password",
  }

  rabbitmq_vhost { '/sensu':
    ensure => present,
  }
  rabbitmq_user_permissions { 'sensu@/sensu':
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }

# Sensu:
  class { 'sensu':
    install_repo             => true,
    rabbitmq_user            => 'sensu',
    rabbitmq_password        => "$rabbitmq_password",
    rabbitmq_host            => "$sensu_server_fqdn",
    rabbitmq_port            => 5671,
    rabbitmq_vhost           => '/sensu',
    rabbitmq_ssl_private_key => "/etc/sensu/ssl/${::hostname}.key.pem",
    rabbitmq_ssl_cert_chain  => "/etc/sensu/ssl/${::hostname}.cert.pem",
    server                   => true,
    use_embedded_ruby        => true,
    sensu_plugin_provider    => 'sensu_gem',
    api                      => true,
    api_user                 => 'sensu',
    api_password             => $api_password,
    redis_host               => '127.0.0.1',
    require                  => [ Package[$sensu_dependency], Class['redis'],
                                  Class['rabbitmq'] ],
  }

  sensu::handler { 'handler_graphite':
    ensure  => present,
    type    => 'tcp',
    socket  => {host => "$graphite_server_fqdn",
                port => 2003},
    mutator => 'only_check_output',
  }

  include ::profile::sensu::plugins

# Uchiwa dashboard:
  $uchiwa_api_config = [
    {
      host      => '127.0.0.1',
      ssl       => false,
      port      => 4567,
      user      => 'sensu',
      pass      => $api_password,
      path      => '',
      timeout   => 5
    }
  ]
  class { 'uchiwa':
    install_repo        => false,
    sensu_api_endpoints => $uchiwa_api_config,
    host                => '127.0.0.1',
    require             => Class['sensu'],
  }

  class { 'nginx':
    confd_purge => true,
  }

  nginx::resource::server { "$sensu_server_fqdn":
    listen_port => 80,
    proxy       => 'http://localhost:3000',
  }

}

