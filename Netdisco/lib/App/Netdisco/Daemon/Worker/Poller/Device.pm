package App::Netdisco::Daemon::Worker::Poller::Device;

use Dancer qw/:moose :syntax :script/;
use Dancer::Plugin::DBIC 'schema';

use App::Netdisco::Util::SNMP 'snmp_connect';
use App::Netdisco::Util::Device qw/get_device is_discoverable/;
use App::Netdisco::Core::Discover ':all';
use App::Netdisco::Daemon::Util ':all';

use NetAddr::IP::Lite ':lower';

use Role::Tiny;
use namespace::clean;

# queue a discover job for all devices known to Netdisco
sub discoverall {
  my ($self, $job) = @_;

  my $devices = schema('netdisco')->resultset('Device')->get_column('ip');
  my $jobqueue = schema('netdisco')->resultset('Admin');

  schema('netdisco')->txn_do(sub {
    # clean up user submitted jobs older than 1min,
    # assuming skew between schedulers' clocks is not greater than 1min
    $jobqueue->search({
        action => 'discover',
        status => 'queued',
        entered => { '<' => \"(now() - interval '1 minute')" },
    })->delete;

    # is scuppered by any user job submitted in last 1min (bad), or
    # any similar job from another scheduler (good)
    $jobqueue->populate([
      map {{
          device => $_,
          action => 'discover',
          status => 'queued',
          username => $job->username,
          userip => $job->userip,
      }} ($devices->all)
    ]);
  });

  return job_done("Queued discover job for all devices");
}

# run a discover job for one device, and its *new* neighbors
sub discover {
  my ($self, $job) = @_;

  my $host = NetAddr::IP::Lite->new($job->device);
  my $device = get_device($host->addr);
  my $jobqueue = schema('netdisco')->resultset('Admin');

  if ($device->ip eq '0.0.0.0') {
      return job_error("discover failed: no device param (need -d ?)");
  }

  if ($device->in_storage
      and $device->vendor and $device->vendor eq 'netdisco') {
      return job_done("discover skipped: $host is pseudo-device");
  }

  unless (is_discoverable($device->ip)) {
      return job_defer("discover deferred: $host is not discoverable");
  }

  my $snmp = snmp_connect($device);
  if (!defined $snmp) {
      return job_error("discover failed: could not SNMP connect to $host");
  }

  store_device($device, $snmp);
  store_interfaces($device, $snmp);
  store_wireless($device, $snmp);
  store_vlans($device, $snmp);
  store_power($device, $snmp);
  store_modules($device, $snmp) if setting('store_modules');
  discover_new_neighbors($device, $snmp);

  # if requested, and the device has not yet been arpniped/macsucked, queue now
  if ($device->in_storage and $job->subaction and $job->subaction eq 'with-nodes') {
      if (!defined $device->last_macsuck) {
          schema('netdisco')->txn_do(sub {
            $jobqueue->create({
              device => $device->ip,
              action => 'macsuck',
              status => 'queued',
              username => $job->username,
              userip => $job->userip,
            });
          });
      }

      if (!defined $device->last_arpnip) {
          schema('netdisco')->txn_do(sub {
            $jobqueue->create({
              device => $device->ip,
              action => 'arpnip',
              status => 'queued',
              username => $job->username,
              userip => $job->userip,
            });
          });
      }
  }

  return job_done("Ended discover for ". $host->addr);
}

1;