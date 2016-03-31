use utf8;
package App::Netdisco::DB::Result::Virtual::NodeNodeIpByMac;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table("node_node_ip_by_age");
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(q{
  select node.mac::text as ident, 'mac' as search_type, node.mac, node.switch, node.port, node.vlan, recent_ips.ip, recent_ips.dns, node.time_first, node.time_last from node
  join (
    select node.mac, max(time_last) from node
    group by node.mac
  ) recent_nodes
  on node.mac = recent_nodes.mac and node.time_last = recent_nodes.max
  join (
    select node_ip.* from node_ip
    join (
      select node_ip.mac, max(time_last) from node_ip
      group by node_ip.mac
    ) u
    on node_ip.mac = u.mac and node_ip.time_last = u.max
  ) recent_ips
  on node.mac = recent_ips.mac and node.active = recent_ips.active
  where node.mac = ?
});

__PACKAGE__->add_columns(
  "ident",
  { data_type => "text"},
  "search_type",
  { data_type => "text"},
  "mac",
  { data_type => "macaddr"},
  "switch",
  { data_type => "inet" },
  "port",
  { data_type => "text" },
  "vlan",
  { data_type => "text" },
  "ip",
  { data_type => "inet" },
  "dns",
  { data_type => "text", is_nullable => 1 },
  "time_first",
  { data_type => "time_stamp" },
  "time_last",
  { data_type => "time_stamp" }
);
__PACKAGE__->set_primary_key("mac");


=head2 device_port

Returns the single C<device_port> to which this Node entry was associated at
the time of discovery.

The JOIN is of type LEFT, in case the C<device> is no longer present in the
database but the relation is being used in C<search()>.

=cut

# device port may have been deleted (reconfigured modules?) but node remains
__PACKAGE__->belongs_to( device_port => 'App::Netdisco::DB::Result::DevicePort',
  { 'foreign.ip' => 'self.switch', 'foreign.port' => 'self.port' },
  { join_type => 'LEFT' }
);


1;
