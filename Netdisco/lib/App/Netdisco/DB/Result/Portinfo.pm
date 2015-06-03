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

=head2 dns

  data_type: 'text'
  is_nullable: 0

=head2 port

  data_type: 'text'
  is_nullable: 0

=head2 port_excel

  data_type: 'text'
  is_nullable: 1

=head2 xroom

  data_type: 'text'
  is_nullable: 1

=head2 xxjack

  data_type: 'text'
  is_nullable: 1

=head2 xxriser1

  data_type: 'text'
  is_nullable: 1

=head2 xxxpairs1

  data_type: 'text'
  is_nullable: 1

=head2 xxxriser2

  data_type: 'text'
  is_nullable: 1

=head2 xxxxpairs2

  data_type: 'text'
  is_nullable: 1

=head2 xxxxxcable

  data_type: 'text'
  is_nullable: 1

=head2 xxxxxgrid

  data_type: 'text'
  is_nullable: 1

=head2 xxxxxwired

  data_type: 'text'
  is_nullable: 1

=head2 xxxxxxcomment

  data_type: 'text'
  is_nullable: 1

=head2 xxbuilding

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
  "dns",
  { data_type => "text", is_nullable => 0 },
  "port",
  { data_type => "text", is_nullable => 0 },
  "port_excel",
  { data_type => "text", is_nullable => 1 },
  "xroom",
  { data_type => "text", is_nullable => 1 },
  "xxjack",
  { data_type => "text", is_nullable => 1 },
  "xxriser1",
  { data_type => "text", is_nullable => 1 },
  "xxxpairs1",
  { data_type => "text", is_nullable => 1 },
  "xxxriser2",
  { data_type => "text", is_nullable => 1 },
  "xxxxpairs2",
  { data_type => "text", is_nullable => 1 },
  "xxxxxcable",
  { data_type => "text", is_nullable => 1 },
  "xxxxxgrid",
  { data_type => "text", is_nullable => 1 },
  "xxxxxwired",
  { data_type => "text", is_nullable => 1 },
  "xxxxxxcomment",
  { data_type => "text", is_nullable => 1 },
  "xxbuilding",
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

=item * L</dns>

=item * L</port>

=back

=cut

__PACKAGE__->set_primary_key("ip", "dns", "port");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-06-03 09:09:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ezS54ZLPqtLNt7prLyDIPg

__PACKAGE__->might_have(
	device_port => "App::Netdisco::DB::Result::DevicePort",
	{
		'foreign.ip' => 'self.ip',
		'foreign.port' => 'self.port'
	},
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
