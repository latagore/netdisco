package App::Netdisco::Web::Plugin::Search::Ports;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use App::Netdisco::Util::Web 'sql_match';
use Data::Dumper;
register_search_tab( { tag => 'ports', label => 'Port', provides_csv => 1 } );

# device ports with a description (er, name) matching
get '/ajax/content/search/ports' => require_login sub {
    my $q = param('q');
    my $prefer = param('prefer');
    $prefer = ''
      unless defined $prefer and $prefer =~ m/^(?:port|name|vlan)$/;

    my $device = schema('netdisco')->resultset('Device');
    
    my $set;
    
    # if searching for q finds a device, use it. otherwise, use it as a filter
    if ($device->search_for_device($q)){
      $device = $device->search_for_device($q);
      $set = $device->ports;
    } elsif ( $q =~ m/^\d+$/ ) {
      $set= schema('netdisco')->resultset('DevicePort')
          ->search(
          { "port_vlans.vlan" => $q },
          {   
              join       => [qw/ port_vlans /]
          }
          );
    } else {
      my ( $likeval, $likeclause ) = sql_match($q);
       $set = schema('netdisco')->resultset('DevicePort')
          ->search(
          {   -or => [
                  { "me.name" => ( param('partial') ? $likeclause : $q ) },
                  (   length $q == 17
                      ? { "me.mac" => $q }
                      : \[ 'me.mac::text ILIKE ?', $likeval ]
                  ),
                  { "me.remote_id"   => $likeclause },
                  { "me.remote_type" => $likeclause },
                  { "device.dns" => $likeclause }
              ]
          },
          {   
              join       => [qw/ port_vlans device /]
          }
          );
    }
   
    my $ports = $set;
    my $port_vlans = $set->search(undef,
      {
        prefetch => "port_vlans"
      });
    
    # add information about the devices for the ports
    $set = $set->search(undef, 
    {
      '+columns' => ["device.ip", "device.dns"],
      join => "device"
    });
     
    # refine by ports if requested
    my $f = param('f');
    if ($f) {
        if (($prefer eq 'vlan') or not $prefer and $f =~ m/^\d+$/) {
            if (param('invert')) {
                $set = $set->search({
                  'me.vlan' => { '!=' => $f },
                  'port_vlans.vlan' => [
                    '-or' => { '!=' => $f }, { '=' => undef }
                  ],
                }, { join => 'port_vlans' });
            }
            else {
                $set = $set->search({
                  -or => {
                    'me.vlan' => $f,
                    'port_vlans.vlan' => $f,
                  },
                }, { join => 'port_vlans' });
            }

            return unless $set->count;
        }
        else {
            if (param('partial')) {
                # change wildcard chars to SQL
                $f =~ s/\*/%/g;
                $f =~ s/\?/_/g;
                # set wilcards at param boundaries
                if ($f !~ m/[%_]/) {
                    $f =~ s/^\%*/%/;
                    $f =~ s/\%*$/%/;
                }
                # enable ILIKE op
                $f = { (param('invert') ? '-not_ilike' : '-ilike') => $f };
            }
            elsif (param('invert')) {
                $f = { '!=' => $f };
            }

            if (($prefer eq 'port') or not $prefer and
                $set->search({'me.port' => $f})->count) {

                $set = $set->search({
                  -or => [
                    'me.port' => $f,
                    'me.slave_of' => $f,
                  ],
                });
            }
            else {
                $set = $set->search({'me.name' => $f});
                return unless $set->count;
            }
        }
    }

    # filter for port status if asked
    my %port_state = map {$_ => 1}
      (ref [] eq ref param('port_state') ? @{param('port_state')}
        : param('port_state') ? param('port_state') : ());

    return unless scalar keys %port_state;

    if (exists $port_state{free}) {
        if (scalar keys %port_state == 1) {
            $set = $set->only_free_ports({
              age_num => (param('age_num') || 3),
              age_unit => (param('age_unit') || 'months')
            });
        }
        else {
            $set = $set->with_is_free({
              age_num => (param('age_num') || 3),
              age_unit => (param('age_unit') || 'months')
            });
        }
        delete $port_state{free};
    }

    if (scalar keys %port_state < 3) {
        my @combi = ();

        push @combi, {'me.up' => 'up'}
          if exists $port_state{up};
        push @combi, {'me.up_admin' => 'up', 'me.up' => { '!=' => 'up'}}
          if exists $port_state{down};
        push @combi, {'me.up_admin' => { '!=' => 'up'}}
          if exists $port_state{shut};

        $set = $set->search({-or => \@combi});
    }

    # filter by building
    my $building = param('building');
    if ($building){
      $set = $set->search(
      {
        "port_info.building" => {-ilike => scalar sql_match($building)}
      },
      {
        join => "port_info"
      });
    }
    # filter by riser room
    my $riserroom = param('riserroom');
    if ($riserroom){
      $set = $set->search(
      {
        "port_info.riser1" => $riserroom
      },
      {
        join => "port_info"
      });
    }
    # filter by horizontal cable
    my $cable = param('cable');
    if ($cable){
      $set = $set->search(
      {
        "port_info.jack" => $cable
      },
      {
        join => "port_info"
      });
    }
    # filter by pigtail
    my $pigtail = param('pigtail');
    if ($pigtail){
      $set = $set->search(
      {
        "port_info.cable" => $pigtail
      },
      {
        join => "port_info"
      });
    }


    # get aggregate master status
    $set = $set->search({}, {
      'join' => 'agg_master',
      '+select' => [qw/agg_master.up_admin agg_master.up/],
      '+as'     => [qw/agg_master_up_admin agg_master_up/],
    });

    # make sure query asks for formatted timestamps when needed
    $set = $set->with_times if param('c_lastchange');

    # get vlans on the port, if there aren't too many
    my $port_cnt = $ports->count() || 1;
    my $vlan_cnt = $port_vlans->count() || 1;
    my $vmember_ok =
      (($vlan_cnt / $port_cnt) <= setting('devport_vlan_limit'));

    if ($vmember_ok) {
        $set = $set->search_rs({}, { prefetch => 'all_port_vlans' })->with_vlan_count
          if param('c_vmember');
    }

    # die join "\n", $set->{vlan_count};

    # what kind of nodes are we interested in?
    my $nodes_name = (param('n_archived') ? 'nodes' : 'active_nodes');
    $nodes_name .= '_with_age' if param('c_nodes') and param('n_age');
    $set = $set->search_rs({}, { order_by => ["${nodes_name}.vlan", "${nodes_name}.mac", "ips.ip"] })
      if param('c_nodes');

    # retrieve active/all connected nodes, if asked for
    $set = $set->search_rs({}, { prefetch => [{$nodes_name => 'ips'}] })
      if param('c_nodes');

    # retrieve wireless SSIDs, if asked for
    $set = $set->search_rs({}, { prefetch => [{$nodes_name => 'wireless'}] })
      if param('c_nodes') && param('n_ssid');

    # retrieve NetBIOS, if asked for
    $set = $set->search_rs({}, { prefetch => [{$nodes_name => 'netbios'}] })
      if param('c_nodes') && param('n_netbios');

    # retrieve vendor, if asked for
    $set = $set->search_rs({}, { prefetch => [{$nodes_name => 'oui'}] })
      if param('c_nodes') && param('n_vendor');

    # retrieve SSID, if asked for
    $set = $set->search({}, { prefetch => 'ssid' }) if param('c_ssid');

    # retrieve neighbor devices, if asked for
    $set = $set->search_rs({}, { prefetch => [{neighbor_alias => 'device'}] })
      if param('c_neighbors');

    # put in the York specific port information
    $set = $set->with_york_port_info;

    # sort ports (empty set would be a 'no records' msg)
    my $results = [ sort { &App::Netdisco::Util::Web::sort_port($a->port, $b->port) } $set->all ];
    return unless scalar @$results;

    if (request->is_ajax) {
        template 'ajax/search/ports.tt', {
          results => $results,
          nodes => $nodes_name,
          device => $device,
          vmember_ok => $vmember_ok,
        }, { layout => undef };
    }
    else {
        header( 'Content-Type' => 'text/comma-separated-values' );
        template 'ajax/search/ports_csv.tt', {
          results => $results,
          nodes => $nodes_name,
          device => $device,
        }, { layout => undef };
    }
};

1;
