package App::Netdisco::DB::Result::Virtual::PortUtilization;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('port_utilization');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(<<ENDSQL
  select device.dns, device.ip,
  -- default 0 for devices with no non-virtual ports
  coalesce(port_count,0) port_count, 
  coalesce(ports_disabled, 0) ports_disabled, 
  coalesce(ports_in_use,0) ports_in_use,
  coalesce(ports_free,0) ports_free
  from device

  left join (
    select t.ip, sum(case when (t.is_free) then 1 else 0 end) ports_free, sum(case when (t.is_free) then 0 else 1 end) ports_in_use from 
      (
      select device_port.ip, device_port.port,
      -- there is no connected device or node => free 
      device_port.remote_ip IS NULL AND
      NOT EXISTS (
        select node.switch from node 
        where (now() - node.time_last <= interval '14 months') 
        AND node.switch = device_port.ip AND node.port = device_port.port 
      ) is_free 
      from device_port
      where (up_admin = 'up' or device_port.vlan = '1000') and device_port.type <> 'propVirtual'
    ) t
    group by t.ip
  ) up_ports
  on up_ports.ip = device.ip

  left join (
    select device_port.ip, count(*) ports_disabled 
    from device_port
    where  device_port.type <> 'propVirtual' and device_port.up_admin != 'up' and (device_port.vlan <> '1000' or device_port.vlan IS NULL)
    group by device_port.ip
  ) ports_disabled
  on ports_disabled.ip = device.ip

  left join (
    select device_port.ip, count(*) port_count from device_port
    where device_port.type <> 'propVirtual'
    group by device_port.ip
  ) all_ports
  on all_ports.ip = device.ip
  order by device.dns, device.ip
ENDSQL
);

__PACKAGE__->add_columns(
  'dns' => {
    data_type => 'text',
  },
  'ip' => {
    data_type => 'inet',
  },
  'port_count' => {
    data_type => 'integer',
  },
  'ports_in_use' => {
    data_type => 'integer',
  },
  'ports_disabled' => {
    data_type => 'integer',
  },
  'ports_free' => {
    data_type => 'integer',
  },
);

1;
