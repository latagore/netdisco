package App::Netdisco::Web::Plugin::PortQuery;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use App::Netdisco::Util::SNMP 'snmp_connect';
use App::Netdisco::Util::Device 'get_device';

register_javascript('portquery');
register_css('portquery');
register_device_port_column({ name => 'portquery', 
	label => 'Port Query',
	position => 'left',
	default => 'on' });
  
# queries the device by connecting to rancid and executing commands
# and dumps the results into a hash
sub query_device {
  my ($device, $port) = @_;
  
  # create command to send to RANCID
  my $cmd;
  $cmd = "\"show interface $port;";
  $cmd .= "show run interface $port;";
  $cmd .= "show interface $port status;";
  $cmd .= "show interface $port status err-disabled\"";
  
  # execute
  my $out = qx{ssh twix\@harvester.netops.yorku.ca 'sudo /extra/rancid/bin/clogin -f /root/.cloginrc -c $cmd $device'};
  
  my ($prompt) = ($out =~ /^([a-zA-Z0-9_\.\-]+#)/m);
  return undef unless $prompt;
  
  # # parse data and turn into nice little hash
  $out =~ /^(${prompt}show interface(.|[\r\n])+?)${prompt}/m;
  my %result = ();
  $result{details} = $1;
  
  $out =~ /^(${prompt}show run interface(.|[\r\n])+?)${prompt}/m;
  $result{config} = $1;
  
  $out =~ /^(${prompt}show interface ${port} status(.|[\r\n])+?)${prompt}/m;
  $result{status} = $1;
  
  $out =~ /^(${prompt}show interface ${port} status err-disabled(.|[\r\n])+?)${prompt}/m;
  $result{disablereason} = $1;

  return undef unless $result{details}
                      and $result{config}
                      and $result{status}
                      and $result{disablereason};
  return {%result};
}

# allows uploading of port info data from CSV
get '/ajax/content/portquery' => require_login sub {
    my $device = schema('netdisco')->resultset('Device')
       ->search_for_device(param('device')) or send_error('Bad device', 400);
    my $port = param('port') or send_error('missing port', 400);
    
    # make sure the device has this port or malicious users
    # could execute arbitrary commands on the device
    my $device_has_port = false;
    foreach my $entry ($device->ports){
      if ($entry->port eq $port){
        $device_has_port = true;
        last;
      }
    }
    send_error("Bad port", 400) unless $device_has_port;
    
    my $dns = $device->dns;
    
    my $result = query_device($dns, $port);
    return "" unless defined $result;
    
    header( 'Content-Type' => 'text/json' );
    return to_json($result);
};

1;
