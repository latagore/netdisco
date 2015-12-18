package App::Netdisco::Web::Device;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

get '/device' => require_login sub {
    my $q = param('q');
    my $schema = schema('netdisco')->resultset('Device');

    # we are passed either dns or ip
    my $dev = $schema->search({
        -or => [
            \[ 'host(me.ip) = ?' => [ bind_value => $q ] ],
            'me.dns' => $q,
        ],
    });

    if ($dev->count == 0) {
        return redirect uri_for('/', {nosuchdevice => 1, device => $q})->path_query;
    }

    # if passed dns, need to check for duplicates
    # and use only ip for q param, if there are duplicates.
    my $first = $dev->first;
    my $others = ($schema->search({dns => $first->dns})->count() - 1);

    params->{'tab'} ||= 'details';
    template 'device', {
      display_name => ($others ? $first->ip : $first->dns),
      device_ip => $first->ip,
      device => params->{'tab'},
    };
};

true;
