use utf8;
package App::Netdisco::DB::Result::RecentNodeNodeIp;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::RecentNodeNodeIp

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<recent_node_node_ip>

=cut

__PACKAGE__->table("recent_node_node_ip");

=head1 ACCESSORS

=head2 mac

  data_type: 'macaddr'
  is_nullable: 1

=head2 switch

  data_type: 'inet'
  is_nullable: 1

=head2 port

  data_type: 'text'
  is_nullable: 1

=head2 active

  data_type: 'boolean'
  is_nullable: 1

=head2 oui

  data_type: 'varchar'
  is_nullable: 1
  size: 8

=head2 time_first

  data_type: 'timestamp'
  is_nullable: 1

=head2 time_last

  data_type: 'timestamp'
  is_nullable: 1

=head2 time_recent

  data_type: 'timestamp'
  is_nullable: 1

=head2 vlan

  data_type: 'text'
  is_nullable: 1

=head2 ip

  data_type: 'inet'
  is_nullable: 1

=head2 ip_active

  data_type: 'boolean'
  is_nullable: 1

=head2 ip_time_first

  data_type: 'timestamp'
  is_nullable: 1

=head2 ip_time_last

  data_type: 'timestamp'
  is_nullable: 1

=head2 dns_record

  data_type: 'boolean'
  is_nullable: 1

=head2 dns

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "mac",
  { data_type => "macaddr", is_nullable => 1 },
  "switch",
  { data_type => "inet", is_nullable => 1 },
  "port",
  { data_type => "text", is_nullable => 1 },
  "active",
  { data_type => "boolean", is_nullable => 1 },
  "oui",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "time_first",
  { data_type => "timestamp", is_nullable => 1 },
  "time_last",
  { data_type => "timestamp", is_nullable => 1 },
  "time_recent",
  { data_type => "timestamp", is_nullable => 1 },
  "vlan",
  { data_type => "text", is_nullable => 1 },
  "ip",
  { data_type => "inet", is_nullable => 1 },
  "ip_active",
  { data_type => "boolean", is_nullable => 1 },
  "ip_time_first",
  { data_type => "timestamp", is_nullable => 1 },
  "ip_time_last",
  { data_type => "timestamp", is_nullable => 1 },
  "dns_record",
  { data_type => "boolean", is_nullable => 1 },
  "dns",
  { data_type => "text", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<recent_node_node_ip_pkey>

=over 4

=item * L</mac>

=item * L</switch>

=item * L</port>

=item * L</vlan>

=item * L</ip>

=item * L</active>

=item * L</ip_active>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "recent_node_node_ip_pkey",
  ["mac", "switch", "port", "vlan", "ip", "active", "ip_active"],
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2016-03-22 12:50:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tW1DRiqFnNvjN7iVko9QIA


=head2 port

Returns the port associated with this node entry.

=cut

__PACKAGE__->has_many( port => 'App::Netdisco::DB::Result::DevicePort',
  { 'foreign.ip' => 'self.switch', 'foreign.port' => 'self.port' } );
  
  
1;
