package App::Netdisco::Web::Template::VMethods; 

use strict;
use warnings;

use Template::Stash;

# utility methods for templates

$Template::Stash::SCALAR_OPS->{ as_ieee } = sub {
  my $mac = NetAddr::MAC->new(shift);
  return $mac->as_ieee;
};

$Template::Stash::SCALAR_OPS->{ as_microsoft } = sub {
  my $mac = NetAddr::MAC->new(shift);
  return $mac->as_microsoft;
};

$Template::Stash::SCALAR_OPS->{ as_sun } = sub {
  my $mac = NetAddr::MAC->new(shift);
  return $mac->as_sun;
};

$Template::Stash::SCALAR_OPS->{ as_cisco } = sub {
  my $mac = NetAddr::MAC->new(shift);
  return $mac->as_cisco;
};
