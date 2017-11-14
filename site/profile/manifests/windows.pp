class profile::windows {

  exec { 'forest_time_sync':
    command  => 'w32tm /config /computer:dsc.borg.trek /manualpeerlist:time.windows.com  /syncfromflags:manual /update',
    onlyif   => 'if (w32tm /query /peers | findstr time.windows.com) {exit 1} else {exit 0}',
    provider => powershell,
  }

}

