package App::Netdisco::DB::Result::Virtual::DevicePortStats;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('device_links');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(<<ENDSQL
 SELECT dpv.ip, dpv.port, count(*) as vlan_count
  FROM device_port_vlan dpv
  GROUP BY dpv.ip, dpv.port
ENDSQL
);

__PACKAGE__->add_columns(
  'ip' => {
    data_type => 'inet',
  },
  'port' => {
    data_type => 'text',
  },
  'vlan_count' => {
    data_type => 'bigint',
  },
);
__PACKAGE__->set_primary_key("port", "ip");

1;
