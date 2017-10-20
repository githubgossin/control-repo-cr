class role::grafana {

  include profile::base_linux
  include profile::graphite::grafana
}
