class profile::elk::elk {

  $kibana_vhost = $::facts['ec2_metadata']['public-ipv4']
  $manager_ip   = dns_a('manager.borg.trek')[0]

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

  vcsrepo { '/opt/docker-elk':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/deviantony/docker-elk.git',
    require  => Package['git'],
  }

  docker_compose { '/opt/docker-elk/docker-compose.yml':
    ensure  => present,
    require => [ Vcsrepo['/opt/docker-elk'], 
                 Class['docker::compose'], 
                 Class['docker'], ],
  }

}
