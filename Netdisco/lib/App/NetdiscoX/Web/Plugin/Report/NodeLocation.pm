package App::NetdiscoX::Web::Plugin::Report::NodeLocation;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use NetAddr::IP::Lite ':lower';

register_report({
  category => 'Node',
  tag => 'nodelocation',
  label => 'Node Location',
});
register_javascript('nodelocation');

use File::Share ':all';

register_template_path
  dist_dir( 'App-NetdiscoX-Web-Plugin-Report-NodeLocation' );
  
sub get_nodes {
  my ($query, $n_archived) = @_;

  # godly regex for matching MAC addresses of IEEE, Microsoft, Cisco and SUN formats.
  my $hex = '[0-9a-fA-F]';
  my $alnum = '[a-zA-Z0-9]';
  my $seg4 = '(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])';# octet for ipv4
  my $seg6 = "${hex}{1,4}"; #equivalent for ipv6

  my $macregex = "((?:(?:(?:${hex}{1,2}([-:]))(?:${hex}{1,2}\\g{-1}){4}${hex}{1,2}))
  |(?:(?:(?:${hex}{4}(\\.))(?:${hex}{4}\\g{-1})${hex}{4}))
  |(?:${hex}{12}))";
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
  (\\.(${alnum}|${alnum}[a-zA-Z0-9\\-]{0,61}${alnum}))+)";
  
  my $begin_regex = '(?<![a-zA-Z0-9:.\\-])';
  my $end_regex='(?![a-zA-Z0-9:.\\-%])';
  
  # get a list of all valid entries and classify them after to preserve order
  my @matches;
  while ($query =~ /
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
  unless (defined $n_archived and $n_archived eq 'on'){
      $where{'nodes.active'} = 'true'; 
  }


  my $node_rs_sub = schema('netdisco')->resultset('Node')->search(
      {
        -and => [
            {"-or" => \@nodewhere},
            \%where
          ]
      },
      {
        columns => 'nodes.mac',
        '+select' => {max => 'nodes.time_last'},
        '+as' => 'time_last',
        alias => "nodes",
        group_by => [qw/nodes.mac/]
      }
    );
  my $node_rs = schema('netdisco')->resultset('Node')->search(
      {
        '(nodes.mac, nodes.time_last)' => {-in => $node_rs_sub->as_query}
      },
      {
        columns => [qw/nodes.mac nodes.switch nodes.port nodes.vlan nodes.time_last nodes.active/],
        select => \'nodes.mac as ident',
        as => 'ident',
        group_by => [qw/nodes.mac nodes.switch nodes.port nodes.vlan nodes.time_last nodes.active/],
        order_by => 'nodes.mac',
        alias => 'nodes'
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
        join => 'ips',
        columns => 'nodes.mac',
        '+select' => {max => 'nodes.time_last'},
        '+as' => 'time_last',
        alias => "nodes",
        group_by => [qw/nodes.mac/]
      }
    );
  $node_ip_rs = schema('netdisco')->resultset('Node')->search(
      {
        '(nodes.mac, nodes.time_last)' => {-in => $node_ip_rs->as_query}
      },
      {
        columns => [qw/nodes.mac nodes.switch nodes.port nodes.vlan nodes.time_last active/],
        select => \'ips.ip as ident',
        as => 'ident',
        group_by => [qw/nodes.mac nodes.switch nodes.port nodes.vlan nodes.time_last active/],
        order_by => 'nodes.mac',
        alias => 'nodes'
      }
    );
  
  my $node_port_rs;
  if (scalar @nodewhere and scalar @nodeipwhere){
    $node_port_rs = $node_rs->union($node_ip_rs);
  } elsif (scalar @nodewhere) {
    $node_port_rs = $node_rs
  } elsif (scalar @nodeipwhere) {
    $node_port_rs = $node_ip_rs;
  }
  $node_port_rs = $node_port_rs->search(undef, {
      '+select'  => 
        \qq/replace( date_trunc( 'minute', age( now(), nodes.time_last ) ) ::text, 'mon', 'month') AS age/
      ,
      '+as' => 'age',
    });
  return $node_port_rs;
}

post '/ajax/content/report/nodelocation' => require_role admin => sub {

    my $q;
    my $file = request->upload('file');
    use Data::Dumper;
    if ($file){
      $q = $file->content;
    } else {
      send_error('must provide a valid query', 400);
    }

    
    my $node_rs = get_nodes($q, param('n_archived'))
      ->search_rs(undef,
        {
          prefetch => [
            {
              'device_port' => [
                {'port_info' => 
                  {'building' => 'official_name'}
                }, 
                'device'
              ]
            },
            'ips'
          ]
        }
      );
    
    my @results = $node_rs->hri->all;
    return unless scalar @results;

    if ( request->is_ajax ) {
        my $json = to_json( \@results );
        template 'plugin/nodelocation/nodelocation.tt', { results => $json },
            { layout => undef };
    }
    #else {
    #    header( 'Content-Type' => 'text/comma-separated-values' );
    #    template 'ajax/report/ipinventory_csv.tt', { results => \@results, },
    #        { layout => undef };
    #}
};

1;
