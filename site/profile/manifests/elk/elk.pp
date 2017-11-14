class profile::elk::elk {

  $kibana_vhost = $::facts['ec2_metadata']['public-ipv4']
  $manager_ip   = dns_a('manager.borg.trek')[0]
  $elk_key      = lookup('profile::elk::key')

  package { 'git':
    ensure => present,
  }

  class {'nginx': }
  nginx::resource::server{ "${kibana_vhost}":
    listen_port => 80,
    proxy       => 'http://localhost:5601',
  }

  class { 'docker':
    dns        => "${manager_ip}",
    fixed_cidr => '172.17.0.0/16',
  }

  class {'docker::compose':
    ensure => present,
  }

  file { '/opt/docker-elk/logstash/ssl':
    ensure => directory,
    require => Vcsrepo['/opt/docker-elk'],
  }

  file {'/opt/docker-elk/logstash/ssl/ca.crt':
    ensure => file,
    mode   => '0644',
    source => 'puppet:///modules/profile/certs/cacert.pem',
    require => Vcsrepo['/opt/docker-elk'],
  }

  file {'/opt/docker-elk/logstash/ssl/server.crt':
    ensure => file,
    mode   => '0444',
    source => 'puppet:///modules/profile/certs/cert.pem',
    require => Vcsrepo['/opt/docker-elk'],
  }

  file {'/opt/docker-elk/logstash/ssl/server.p8':
    ensure  => file,
    mode    => '0444',
    content => "$elk_key",
    require => Vcsrepo['/opt/docker-elk'],
  }

  vcsrepo { '/opt/docker-elk':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/deviantony/docker-elk.git',
    require  => Package['git'],
  }

  file { '/opt/docker-elk/docker-compose.yml':
    ensure => file,
    source => 'puppet:///modules/profile/docker-compose.yml',
    require => Vcsrepo['/opt/docker-elk'],
  }

  file { '/opt/docker-elk/logstash/pipeline/logstash.conf':
    ensure => file,
    source => 'puppet:///modules/profile/logstash.conf',
    require => Vcsrepo['/opt/docker-elk'],
  }

  docker_compose { '/opt/docker-elk/docker-compose.yml':
    ensure    => present,
    require   => [ Vcsrepo['/opt/docker-elk'], 
                   Class['docker::compose'], 
                   Class['docker'],
                 ],
    subscribe => [ File['/opt/docker-elk/docker-compose.yml'],
                   File['/opt/docker-elk/logstash/pipeline/logstash.conf'],
                   File['/opt/docker-elk/logstash/ssl/ca.crt'],
                   File['/opt/docker-elk/logstash/ssl/server.crt'],
                   File['/opt/docker-elk/logstash/ssl/server.p8'],
                 ],
  }

}

