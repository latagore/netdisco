package App::Netdisco::Web::DancerVMethods;

use Dancer ':syntax';
use NetAddr::MAC;
use Template::Stash;

# Virtual methods for Template Toolkit to show different
# mac address formats 
$Template::Stash::SCALAR_OPS->{ mac_as_ieee } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_ieee;
};
$Template::Stash::SCALAR_OPS->{ mac_as_cisco } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_cisco;
};
$Template::Stash::SCALAR_OPS->{ mac_as_microsoft } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_microsoft;
};
$Template::Stash::SCALAR_OPS->{ mac_as_sun } = sub {
  my $mac = $_;
  return NetAddr::MAC->new(mac => shift)->as_sun;
};

true;
