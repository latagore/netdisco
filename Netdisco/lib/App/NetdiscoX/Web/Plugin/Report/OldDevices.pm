package App::NetdiscoX::Web::Plugin::Report::OldDevices;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use NetAddr::IP::Lite ':lower';

register_admin_task({
  tag => 'olddevices',
  label => 'Old Devices',
});
    

use File::Share ':all';

register_template_path
  dist_dir( 'App-NetdiscoX-Web-Plugin-Report-OldDevices' );

get '/ajax/content/admin/olddevices' => require_role admin =>sub {

    my $max_age = params->{max_age} || setting('age_limit_warning') || 2;
    $max_age .= " days";
    my $cutoff_timestamp = "(now() - '$max_age'::interval)";
    my @type = param_array 'type';
    my %has_type;
    
    
    my @where = [];
    
    my $layer3string = '_____1__'; # match devices with layer 3 capability
    if (scalar @type) {
      debug 'hi';
      @has_type{@type}= ();
  
      push @where, { last_discover => { '<' => \$cutoff_timestamp} } if exists $has_type{discover};
      push @where, { -and => 
                     [
                       {last_arpnip => { '<' => \$cutoff_timestamp}},
                       {layers => { -ilike => $layer3string }}
                     ]
                   } 
                   if exists $has_type{arpnip};
      push @where, { last_macsuck => { '<' => \$cutoff_timestamp} } if exists $has_type{macsuck};
      use Data::Dumper;
      debug Dumper(\@type);
      debug Dumper(\%has_type);
    } else {
      push @where, { last_discover => { '<' => \$cutoff_timestamp} };
      push @where, { -and => 
                     [
                       {last_arpnip => { '<' => \$cutoff_timestamp}},
                       {layers => { -ilike => $layer3string }}
                     ]
                   };
      push @where, { last_macsuck => { '<' => \$cutoff_timestamp} };
    }

    my $rs;
    $rs = schema('netdisco')->resultset('Device')->search(\@where,
      {
        columns => [qw/ dns ip /]
      })->with_times;
    
    my @results = $rs->hri->all;
    return unless scalar @results;

    if ( request->is_ajax ) {
        my $json = to_json( \@results );
        template 'plugin/olddevices/olddevices.tt', { results => $json },
            { layout => undef };
    }
    #else {
    #    header( 'Content-Type' => 'text/comma-separated-values' );
    #    template 'ajax/report/ipinventory_csv.tt', { results => \@results, },
    #        { layout => undef };
    #}
};

1;
