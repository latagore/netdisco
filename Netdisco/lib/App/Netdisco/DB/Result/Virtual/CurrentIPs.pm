package App::Netdisco::DB::Result::Virtual::CurrentIPs;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('current_ips');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(<<ENDSQL
  select node_ip.* from (
    select mac, max(time_last) as time_last from node_ip
    group by mac
  ) t
  left join node_ip 
  on node_ip.mac = t.mac and node_ip.time_last = t.time_last
ENDSQL
);

__PACKAGE__->add_columns(
  'mac' => {
    data_type => 'text',
  },
  'ip' => {
    data_type => 'inet',
  },
  'active' => {
    data_type => 'boolean',
  },
  'time_first' => {
    data_type => 'timestamp',
  },
  'time_last' => {
    data_type => 'timestamp',
  },
  'dns_record' => {
    data_type => 'boolean',
  },
  'dns' => {
    data_type => 'text',
  },
);
__PACKAGE__->set_primary_key("mac", "ip");

1;
