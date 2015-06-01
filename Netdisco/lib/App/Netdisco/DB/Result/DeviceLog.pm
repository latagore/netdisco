use utf8;
package App::Netdisco::DB::Result::DeviceLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::DeviceLog

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<device_log>

=cut

__PACKAGE__->table("device_log");

=head1 ACCESSORS

=head2 ip

  data_type: 'inet'
  is_nullable: 0

=head2 dns

  data_type: 'text'
  is_nullable: 1

=head2 log

  data_type: 'text'
  is_nullable: 1

=head2 creation

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 username

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ip",
  { data_type => "inet", is_nullable => 0 },
  "dns",
  { data_type => "text", is_nullable => 1 },
  "log",
  { data_type => "text", is_nullable => 1 },
  "creation",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "username",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ip>

=item * L</creation>

=back

=cut

__PACKAGE__->set_primary_key("ip", "creation");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-06-01 10:58:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hUmvzVrNZcMw2QRRoHq4aw




1;
