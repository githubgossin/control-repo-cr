class role::manager {

  include profile::base_linux
  include profile::puppetdb
  include profile::dns::server

}
