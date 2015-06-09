use utf8;
package App::Netdisco::DB::Result::Portinfo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::Portinfo

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<portinfo>

=cut

__PACKAGE__->table("portinfo");

=head1 ACCESSORS

=head2 ip

  data_type: 'inet'
  is_nullable: 0

=head2 port

  data_type: 'text'
  is_nullable: 0

=head2 port_excel

  data_type: 'text'
  is_nullable: 1

=head2 room

  data_type: 'text'
  is_nullable: 1

=head2 jack

  data_type: 'text'
  is_nullable: 1

=head2 riser1

  data_type: 'text'
  is_nullable: 1

=head2 pairs1

  data_type: 'text'
  is_nullable: 1

=head2 riser2

  data_type: 'text'
  is_nullable: 1

=head2 pairs2

  data_type: 'text'
  is_nullable: 1

=head2 cable

  data_type: 'text'
  is_nullable: 1

=head2 grid

  data_type: 'text'
  is_nullable: 1

=head2 wired

  data_type: 'text'
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 building

  data_type: 'text'
  is_nullable: 1

=head2 last_modified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 last_modified_by

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "ip",
  { data_type => "inet", is_nullable => 0 },
  "port",
  { data_type => "text", is_nullable => 0 },
  "port_excel",
  { data_type => "text", is_nullable => 1 },
  "room",
  { data_type => "text", is_nullable => 1 },
  "jack",
  { data_type => "text", is_nullable => 1 },
  "riser1",
  { data_type => "text", is_nullable => 1 },
  "pairs1",
  { data_type => "text", is_nullable => 1 },
  "riser2",
  { data_type => "text", is_nullable => 1 },
  "pairs2",
  { data_type => "text", is_nullable => 1 },
  "cable",
  { data_type => "text", is_nullable => 1 },
  "grid",
  { data_type => "text", is_nullable => 1 },
  "wired",
  { data_type => "text", is_nullable => 1 },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "building",
  { data_type => "text", is_nullable => 1 },
  "last_modified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "last_modified_by",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</ip>

=item * L</port>

=back

=cut

__PACKAGE__->set_primary_key("ip", "port");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-06-08 09:41:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3ucgcSTA0x90T9ZUs5e0mA

__PACKAGE__->belongs_to(
       device_port => "App::Netdisco::DB::Result::DevicePort",
       {
               'foreign.ip' => 'self.ip',
               'foreign.port' => 'self.port'
       },
);


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
