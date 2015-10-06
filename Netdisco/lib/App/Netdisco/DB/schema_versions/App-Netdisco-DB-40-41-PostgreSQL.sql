BEGIN;

-- Add improvements to indexing
CREATE INDEX idx_device_port_name
    ON device_port
    USING btree
    (name COLLATE pg_catalog."default");
CREATE INDEX idx_device_port_port
    ON device_port
    USING btree
    (port COLLATE pg_catalog."default");
CREATE INDEX idx_device_port_slave_of
    ON device_port
    USING btree
    (slave_of COLLATE pg_catalog."default");
CREATE INDEX idx_device_port_remote_id
    ON device_port
    USING btree
    (remote_id COLLATE pg_catalog."default");
CREATE INDEX idx_device_port_remote_type
    ON device_port
    USING btree
    (remote_type COLLATE pg_catalog."default");

CREATE INDEX idx_device_port_vlan_ip
    ON device_port_vlan_ip
    USING btree
    (ip COLLATE pg_catalog."default");
CREATE INDEX idx_device_port_vlan_port
    ON device_port_vlan
    USING btree
    (port COLLATE pg_catalog."default");

COMMIT;
