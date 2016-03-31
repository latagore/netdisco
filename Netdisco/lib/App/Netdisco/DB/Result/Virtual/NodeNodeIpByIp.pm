use utf8;
package App::Netdisco::DB::Result::Virtual::NodeNodeIpByIp;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table("node_node_ip_by_ip");
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(q{
  select ips.ip::text as ident, 'ip' as search_type, recent_nodes.mac, recent_nodes.switch, recent_nodes.port, recent_nodes.vlan, ips.ip, ips.dns, ips.time_first, ips.time_last from node_ip ips
  join (
    select node_ip.ip, max(time_last) as max_time_last from node_ip
    group by node_ip.ip
  ) recent_ips
  on ips.ip = recent_ips.ip and ips.time_last = recent_ips.max_time_last

  join (
    select node.* from node
    join (
      select node.mac, max(time_last) from node
      group by node.mac
    ) t
    on node.mac = t.mac and node.time_last = t.max
  ) recent_nodes
  on recent_nodes.mac = ips.mac and recent_nodes.active = ips.active
  where ips.ip = ?
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
