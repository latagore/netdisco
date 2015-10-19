package App::Netdisco::Web::DancerVMethods;

use Dancer ':syntax';
use NetAddr::MAC;
use Template::Stash;

# Virtual methods for Template Toolkit to show different
# mac address formats 
# used for rendering MAC addresses for HRI resultsets
$Template::Stash::SCALAR_OPS->{ as_ieee } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_ieee;
};
$Template::Stash::SCALAR_OPS->{ as_cisco } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_cisco;
};
$Template::Stash::SCALAR_OPS->{ as_microsoft } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_microsoft;
};
$Template::Stash::SCALAR_OPS->{ as_sun } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_sun;
};

true;
