package App::Netdisco::Web::Plugin::Report::IpInventory;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use NetAddr::IP::Lite ':lower';

register_report(
    {   category     => 'IP',
        tag          => 'ipinventory',
        label        => 'IP Inventory',
        provides_csv => 1,
    }
);

get '/ajax/content/report/ipinventory' => require_login sub {

    # Default to something simple with no results to prevent
    # "Search failed!" error
    my $subnet = param('subnet') || '0.0.0.0/32';
    $subnet = NetAddr::IP::Lite->new($subnet);
    $subnet = NetAddr::IP::Lite->new('0.0.0.0/32')
      if (! $subnet) or ($subnet->addr eq '0.0.0.0');

    my $limit = param('limit') || 256;
    my $order = [{-desc => 'age'}, {-asc => 'ip'}];

    my $used = param('used');
    my $num = param('num');
    my $unit = param('unit');
    my $registered = param('registered');

    send_error("Invalid unit") unless grep { $_ eq $unit } qw/months days weeks/;
    send_error("Invalid registered field") unless grep { $_ eq $registered } qw/registered unregistered both/;

    my $interval = "\'$num $unit\'::interval";

    # We need a reasonable limit to prevent a potential DoS, especially if
    # 'never' is true.  TODO: Need better input validation, both JS and
    # server-side to provide user feedback
    $limit = 8192 if $limit > 8192;

    my $rs1 = schema('netdisco')->resultset('DeviceIp')->search(
        undef,
        {   join   => 'device',
            select => [
                'alias AS ip',
                \'NULL as mac',
                'creation AS time_first',
                'device.last_discover AS time_last',
                'dns',
                \'true AS active',
                \'false AS node',
                \qq/replace( date_trunc( 'minute', age( now(), device.last_discover ) ) ::text, 'mon', 'month') AS age/
            ],
            as => [qw( ip mac time_first time_last dns active node age)],
        }
    )->hri;

    my $rs2 = schema('netdisco')->resultset('NodeIp')->search(
        undef,
        {   columns   => [qw( ip mac time_first time_last dns active)],
            '+select' => [ \'true AS node',
                           \qq/replace( date_trunc( 'minute', age( now(), time_last ) ) ::text, 'mon', 'month') AS age/
                         ],
            '+as'     => [ 'node', 'age' ],
        }
    )->hri;

    my $rs3 = schema('netdisco')->resultset('NodeNbt')->search(
        undef,
        {   columns   => [qw( ip mac time_first time_last )],
            '+select' => [
                'nbname AS dns', 'active',
                \'true AS node',
                \qq/replace( date_trunc( 'minute', age( now(), time_last ) ) ::text, 'mon', 'month') AS age/
            ],
            '+as' => [ 'dns', 'active', 'node', 'age' ],
        }
    )->hri;

    my $rs_union = $rs1->union( [ $rs2, $rs3 ] );

    my $rs_sub = $rs_union->search(
        { ip => { '<<' => $subnet->cidr } },
        {   select   => [
                \'DISTINCT ON (ip) ip',
                'mac',
                'dns',
                \qq/date_trunc('second', time_last) AS time_last/,
                \qq/date_trunc('second', time_first) AS time_first/,
                'active',
                \'(select switch from node where node.mac = me.mac order by time_last desc limit 1) AS switch',
                \'(select device.dns from node join device on device.ip = node.switch where node.mac = me.mac order by time_last desc limit 1) AS switchdns',
                \'(select port from node where node.mac = me.mac order by time_last desc limit 1) AS port',
                'node',
                'age'
            ],
            as => [
                'ip',     'mac',  'dns',  'time_last', 'time_first',
                'active', 'switch', 'switchdns', 'port', 'node', 'age'
            ],
            order_by => [{-asc => 'ip'}, {-desc => 'active'}],
        }
    )->as_query;

    my $rs;
    if ( $used eq "unused") {
        $rs = $rs_union->search(
                { -or =>
                  [  
                    { time_last => { '<', \"now() - $interval" } },
                    { time_last => undef }
                  ]
                },
                {
                  columns   => [qw( ip mac time_first time_last dns active switch switchdns port node age)],
                  from => { me => $rs_sub }, 
                }
            );
    } elsif ($used eq "used") {
        $rs = $rs_union->search(
            { time_last => { '>=',  \"now() - $interval" } },
            { 
              columns   => [qw( ip mac time_first time_last dns active switch switchdns port node age)],
              from => { me => $rs_sub }, 
            }
        );
    } else {
        $subnet = NetAddr::IP::Lite->new('0.0.0.0/32') if ($subnet->bits ne 32);

        # check if subnet ip doesn't exist in DB
        
        $rs_union = $rs_union->search(
          { "-and" =>
            [
              { "me.ip" => { "=" => \"n.ip"} },
              { "me.ip" => {'<<' => $subnet->cidr} }
            ]
          },
          { 
            columns => 'ip',
          });
          
        $rs = schema('netdisco')->resultset('Virtual::CidrIps')->search(
            { -and =>
              [
                { ip => { '<<' => $subnet->cidr }},
                { '-not exists' => $rs_union->as_query }
              ]
            },
            {   bind => [ $subnet->cidr ],
                columns   => [qw( ip mac time_first time_last dns active )],
                '+select' => [ \'false AS node',
                               \qq/replace( date_trunc( 'minute', age( now(), time_last ) ) ::text, 'mon', 'month') AS age/,
                               \'NULL as switch',
                               \'NULL as switchdns',
                               \'NULL as port'
                             ],
                '+as'     => [ 'node', 'age', 'switch', 'switchdns', 'port' ],
                alias => "n"
            }
        )->hri;

    }

    if ($registered eq "registered") {      
      $rs = $rs->search(
        { dns => { '!=' => undef } }
      );

    } elsif ($registered eq "unregistered") {
      $rs = $rs->search(
        {dns => undef}
      );
    }

    my @results = $rs->order_by($order)->limit($limit)->all;
    return unless scalar @results;

    if ( request->is_ajax ) {
        my $json = to_json( \@results );
        template 'ajax/report/ipinventory.tt', { results => $json },
            { layout => undef };
    }
    else {
        header( 'Content-Type' => 'text/comma-separated-values' );
        template 'ajax/report/ipinventory_csv.tt', { results => \@results, },
            { layout => undef };
    }
};

1;
