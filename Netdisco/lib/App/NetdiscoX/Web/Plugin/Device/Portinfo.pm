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
  grid wired comment phoneext/;

register_device_port_column({ name => 'yorkportinfo_room', 
	label => 'Room',
	position => 'mid',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_jack', 
	label => 'Cable',
	position => 'mid',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_building', 
	label => 'Building',
	position => 'mid',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_riser1', 
	label => 'Riser Room 1',
	position => 'mid',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_pairs1', 
	label => 'Pairs 1',
	position => 'mid',
	default => 'Off' });
register_device_port_column({ name => 'yorkportinfo_riser2', 
	label => 'Riser Room 2',
	position => 'mid',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_pairs2', 
	label => 'Pairs 2',
	position => 'mid',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_cable', 
	label => 'Pigtail',
	position => 'mid',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_grid', 
	label => 'Grid',
	position => 'mid',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_comment', 
	label => 'Comment',
	position => 'right',
	default => 'off' });
register_device_port_column({ name => 'yorkportinfo_lastupdatedcable', 
	label => 'Last Updated (Cable)',
	position => 'right',
	default => 'on' });
register_device_port_column({ name => 'yorkportinfo_lastupdatedbycable', 
	label => 'Last Updated By (Cable)',
	position => 'right',
	default => 'on' });

my %DB_TO_HUMAN_NAME = (
  cable => "Pigtail",
  jack => "Horizontal Cable",
  room => "Room",
  riser1 => "Riser Room 1",
  riser2 => "Riser Room 2",
  pairs1 => "Pairs 1",
  pairs2 => "Pairs 2",
  grid => "Grid",
  phoneext => "Phone Extension",
  comment => "Comment"
);

ajax '/ajax/portinfocontrol' => require_role port_control => sub {
  my $column = param('column');
  my $value = param('value');
  send_error('Bad port info column') unless grep { $_ eq $column } PORT_COLUMNS;
  my $device = schema('netdisco')->resultset('Device')
    ->search_for_device(param('device')) 
    or send_error('Bad device', 400);
  my $port = $device->ports->search({port => param('port')})->first()
    or send_error('Bad Port', 400);  

  if ($column eq 'building'){
    my $oldbuildingname = "";
    if ($port->port_info 
        and $port->port_info->building 
        and $port->port_info->building->official_name) {
      $oldbuildingname = $port->port_info->building->official_name->name;
    }
    my $buildings = schema('netdisco')->resultset('Building')
      ->search(
        { "building_names.name" => $value },
        { prefetch => "building_names" }
      );
    send_error('Bad building', 400) unless ($buildings->count == 1);
    my $building = $buildings->first;
    my $newbuildingname = $building->official_name->name;
    
    $port->update_or_create_related("port_info",
      {
        "building_campus" => $building->campus,
        "building_num"    => $building->num,
        "last_modified" => \'NOW()',
        "last_modified_by" => session('logged_in_user')
      });
    $port->create_related("logs",
      {
        log => "Building changed from '$oldbuildingname' "
                  . "to '$newbuildingname'",
        reason => "other",
        action => "cable change",
        username => session('logged_in_user'),
        userip => request->address
      });
  } else {
    my $oldvalue = "";
    if ($port->port_info and $port->port_info->$column){
       $oldvalue = $port->port_info->$column;
    }
    
    # column name for humans to read
    my $columnname = $DB_TO_HUMAN_NAME{$column};
    
    $port->update_or_create_related("port_info", 
      {
        "$column" => "$value",
        "last_modified" => \'NOW()',
        "last_modified_by" => session('logged_in_user')
      }); 
    $port->create_related("logs",
      {
        log => "$columnname changed from '$oldvalue' "
                  . "to '$value'",
        reason => "other",
        action => "cable change",
        username => session('logged_in_user'),
        userip => request->address
      });

  }
  
  content_type('text/plain');
  template 'plugin/portinfo/portinfo.tt', {}, {layout => undef};
};

get '/ajax/plugin/buildings' => require_login sub {
  my @results = schema('netdisco')->resultset('Building')
    ->search({},
      {
        
        join => qw/portinfos/,
        '+select' => [ { count => 'port' }],
        '+as' => [ qw /count/ ],
        group_by => [qw/campus num/],
        having => \'count(port) > 0'
      })
    ->search({},
      {    
        prefetch => [qw/official_name short_name uit_name other_names/],
        order_by => "official_name.name"
      })->hri->all;

  content_type('text/json');
  template 'plugin/portinfo/buildings.tt', 
    { results => \@results },
    { layout => undef };
};

1;
