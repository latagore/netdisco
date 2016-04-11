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
  provides_csv => 1
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
  my @dnsmatches;
  
  for my $match (@matches){
    if ($match =~ /^$macregex$/gx) {
      push @macmatches, $match; 
    } elsif ($match =~ /^$ipregex$/gx) {
      push @ipmatches, $match;
    } elsif ($match =~ /^$hostnameregex$/gx){
      push @dnsmatches, $match;
    }
  }

  my @results;
  my $macsearch = schema('netdisco')->resultset('Virtual::NodeNodeIpByMac')->search(
      undef,
      {
        alias => 'me',
        join => 
          {
            'device_port' => [
              {'port_info' => 
                {'building' => 'official_name'}
              },
              'device'
            ]
          },
        '+select' => [qw/device.dns device_port.port port_info.jack port_info.room official_name.name/,
                      \qq/replace( date_trunc( 'minute', age( now(), me.time_last ) ) ::text, 'mon', 'month') AS age/],
        '+as' => [qw/device_port.device.dns device_port.port device_port.port_info.jack device_port.port_info.room device_port.port_info.building.official_name.name/,
                  'age']
      });
  for my $mac(@macmatches){
    my $netmac = NetAddr::MAC->new($mac);
    my $result = [ $macsearch->search(
        undef, { bind => [$netmac->as_ieee] })->hri->all ];
    if (scalar @$result){
      for my $entry (@$result){
        push @results, $entry;
      }
    } else { # push a blank entry to indicate nothing was found
      $result = { ident => $netmac->as_ieee };
      push @results, $result;
    }
  }
  
  
  my $ipsearch = schema('netdisco')->resultset('Virtual::NodeNodeIpByIp')->search(
      undef,
      {
        alias => 'me',
        join => 
          {
            'device_port' => [
              {'port_info' => 
                {'building' => 'official_name'}
              },
              'device'
            ]
          },
        '+select' => [qw/device.dns device_port.port port_info.jack port_info.room official_name.name/,
                      \qq/replace( date_trunc( 'minute', age( now(), me.time_last ) ) ::text, 'mon', 'month') AS age/],
        '+as' => [qw/device_port.device.dns device_port.port device_port.port_info.jack device_port.port_info.room device_port.port_info.building.official_name.name/,
                  'age']
      });
  for my $ip(@ipmatches){
    my $netip = NetAddr::IP->new($ip);
    my $result = [ $ipsearch->search(
        undef, { bind => [$netip->addr] })->hri->all ];
    if (scalar @$result){
      for my $entry (@$result){
        push @results, $entry;
      }
    } else { # push a blank entry to indicate nothing was found
      $result = { ident => $netip->addr };
      push @results, $result;
    }
  }
  
    my $dnssearch = schema('netdisco')->resultset('Virtual::NodeNodeIpByDns')->search(
      undef,
      {
        alias => 'me',
        join => 
          {
            'device_port' => [
              {'port_info' => 
                {'building' => 'official_name'}
              },
              'device'
            ]
          },
        '+select' => [qw/device.dns device_port.port port_info.jack port_info.room official_name.name/,
                      \qq/replace( date_trunc( 'minute', age( now(), me.time_last ) ) ::text, 'mon', 'month') AS age/],
        '+as' => [qw/device_port.device.dns device_port.port device_port.port_info.jack device_port.port_info.room device_port.port_info.building.official_name.name/,
                  'age']
      });
  for my $dns(@dnsmatches){
    # two bind identical values because need to filter subquery
    # to improve performance..
    my $result = [ $dnssearch->search(
        undef, { bind => [$dns, $dns] })->hri->all ];
    if (scalar @$result){
      for my $entry (@$result){
        push @results, $entry;
      }
    } else { # push a blank entry to indicate nothing was found
      $result = { ident => $dns };
      push @results, $result;
    }
  }
  return [@results];
}

post '/ajax/content/report/nodelocation' => require_login sub {

    my $q;
    my $file = request->upload('file');
    if ($file){
      $q = $file->content;
    } else {
      send_error('must provide a valid query', 400);
    }

    my $node_rs = get_nodes($q, param('n_archived'));

    my @results = @$node_rs;

    return unless scalar @results;
    
    if ( request->is_ajax ) {
        my $json = to_json( \@results );
        template 'plugin/nodelocation/nodelocation.tt', 
            { 
              results => $json
            },
            { layout => undef };
    }
    else {
       header( 'Content-Type' => 'text/comma-separated-values' );
       template 'plugin/nodelocation/nodelocation_csv.tt', { results => \@results, },
           { layout => undef };
    }
};

1;
