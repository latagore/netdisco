package App::Netdisco::Web::Plugin::Search::Ports;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use App::Netdisco::Util::Web 'sql_match';
use Data::Dumper;
register_search_tab( { tag => 'ports', label => 'Port', provides_csv => 1 } );

sub sql_match_leading_zeros {
  my ($term) = @_;
  return { '~*' => '(\D|\m)0*'.$term.'(\D|\M)'}
}

# device ports with a description (er, name) matching
get '/ajax/content/search/ports' => require_login sub {
    my $q = param('q');
    send_error( 'Missing query', 400 ) unless
      (
        $q or
        param('building') or
        param('cable') or
        param('pigtail') or
        param('riserroom') or 
        param('room') or 
        param('vlan') or 
        param('node') or 
        param('port')
      );

    my $prefer = param('prefer');
    $prefer = ''
      unless defined $prefer and $prefer =~ m/^(?:port|name|vlan)$/;

    my $device = schema('netdisco')->resultset('Device');
    
    my $set = schema('netdisco')->resultset('DevicePort');
    
    # if searching for q finds a device, use it. otherwise, use it as a filter
    if (defined $q and $device->search_for_device($q)){
      $set = $device->search_for_device($q)->ports;
    } elsif ( $q =~ m/^\d+$/ ) {
      $set = $set->search(
          { "port_vlans.vlan" => $q },
          {   
              join       => [qw/ port_vlans /]
          }
          );
    } elsif ($q) {
      # find nodes by q
      my $match = sql_match($q);
      my $nodemac = NetAddr::MAC->new(mac => $q);
      my $nodeip = NetAddr::IP->new($q);
      my @node_where;
      if (defined $nodemac and !$nodemac->errstr) {
        @node_where = ('me.mac' => $nodemac->as_ieee);
      } elsif (defined $nodeip and defined $nodeip->addr) {
        @node_where = ('ips.ip' => $nodeip->addr);
      } else {
        @node_where = ('ips.dns' => { -ilike => $match });
      }
      
      my $search_archived = param('f_node_archived');
      if (defined $search_archived and $search_archived eq 'on'){
        params->{n_archive} = 'on';
      } else {
        params->{n_archive} = 'off';
        push @node_where, 'me.active', 'true'; 
      }
       
      my $node_set = schema('netdisco')->resultset('Node')
                        ->search(
                          {@node_where},
                          { join => 'ips'}
                        );
      
      # search for ports
      my ( $likeval, $likeclause ) = sql_match($q);
      my $mac = NetAddr::MAC->new($q);

      $set = $set->search(
         {
           -or => [
             { "me.name" => ( $likeclause ) },
             ((defined $mac and !($mac->errstr))
               ? { "me.mac" => $mac->as_ieee }
               : \[ 'me.mac::text ILIKE ?', $likeval ]
             ),
             { "me.remote_id"   => $likeclause },
             { "me.remote_type" => $likeclause },
             { 
               "(me.ip, me.port)" => { -in => $node_set
                   ->search_rs(undef, {columns => "me.switch, me.port"})
                   ->as_query 
                 }
             }
           ]
         },
         {   
             join       => [qw/ port_vlans device /]
         }
         );
    }
   
    # refine by node if requested
    my $fnode = param('node');
    if ($fnode) {
      my $match = sql_match($fnode);

      #define DBI where clauses
      my $nodemac = NetAddr::MAC->new(mac => $fnode);
      my $nodeip = NetAddr::IP->new($fnode);
      my @where;
      if (defined $nodemac and !$nodemac->errstr) {
        @where = ('nodes.mac' => $nodemac->as_ieee);
      } elsif (defined $nodeip and defined $nodeip->addr) {
        @where = ('ips.ip' => $nodeip->addr);
      } else {
        @where = ('ips.dns' => { -ilike => $match });
      }
      
      my $search_archived = param('f_node_archived');
      if (defined $search_archived and $search_archived eq 'on'){
        params->{n_archive} = 'on';
      } else {
        params->{n_archive} = 'off';
        push @where, 'nodes.active', 'true'; 
      }

      $set = $set->search({@where}, 
        { 
          join => { 'nodes' => 'ips' }
        });
      return unless $set->count;
    }
    
    # refine by vlan if requested
    my $fvlan = param('vlan');
    if ($fvlan) {
      if (param('include_trunked_ports') && param('include_trunked_ports') eq 'on') {
        $set = $set->search({
          -or => {
            'me.vlan' => $fvlan,
            'port_vlans.vlan' => $fvlan},
          }, { join => 'port_vlans' });
      } else {
        $set = $set->search({'me.vlan' => $fvlan});
      }
      return unless $set->count;
    }

    # refine by port if requested
    my $fport = param('port');
    if ($fport){
      # change wildcard chars to SQL
      $fport =~ s/\*/%/g;
      $fport =~ s/\?/_/g;
      # set wilcards at param boundaries
      if ($fport !~ m/[%_]/) {
        $fport =~ s/^\%*/%/;
        $fport =~ s/\%*$/%/;
      }
      # enable ILIKE op
      $fport = { (param('invert') ? '-not_ilike' : '-ilike') => $fport };

      $set = $set->search({
        -or => [
          'me.port' => $fport,
          'me.slave_of' => $fport,
        ],
      });
    }
    
    # join building official name if asked for
    $set = $set->search_rs (undef, {
        prefetch => { "port_info" => { building =>  "official_name" } }
    }) if param('yorkportinfo_building');
    
    # filter by building
    my $building = param('building');
    if ($building){
      $set = $set->search(
      {
        "official_name.name" => {-ilike => scalar sql_match($building)}
      },
      {
        prefetch => { "port_info" => { building =>  "official_name" } }
      });
    }
    # filter by riser room
    my $riserroom = param('riserroom');
    if ($riserroom){
      $set = $set->search(
      {
        "port_info.riser1" => sql_match_leading_zeros($riserroom)
      },
      {
        join => "port_info"
      });
    }
    # filter by destination room
    my $room = param('room');
    if ($room){
      $set = $set->search(
      {
        "port_info.room" => sql_match_leading_zeros($room)
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
        "port_info.jack" => sql_match_leading_zeros($cable)
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
        "port_info.cable" => sql_match_leading_zeros($pigtail)
      },
      {
        join => "port_info"
      });
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

    # add information about the devices for the ports
    $set = $set->search(undef, 
    {
      '+columns' => ["device.ip", "device.dns"],
      join => "device"
    });

    # get aggregate master status
    $set = $set->search({}, {
      'join' => 'agg_master',
      '+select' => [qw/agg_master.up_admin agg_master.up/],
      '+as'     => [qw/agg_master_up_admin agg_master_up/],
    });

    # make sure query asks for formatted timestamps when needed
    $set = $set->with_times if param('c_lastchange');

    # what kind of nodes are we interested in?
    my $nodes_name = (param('n_archived') ? 'nodes' : 'active_nodes');
    $nodes_name .= '_with_age' if param('c_nodes') and param('n_age');

    # retrieve power, if asked for
    $set = $set->search_rs({}, { prefetch => 'power' })
      if param('c_power');

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
          nodes_name => $nodes_name
        }, { layout => undef };
    }
    else {
        header( 'Content-Type' => 'text/comma-separated-values' );
        template 'ajax/search/ports_csv.tt', {
          results => $results,
          nodes_name => $nodes_name
        }, { layout => undef };
    }
};

1;
