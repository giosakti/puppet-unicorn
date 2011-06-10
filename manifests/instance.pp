define unicorn::instance(
  $basedir,
  $worker_processes = 4,
  $socket_path = nil,
  $socket_backlog = 64,
  $port = nil,
  $tcp_nopush = true,
  $timeout = 60,
  $preload_app = true,
  $rails = false,
  $rolling_restarts = true,
  $rolling_restarts_sleep = 1,
  $debug_base_port = nil,
  $after_fork_extras = nil,
  $command = 'unicorn',
  $env = 'production',
  $uid = 'root',
  $gid = 'root',
  $monit_extras = nil
) {

  $real_command = $rails ? {
    true  => "${command}_rails",
    false => $command
  }

  file {
    "${name}_unicorn.conf":
      path    => "${basedir}/config/unicorn.conf.rb",
      mode    => 644,
      owner   => $uid,
      group   => $gid,
      content => template('unicorn/unicorn.conf');
  }

  $process_name = $name
  if $use_monit {
    if $socket_path {
      $check_socket = "if failed unixsocket ${socket_path} then alert"
    }

    if $port {
      $check_port = "if failed host localhost port ${port}\n    protocol HTTP request \"/monit_test\"\n    with timeout ${timeout}\n    then restart"
    }

    monit::check::process {
      "${process_name}_unicorn":
        pidfile => "$basedir/tmp/pids/unicorn.pid",
        start   => "/bin/sh -c '$command master -E $env -c $basedir/config/unicorn.conf.rb -D'",
        start_extras => "as uid $uid and gid $gid",
        stop    => "/bin/sh -c 'kill `cat $basedir/tmp/pids/unicorn.pid`'",
        customlines => [$check_socket, $check_port, $monit_extras, "group ${process_name}_unicorn"];
    }
  }
  else {
    service {
      "${process_name}_unicorn":
        provider  => 'base',
        start     => "$command master -E $env -c $basedir/config/unicorn.conf.rb -D",
        stop      => "kill `cat $basedir/tmp/pids/unicorn.pid`",
        restart   => "kill -s USR2 `cat $basedir/tmp/pids/unicorn.pid`",
        status    => "ps -o pid= -o comm= -p `cat $basedir/shared/pids/unicorn.pid`",
        ensure    => 'running',
        subscribe => File["${name}_unicorn.conf"];
    }
  }
}
