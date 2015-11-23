package App::NetdiscoX::Web::Plugin::Device::Age;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;

use File::Share ':all';
register_template_path(
  dist_dir( 'App-NetdiscoX-Web-Plugin-Device-Age' ));
register_css('age');
register_javascript('age');

# ajax for getting device age
ajax '/ajax/deviceage' => require_login sub {
    my $q = param('device');
    my $device = schema('netdisco')->resultset('Device')
      ->search_for_device($q) or send_error('Bad device', 400);
    my $devicesearch = schema('netdisco')->resultset('Device')
                         ->search({'me.ip' => $device->ip});
    
    send_error('Bad device', 400) unless $devicesearch->count == 1;

    # get the age of the last operations in days through DB 
    my $devicewithage = $devicesearch->search(undef,
      {'+columns' => [
        {discover_age => \"extract(day from current_timestamp - last_discover)"},
        {macsuck_age  => \"extract(day from current_timestamp - last_macsuck)"},
        {arpnip_age   => \"extract(day from current_timestamp - last_arpnip)"}
      ]})->first;
                   
    #time since epoch for age
    my %result = (
      discoverAge => $devicewithage->get_column("discover_age"),
      macsuckAge  => $devicewithage->get_column("macsuck_age"),
      arpnipAge   => $devicewithage->get_column("arpnip_age"),
      ageLimit    => setting('age_limit_warning') || '2' #default at 2 days
    );
    
    # hide arpnip age if device doesn't have layer 3
    unless ($devicesearch->has_layer(3)->count){
      $result{arpnipAge} = 0;
    }
    content_type('text/json');
    template 'plugin/age/age.tt', {
      result => \%result
    }, { layout => undef };
};

1;
