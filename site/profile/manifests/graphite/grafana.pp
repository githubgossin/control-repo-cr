class profile::graphite::grafana {
  $db_password = lookup('profile::graphite::grafana::db_password')
  $db_root_password = lookup('profile::graphite::grafana::db_root_password')
  $admin_password = lookup('profile::graphite::grafana::admin_password')

  $db_user = 'grafana'
  $db_name = 'grafana'
  $graphite_server_fqdn = 'trends.borg.trek'
  $grafana_server_fqdn = 'grafana.borg.trek'
  $grafana_server_public_ip = "${facts['ec2_metadata']['public-ipv4']}"

  $config = {
    app_mode => 'production',
    database => {
      type   => 'mysql',
      host   => '127.0.0.1:3306',
      name   => $db_name,
      user   => $db_user,
      password => $db_password,
    },
    users           => {
      allow_sign_up => false,
      allow_org_create => false,
    },
    security => {
      admin_password => $admin_password,
    },
  }

  class { '::mysql::server':
    root_password           => $db_root_password,
    remove_default_accounts => true,
  }

  mysql::db { $db_name:
    user     => $db_user,
    password => $db_password,
    host     => 'localhost',
    grant    => ['ALL'],
    require  => Class['::mysql::server'],
  }

  class { 'grafana':
    cfg     => $config,
#    version => '4.2.0',
    require => Mysql::Db[$db_name],
  }

  grafana_datasource { 'graphite':
    grafana_url      => 'http://localhost:3000',
    grafana_user     => 'admin',
    grafana_password => $admin_password,
    type             => 'graphite',
    url              => "http://$graphite_server_fqdn",
    access_mode      => 'proxy',
    is_default       => true,
    require          => Class['grafana'],
  }

  class { 'nginx':
    confd_purge => true,
  }

  nginx::resource::server { $grafana_server_fqdn:
    listen_port => 80,
    proxy       => 'http://localhost:3000',
  }
  nginx::resource::server { $grafana_server_public_ip:
    listen_port => 80,
    proxy       => 'http://localhost:3000',
  }
}

