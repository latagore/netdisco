package App::Netdisco::Web::Plugin::Search::Ports;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use App::Netdisco::Util::Web 'sql_match';
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
      my $match = '^'
          . quotemeta($q)
          . "(\\..+)*";
      if (index($q, setting('domain_suffix')) == -1){
        $match .= setting('domain_suffix')
                           .'$';
      } else {
        $match .= '$';
      }

      my $nodemac = NetAddr::MAC->new(mac => $q);
      my $nodeip = NetAddr::IP->new($q);
      my @node_where;
      if (defined $nodemac and !$nodemac->errstr) {
        @node_where = ('me.mac' => $nodemac->as_ieee);
      } elsif (defined $nodeip and defined $nodeip->addr) {
        @node_where = ('ips.ip' => $nodeip->addr);
      } else {
        @node_where = ('ips.dns' => { '~*' => $match });
      }
      
      my $search_archived = param('f_node_archived');
      if (defined $search_archived and $search_archived eq 'on'){
        params->{n_archived} = 'checked';
      } else {
        delete params->{n_archived};
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
      # godly regex for matching MAC addresses of IEEE, Microsoft, Cisco and SUN formats.
      my $hex = '[0-9a-fA-F]';
      my $alnum = '[a-zA-Z0-9]';
      my $seg4 = '(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])';# octet for ipv4
      my $seg6 = "${hex}{1,4}"; #equivalent for ipv6

      my $macregex = "((?:(?:(?:${hex}{1,2}([-:]))(?:${hex}{1,2}\\g{-1}){4}${hex}{1,2}))
      |(?:(?:(?:${hex}{4}(\\.))(?:${hex}{4}\\g{-1})${hex}{4})))";
      my $ipv4regex = "(${seg4}\\.){3,3}${seg4}";
      # even more godly regex for matching IPV4 and IPV6 addresses
      my $ipregex = "
      (
      (${seg6}:){7,7}${seg6}|
      (${seg6}:){1,7}:|
      (${seg6}:){1,6}:${seg6}|
      (${seg6}:){1,5}(:${seg6}){1,2}|
      (${seg6}:){1,4}(:${seg6}){1,3}|
      (${seg6}:){1,3}(:${seg6}){1,4}|
      (${seg6}:){1,2}(:${seg6}){1,5}|
      ${seg6}:((:${seg6}){1,6})|
      :((:${seg6}){1,7}|:)|
      fe08:(:${seg6}){2,2}%${alnum}{1,}|
      ::(ffff(:0{1,4}){0,1}:){0,1}$ipv4regex|
      (${seg6}:){1,4}$ipv4regex:|
      $ipv4regex
      )";
      my $hostnameregex = 
      "((${alnum}|${alnum}[a-zA-Z0-9\\-]{0,61}${alnum})
      (\\.(${alnum}|${alnum}[a-zA-Z0-9\\-]{0,61}${alnum}))*)";
      
      my $begin_regex = '(?<![a-zA-Z0-9:.\\-])';
      my $end_regex='(?![a-zA-Z0-9:.\\-%])';
      
      # get a list of all valid entries and classify them after to preserve order
      my @matches;
      while ($fnode =~ /
          ${begin_regex}
          (${macregex}|${ipregex}|${hostnameregex})
          ${end_regex}/gx)
      {
        push @matches, $1;
      }
      
      my @macmatches;
      my @ipmatches;
      my @hostnamematches;
      
      for my $match (@matches){
        if ($match =~ /^$macregex$/gx) {
          push @macmatches, $match; 
        } elsif ($match =~ /^$ipregex$/gx) {
          push @ipmatches, $match;
        } elsif ($match =~ /^$hostnameregex$/gx){
          push @hostnamematches, $match;
        }
      }
      
      
      my @nodewhere;
      my @nodeipwhere;
      for my $match (@macmatches){
        my $mac = NetAddr::MAC->new($match);
        push @nodewhere, {"nodes.mac" => $mac->as_ieee};
      }
      for my $match (@ipmatches){
        my $ip = NetAddr::IP->new($match);
        push @nodeipwhere, {"ips.ip" => $ip->addr};
      }
      for my $match (@hostnamematches){
        my $uc_match = uc $match; # upper case
        push @nodeipwhere, 
          \["upper(ips.dns) like ?", "${uc_match}%"];
      }

      my %where;
      my $search_archived = param('f_node_archived');
      if (defined $search_archived and $search_archived eq 'on'){
        params->{n_archived} = 'checked';
      } else {
        delete params->{n_archived};
          $where{'nodes.active'} = 'true'; 
      }


      my $node_rs = schema('netdisco')->resultset('Node')->search(
          {
            -and => [
                {"-or" => \@nodewhere},
                \%where
              ]
          },
          {
            columns => [qw/switch port/],
            alias => "nodes"
          }
        );
      my $node_ip_rs = schema('netdisco')->resultset('Node')->search(
          {
            -and => [
                {"-or" => \@nodeipwhere},
                \%where
              ]
          },
          {
            columns => [qw/switch port/],
            alias => "nodes",
            join => "ips"
          }
        );
      
      my $node_port_rs;
      if (scalar @nodewhere and scalar @nodeipwhere){
        $node_port_rs = $node_rs->union($node_ip_rs);
      } elsif (scalar @nodewhere) {
        $node_port_rs = $node_rs;
      } elsif (scalar @nodeipwhere) {
        $node_port_rs = $node_ip_rs;
      }
      $set = $set->search(
          {
            "(me.ip, me.port)" => 
                { "-in" => $node_port_rs->as_query }
          }
        );
      return unless $set->count;
    }
    
    # refine by vlan if requested
    my $fvlan = param('vlan');
    if ($fvlan) {
      $set = $set->search({
        -or => {
          'me.vlan' => $fvlan,
          'port_vlans.vlan' => $fvlan},
        }, { join => 'port_vlans' }
      );
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
          "building_names.name" => {-ilike => scalar sql_match($building)}
      },
      {
        prefetch => { "port_info" => { building =>  "building_names" } }
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
    # filter by port description
    my $descr = param('descr');
    if ($descr){
      $set = $set->search(
      {
        # port description is name in the database
        "me.name" =>  {-ilike => scalar sql_match($descr)}
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

    # retrieve node count if asked for
    $set = $set->with_node_count if param('c_nodes') and param('n_archived');
    $set = $set->with_active_node_count if param('c_nodes') and not param('n_archived');
    
    # put in the York specific port information
    $set = $set->with_york_port_info;

    # get the one-to-many information like VLANs and some nodes
    my @extra_rs;
    if (param('c_vmember')){
      my $vlans = $set->search(undef, 
        {
          columns => ['me.ip', 'me.port'],
          prefetch => 'all_port_vlans' 
        });
      push @extra_rs, $vlans;
    }
    
    if (param('c_nodes')) {
      my $nodes = $set;
      if (param('n_archived')) {
        $nodes = $nodes->search(undef,
        {
          prefetch => { 'nodes_with_age' => [ 'ips', 'oui' ] }
        });
      } else {
        $nodes = $nodes->search(undef,
        {
          prefetch => { 'active_nodes_with_age' => [ 'ips', 'oui' ] }
        });
      }

      push @extra_rs, $nodes;
    }
    
    debug "### SORT";

    # sort ports (empty set would be a 'no records' msg)
    my @results = sort { &App::Netdisco::Util::Web::sort_device_and_port($a, $b) } $set->merge_rs(\@extra_rs);
    #my @results = $set->hri->all;
    return unless scalar @results;
    debug (scalar @results);
    debug "### DONE SORT, START JSON RENDER";
    
    my $json =  to_json(\@results);
    debug length $json;
    if (request->is_ajax) {
        template 'ajax/search/ports-json.tt', {
          results => $json,
          nodes_name => $nodes_name
        }, { layout => undef };
    }
    else {
        header( 'Content-Type' => 'text/comma-separated-values' );
        template 'ajax/search/ports_csv.tt', {
          results => @results,
          nodes_name => $nodes_name
        }, { layout => undef };
    }
};

1;
