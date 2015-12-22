package App::Netdisco::Web;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;

use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use Socket6 (); # to ensure dependency is met
use HTML::Entities (); # to ensure dependency is met
use URI::QueryParam (); # part of URI, to add helper methods
use URL::Encode 'url_params_mixed';
use Path::Class 'dir';
use Module::Find ();
use Module::Load ();
use App::Netdisco::Util::Web 'interval_to_daterange';

# can override splats only by loading first
Module::Find::usesub 'App::NetdiscoE::Web';

use App::Netdisco::Web::AuthN;
use App::Netdisco::Web::Static;
use App::Netdisco::Web::Search;
use App::Netdisco::Web::Device;
use App::Netdisco::Web::Report;
use App::Netdisco::Web::AdminTask;
use App::Netdisco::Web::TypeAhead;
use App::Netdisco::Web::PortControl;
use App::Netdisco::Web::Statistics;
use App::Netdisco::Web::Password;
use App::Netdisco::Web::GenericReport;

sub _load_web_plugins {
  my $plugin_list = shift;

  foreach my $plugin (@$plugin_list) {
      $plugin =~ s/^X::/+App::NetdiscoX::Web::Plugin::/;
      $plugin = 'App::Netdisco::Web::Plugin::'. $plugin
        if $plugin !~ m/^\+/;
      $plugin =~ s/^\+//;

      debug "loading Netdisco plugin $plugin";
      Module::Load::load $plugin;
  }
}

if (setting('web_plugins') and ref [] eq ref setting('web_plugins')) {
    _load_web_plugins( setting('web_plugins') );
}

if (setting('extra_web_plugins') and ref [] eq ref setting('extra_web_plugins')) {
    unshift @INC, dir(($ENV{NETDISCO_HOME} || $ENV{HOME}), 'site_plugins')->stringify;
    _load_web_plugins( setting('extra_web_plugins') );
}

# after plugins are loaded, add our own template path
push @{ config->{engines}->{netdisco_template_toolkit}->{INCLUDE_PATH} },
     setting('views');

# workaround for https://github.com/PerlDancer/Dancer/issues/935
hook after_error_render => sub { setting('layout' => 'main') };

# setup params for device ports + search ports view
hook 'before' => sub {
  # trim whitespace
  params->{q} =~ s/(^\s+)|(\s+$)//g;

  my @default_port_columns_left = (
    { name => 'c_up',          label => 'Status',            default => ''   },
    { name => 'c_admin',       label => 'Port Controls',     default => ''   },
    { name => 'c_port',        label => 'Port ID',           default => 'on' },
  );

  my @default_port_columns_mid = (
    { name => 'c_descr',       label => 'Port Name',       default => ''   },
    { name => 'c_type',        label => 'Type',              default => ''   },
    { name => 'c_duplex',      label => 'Duplex',            default => ''   },
    { name => 'c_name',        label => 'Port Description',              default => '' },
    { name => 'c_speed',       label => 'Speed',             default => ''   },
    { name => 'c_mac',         label => 'Port MAC',          default => ''   },
    { name => 'c_mtu',         label => 'MTU',               default => ''   },
    { name => 'c_pvid',        label => 'Native VLAN',       default => 'on' },
    { name => 'c_vmember',     label => 'VLAN Membership',   default => 'on' },
    { name => 'c_stp',         label => 'Spanning Tree',     default => ''   },
    { name => 'c_power',       label => 'PoE',               default => ''   },
    { name => 'c_ssid',        label => 'SSID',              default => ''   },
  );
  
  my @default_port_columns_right = (
    { name => 'c_neighbors',   label => 'Connected Devices', default => 'on' },
    { name => 'c_nodes',       label => 'Connected Nodes',   default => 'on' },
    { name => 'c_comment',     label => 'Last Comment',      default => ''   },
    { name => 'c_lastchange',  label => 'Last Change',       default => ''   },
  );

  # build list of port detail columns
  my @port_columns = ();

  push @port_columns, @default_port_columns_left;
  push @port_columns,
    grep {$_->{position} eq 'left'} @{ setting('_extra_device_port_cols') };
  push @port_columns, @default_port_columns_mid;
  push @port_columns,
    grep {$_->{position} eq 'mid'} @{ setting('_extra_device_port_cols') };
  push @port_columns, @default_port_columns_right;
  push @port_columns,
    grep {$_->{position} eq 'right'} @{ setting('_extra_device_port_cols') };

  var('port_columns' => \@port_columns);

  # view settings for port connected devices
  var('connected_properties' => [
    { name => 'n_age',      label => 'Age Stamp',     default => 'on'   },
    { name => 'n_ip',       label => 'IP Address',    default => 'on' },
    { name => 'n_netbios',  label => 'NetBIOS',       default => 'on' },
    { name => 'n_ssid',     label => 'SSID',          default => 'on' },
    { name => 'n_vendor',   label => 'Vendor',        default => ''   },
    { name => 'n_archived', label => 'Archived Data', default => ''   },
  ]);

  return unless 
       (request->path eq uri_for('/device')->path
    or (request->path eq uri_for('/search')->path
    or index(request->path, uri_for('/ajax/content/device')->path) == 0)
    or index(request->path, uri_for('/ajax/content/search')->path) == 0);

  # the first time the user navigates to a page, the columns get set to defaults
  # or cookies

  my $cookie = (cookie('nd_ports-form') || '');
  my $cdata = url_params_mixed($cookie);
  
  my $default = 0 ;
  $default = 1 if param('reset');
  unless (param('reset')){
    if (param('custom-view') and param('custom-view') eq 'on'){
      # use params, do nothing
    } elsif ($cdata and scalar %$cdata) {
      # use cookie
      foreach my $item (@{ var('port_columns') }) {
          my $key = $item->{name};
          next unless defined $cdata->{$key}
            and $cdata->{$key} =~ m/^[[:alnum:]_]+$/;
          params->{$key} = $cdata->{$key};
      }
      foreach my $item (@{ var('connected_properties') }) {
          my $key = $item->{name};
          next unless defined $cdata->{$key}
            and $cdata->{$key} =~ m/^[[:alnum:]_]+$/;
          params->{$key} = $cdata->{$key};
      }

      foreach my $key (qw/age_num age_unit mac_format/) {
          params->{$key} ||= $cdata->{$key}
            if defined $cdata->{$key}
               and $cdata->{$key} =~ m/^[[:alnum:]_]+$/;
      }
    } else {
      $default = 1;
    }
  }

  if ($default){
    # reset params to defaults
    foreach my $col (@{ var('port_columns') }) {
        delete params->{$col->{name}};
      params->{$col->{name}} = 'checked'
        if $col->{default} eq 'on';
    }
    foreach my $col (@{ var('connected_properties') }) {
      delete params->{$col->{name}};
      params->{$col->{name}} = 'checked'
        if $col->{default} eq 'on';
    }
    # not stored in the cookie
    params->{'age_num'} =  setting('ports_free_threshold') || 3;
    params->{'age_unit'} =  setting('ports_free_threshold_unit') || 'months';
    params->{'mac_format'} = 'IEEE';

    # nuke the port params cookie
    cookie('nd_ports-form' => '', expires => '-1 day');
  }
};

