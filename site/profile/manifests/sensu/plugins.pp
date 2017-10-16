class profile::sensu::plugins {
  $community_plugins = lookup("profile::sensu::community_plugins", Hash, "hash")

  $community_plugins.each |$pkg_name, $version| {
    sensu::plugin { $pkg_name:
      type        => 'package',
      pkg_version => $version,
    }
  }
}

