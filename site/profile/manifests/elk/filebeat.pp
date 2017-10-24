class profile::elk::filebeat {
  
  $logstash_server = lookup('profile::elk::logstash_server')

  class { 'filebeat':
    outputs => {
      'logstash' => {
        'hosts'  => [ "${logstash_server}:5000" ],
      },
    },
    manage_repo => true,
    package_ensure => latest,
  }

  filebeat::prospector { 'syslogs':
    paths => [
      '/var/log/syslog',
    ],
    doc_type => 'syslog-beat',
  }

}
