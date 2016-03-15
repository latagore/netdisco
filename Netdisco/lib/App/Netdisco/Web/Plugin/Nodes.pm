package App::Netdisco::Web::Plugin::Nodes;

use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use App::Netdisco::Util::Web 'sql_match';

get '/ajax/content/nodes' => require_login sub {
    my $q = param('q');
    my $f = param('f');
    send_error( 'Missing query', 400 ) unless
      ( $q and $f );
    
    my $rs;
    # decide whether to include age or not
    if (!param('n_age')){
      $rs = schema('netdisco')->resultset('Node');
    } else {
      $rs = schema('netdisco')->resultset('Virtual::NodeWithAge');
    }    
    
    # filter by q and f
    $rs = $rs->search(
        { -and =>
          [
            \['me.switch = ?', $q],
            \['me.port = ?', $f]
          ]
        });
    
    # don't show archived nodes unless requested
    unless (param('n_archived')){
      $rs = $rs->search({-bool => 'active'});
    }
        
    my @results = $rs->all;
    return unless scalar @results;

    template 'ajax/nodes.tt', {
      results => \@results
    }, { layout => undef };
};

1;
