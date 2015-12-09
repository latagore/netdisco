package App::NetdiscoX::Web::Plugin::FAQ;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;

use File::Share ':all';
register_template_path(
  dist_dir( 'App-NetdiscoX-Web-Plugin-FAQ' ));
register_javascript('faq');
register_css('faq');
