class profile::elk::filebeat {
  
  $logstash_server = lookup('profile::elk::logstash_server')
  $filebeat_key    = lookup('profile::filebeat::key')

  file {'/etc/ssl/certs/ca.crt':
    ensure => file,
    mode   => '0644',
    source => 'puppet:///modules/profile/certs/cacert.pem',
  }

  file {'/etc/ssl/certs/client.crt':
    ensure => file,
    mode   => '0444',
    source => 'puppet:///modules/profile/certs/filebeat.cert.pem',
  }

  file {'/etc/ssl/private/client.p8':
    ensure  => file,
    mode    => '0400',
    content => "$filebeat_key",
  }

  class { 'filebeat':
    outputs => {
      'logstash' => {
        'hosts'                       => [ "${logstash_server}:5000" ],
        'ssl.certificate_authorities' => [ '/etc/ssl/certs/ca.crt' ],
        'ssl.certificate'             => '/etc/ssl/certs/client.crt',
        'ssl.key'                     => '/etc/ssl/private/client.p8',

      },
    },
    manage_repo    => true,
    package_ensure => latest,
    subscribe      => [ File['/etc/ssl/certs/ca.crt'],
                        File['/etc/ssl/certs/client.crt'],
                        File['/etc/ssl/private/client.p8'],
                      ],
 
  }

  filebeat::prospector { 'syslogs':
    paths => [
      '/var/log/syslog',
    ],
    doc_type => 'syslog-beat',
  }

}

