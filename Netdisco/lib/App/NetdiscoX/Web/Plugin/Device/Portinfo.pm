package App::NetdiscoX::Web::Plugin::Device::Portinfo;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use List::MoreUtils ();

use App::Netdisco::Web::Plugin;

use File::Share ':all';
register_template_path(
  dist_dir( 'App-NetdiscoX-Web-Plugin-Device-Portinfo' ));
register_css('portinfo');
register_javascript('portinfo');

# Device port column for port cable info
use constant PORT_COLUMNS => qw/
  room building jack riser1 pairs1 riser2 pairs2 cable
  grid wired comment/;

register_device_port_column({ name => 'yorkportinfo_room', 
	label => 'Room',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_building', 
	label => 'Building',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_jack', 
	label => 'Cable',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_riser1', 
	label => 'Riser 1',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_pairs1', 
	label => 'Pair 1',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_riser2', 
	label => 'Riser 2',
	position => 'right',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_pairs2', 
	label => 'Pair 2',
	position => 'right',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_cable', 
	label => 'Pigtail',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_grid', 
	label => 'Floor Grid',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_wired', 
	label => 'Wired',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_comment', 
	label => 'Comment',
	position => 'right',
	default => 'on' });

get '/ajax/portinfocontrol' => require_role port_control => sub {
  my $column = param('column');
  my $value = param('value');
  send_error('Bad port info column') unless grep { $_ eq $column } PORT_COLUMNS;
  my $device = schema('netdisco')->resultset('Device')
    ->search_for_device(param('device')) 
    or send_error('Bad device', 400);
  my $port = $device->ports->search({port => param('port')})->first()
    or send_error('Bad Port', 400);  
  
  $port->update_or_create_related("port_info", { "$column" => "$value" }); 
  
  template 'plugin/portinfo/portinfo.tt', {
  
    
  }, {layout => undef};
};

1;
