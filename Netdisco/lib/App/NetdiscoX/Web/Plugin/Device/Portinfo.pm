package App::NetdiscoX::Web::Plugin::Device::Portinfo;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;

register_device_port_column({ name => 'yorkportinfo_room', 
	label => 'Room',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_building', 
	label => 'Building',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_jack', 
	label => 'Wall Jack',
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
	label => 'Cable',
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

1;