# new searches will use these defaults in their sidebars
hook 'before_template' => sub {
  my $tokens = shift;

  $tokens->{device_ports} = uri_for('/device', { tab => 'ports' });

  # copy ports form defaults into helper values for building template links
  foreach my $key (qw/age_num age_unit mac_format/) {
      $tokens->{device_ports}->query_param($key, params->{$key});
  }

  $tokens->{mac_format_call} = 'as_'. lc(params->{'mac_format'})
    if params->{'mac_format'};

  foreach my $col (@{ var('port_columns') }) {
      next unless $col->{default} eq 'on';
      $tokens->{device_ports}->query_param($col->{name}, 'checked');
  }

  foreach my $col (@{ var('connected_properties') }) {
      next unless $col->{default} eq 'on';
      $tokens->{device_ports}->query_param($col->{name}, 'checked');
  }

  # for templates to link to same page with modified query but same options
  my $self_uri = uri_for(request->path, scalar params);
  $self_uri->query_param_delete('q');
  $self_uri->query_param_delete('f');
  $self_uri->query_param_delete('prefer');
  $tokens->{self_options} = $self_uri->query_form_hash;
};

# this hook should be loaded _after_ all plugins
hook 'before_template' => sub {
    my $tokens = shift;

    # allow portable static content
    $tokens->{uri_base} = request->base->path
        if request->base->path ne '/';

    # allow portable dynamic content
    $tokens->{uri_for} = sub { uri_for(@_)->path_query };

    # access to logged in user's roles
    $tokens->{user_has_role}  = sub { user_has_role(@_) };

    # create date ranges from within templates
    $tokens->{to_daterange}  = sub { interval_to_daterange(@_) };

    # data structure for DataTables records per page menu
    $tokens->{table_showrecordsmenu} =
      to_json( setting('table_showrecordsmenu') );

    # fix Plugin Template Variables to be only path+query
    $tokens->{$_} = $tokens->{$_}->path_query
      for qw/search_node search_device device_ports/;

    # allow very long lists of ports
    $Template::Directive::WHILE_MAX = 10_000;

    # allow hash keys with leading underscores
    $Template::Stash::PRIVATE = undef;
};

# remove empty lines from CSV response
# this makes writing templates much more straightforward!
hook 'after' => sub {
    my $r = shift; # a Dancer::Response

    if ($r->content_type and $r->content_type eq 'text/comma-separated-values') {
        my @newlines = ();
        my @lines = split m/\n/, $r->content;

        foreach my $line (@lines) {
            push @newlines, $line if $line !~ m/^\s*$/;
        }

        $r->content(join "\n", @newlines);
    }
};

any qr{.*} => sub {
    var('notfound' => true);
    status 'not_found';
    template 'index';
};

{
  # https://github.com/PerlDancer/Dancer/issues/967
  no warnings 'redefine';
  *Dancer::_redirect = sub {
      my ($destination, $status) = @_;
      my $response = Dancer::SharedData->response;
      $response->status($status || 302);
      $response->headers('Location' => $destination);
  };
}

true;

