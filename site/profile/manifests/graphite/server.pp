class profile::graphite::server {

  $mysql_root_password     = lookup('profile::graphite::mysql_root_password')
  $mysql_graphite_password = lookup('profile::graphite::mysql_graphite_password')
  $graphite_secret_key     = lookup('profile::graphite::graphite_secret_key')

  class { '::mysql::server':
    root_password           => $mysql_root_password,
    remove_default_accounts => true,
  }

  mysql::db { 'graphite':
    user     => 'graphite',
    password => $mysql_graphite_password,
    host     => 'localhost',
  }

  class { 'graphite':
    gr_storage_schemas        => [
      {
        name       => 'carbon',
        pattern    => '^carbon\.',
        retentions => '1m:90d'
      },
      {
        name       => 'default',
        pattern    => '.*',
        retentions => '10s:1h,1m:1d,10m:1y'
      }
    ],
    gr_max_updates_per_second => 100,
    gr_timezone               => 'Europe/Oslo',
    secret_key                => $graphite_secret_key,
    gr_web_server             => 'nginx',
    gr_django_db_engine       => 'django.db.backends.mysql',
    gr_django_db_name         => 'graphite',
    gr_django_db_user         => 'graphite',
    gr_django_db_password     => $mysql_graphite_password,
    gr_django_db_host         => '127.0.0.1',
    gr_django_db_port         => '3306',
    require                   => Mysql::Db['graphite'],
  }
}

