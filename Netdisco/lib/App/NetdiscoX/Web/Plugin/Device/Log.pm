package App::NetdiscoX::Web::Plugin::Device::Log;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;

use File::Share ':all';
register_template_path(
  dist_dir( 'App-NetdiscoX-Web-Plugin-Device-Log' ));
register_css('log');


register_device_tab({ tag => 'log', label => 'Log' });

# log table
ajax '/ajax/content/device/log' => require_login sub {
    my $q = param('q');
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($q) or send_error('Bad device', 400);

    my @results
        = schema('netdisco')->resultset('DeviceLog')
        ->search( { 'ip' => $device->ip } )
        ->hri->all;
    
    content_type('text/html');
    my $json = to_json( \@results );
    template 'ajax/device/log.tt', {
      results => $json
    }, { layout => undef };
};

1;
