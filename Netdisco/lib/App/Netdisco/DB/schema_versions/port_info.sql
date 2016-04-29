--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plperl; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plperl WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plperl; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plperl IS 'PL/Perl procedural language';


--
-- Name: plperlu; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plperlu WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plperlu; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plperlu IS 'PL/PerlU untrusted procedural language';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: port; Type: TYPE; Schema: public; Owner: netdisco
--

CREATE TYPE port AS (
	f1 text
);


ALTER TYPE public.port OWNER TO netdisco;

--
-- Name: cast_to_port(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION cast_to_port(text) RETURNS port
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT ($1);
$_$;


ALTER FUNCTION public.cast_to_port(text) OWNER TO postgres;

--
-- Name: gethostbyaddr(inet); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION gethostbyaddr(inet) RETURNS text
    LANGUAGE plperlu
    AS $_X$
use strict;
use Socket;
my $inet = $_[0];
my $iaddr=inet_aton($inet);
my $name = gethostbyaddr($iaddr,AF_INET);
return $name;
$_X$;


ALTER FUNCTION public.gethostbyaddr(inet) OWNER TO postgres;

--
-- Name: getrows(integer); Type: FUNCTION; Schema: public; Owner: netdisco
--

CREATE FUNCTION getrows(m integer) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
declare
r record;
t record;
i integer default 0;
begin
t := NULL;
for r in EXECUTE 'select mac, switch, port, active, oui, time_first, time_last, time_recent, vlan from node order by switch, port' loop
if i <> 0 then
	if (r.switch <> t.switch or r.port <> t.port) then
		t := r;
		i := 0;
	end if;
end if;
if i < m then	
        t := r;
        i := i + 1;
	return next r;
end if;
end loop;
return;
end
$$;


ALTER FUNCTION public.getrows(m integer) OWNER TO netdisco;

--
-- Name: getrows(integer, boolean); Type: FUNCTION; Schema: public; Owner: netdisco
--

CREATE FUNCTION getrows(m integer, active boolean) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
declare
r record;
t record;
i integer default 0;
query text;
begin
t := NULL;
if (active) then
  query := 'select mac, switch, port, active, oui, time_first, time_last, time_recent, vlan from node where active order by switch, port';
else
  query := 'select mac, switch, port, active, oui, time_first, time_last, time_recent, vlan from node order by switch, port';
end if;

for r in EXECUTE query loop
if i <> 0 then
	if (r.switch <> t.switch or r.port <> t.port) then
		t := r;
		i := 0;
	end if;
end if;
if i < m then	
        t := r;
        i := i + 1;
	return next r;
end if;
end loop;
return;
end
$$;


ALTER FUNCTION public.getrows(m integer, active boolean) OWNER TO netdisco;

--
-- Name: getsomenodes(integer, boolean); Type: FUNCTION; Schema: public; Owner: netdisco
--

CREATE FUNCTION getsomenodes(m integer, active boolean) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
n record;
dp record;
query text;
begin
if (active) then
  query := 'select * from node
      where switch = $1 and port = $2 and active
      order by time_last limit 10';
else
  query := 'select * from node
      where switch = $1 and port = $2
      order by time_last limit 10';
end if;

for dp in EXECUTE 'select ip, port from device_port' loop
  for n in 
    EXECUTE query using dp.ip, dp.port loop
    return next n;
  end loop;
end loop;
return;
end
$_$;


ALTER FUNCTION public.getsomenodes(m integer, active boolean) OWNER TO netdisco;

--
-- Name: getsomenodes2(integer, boolean); Type: FUNCTION; Schema: public; Owner: netdisco
--

CREATE FUNCTION getsomenodes2(m integer, active boolean) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $_$
declare
n record;
dp record;
i integer default 0;
query text;
begin
if (active) then
  query := 'select mac, switch, port, active, oui, time_first, time_last, time_recent, vlan from node where active order by switch, port, time_last';
else
  query := 'select mac, switch, port, active, oui, time_first, time_last, time_recent, vlan from node order by switch, port, time_last';
end if;

for dp in EXECUTE 'select ip, port from device_port' loop
  for n in 
    EXECUTE 'select * from node
      where switch = $1 and port = $2 order by time_last limit 10 ' using dp.ip, dp.port loop
    return next n;
  end loop;
end loop;
return;
end
$_$;


ALTER FUNCTION public.getsomenodes2(m integer, active boolean) OWNER TO netdisco;

--
-- Name: port_cast_to_text(port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_cast_to_text(port) RETURNS text
    LANGUAGE plperl IMMUTABLE
    AS $_X$
	return $_[0]->{f1};
$_X$;


ALTER FUNCTION public.port_cast_to_text(port) OWNER TO postgres;

--
-- Name: port_cmp(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_cmp(text, text) RETURNS integer
    LANGUAGE plperl
    AS $_$
    use strict;
    use warnings;
    use feature ":5.14";
    
    my ($aval, $bval) = @_;

    # hack for foundry "10GigabitEthernet" -> cisco-like "TenGigabitEthernet"
    $aval = $1 if $aval =~ qr/^10(GigabitEthernet.+)$/;
    $bval = $1 if $bval =~ qr/^10(GigabitEthernet.+)$/;

    my $numbers        = qr{^(\d+)$};
    my $numeric        = qr{^([\d\.]+)$};
    my $dotted_numeric = qr{^(\d+)[:.](\d+)$};
    my $letter_number  = qr{^([a-zA-Z]+)(\d+)$};
    my $wordcharword   = qr{^([^:\/.]+)[-\ :\/\.]+([^:\/.0-9]+)(\d+)?$}; #port-channel45
    my $netgear        = qr{^Slot: (\d+) Port: (\d+) }; # "Slot: 0 Port: 15 Gigabit - Level"
    my $ciscofast      = qr{^
                            # Word Number slash (Gigabit0/)
                            (\D+)(\d+)[\/:]
                            # Groups of symbol float (/5.5/5.5/5.5), separated by slash or colon
                            ([\/:\.\d]+)
                            # Optional dash (-Bearer Channel)
                            (-.*)?
                            $}x;

    my @a = (); my @b = ();

    if ($aval =~ $dotted_numeric) {
        @a = ($1,$2);
    } elsif ($aval =~ $letter_number) {
        @a = ($1,$2);
    } elsif ($aval =~ $netgear) {
        @a = ($1,$2);
    } elsif ($aval =~ $numbers) {
        @a = ($1);
    } elsif ($aval =~ $ciscofast) {
        @a = ($1,$2);
        push @a, split(/[:\/]/,$3), $4;
    } elsif ($aval =~ $wordcharword) {
        @a = ($1,$2,$3);
    } else {
        @a = ($aval);
    }

    if ($bval =~ $dotted_numeric) {
        @b = ($1,$2);
    } elsif ($bval =~ $letter_number) {
        @b = ($1,$2);
    } elsif ($bval =~ $netgear) {
        @b = ($1,$2);
    } elsif ($bval =~ $numbers) {
        @b = ($1);
    } elsif ($bval =~ $ciscofast) {
        @b = ($1,$2);
        push @b, split(/[:\/]/,$3),$4;
    } elsif ($bval =~ $wordcharword) {
        @b = ($1,$2,$3);
    } else {
        @b = ($bval);
    }

    # Equal until proven otherwise
    my $val = 0;
    while (scalar(@a) or scalar(@b)){
        # carried around from the last find.
        last if $val != 0;
	
        my $a1 = shift @a;
        my $b1 = shift @b;

        if (!defined $a1 and !defined $b1) {
	    $val = 0;
	    last;
        }

        # A has more components - loses
        unless (defined $b1){
            $val = 1;
            last;
        }

        # A has less components - wins
        unless (defined $a1) {
            $val = -1;
            last;
        }
	#elog(WARNING, "a1: $a1");
	#elog(WARNING, "b1: $b1");
        if ($a1 =~ $numeric and $b1 =~ $numeric){
            $val = $a1 <=> $b1;
        } elsif ($a1 ne $b1) {
            $val = $a1 cmp $b1;
        }
    }

    return $val;
$_$;


ALTER FUNCTION public.port_cmp(text, text) OWNER TO postgres;

--
-- Name: port_eq(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_eq(text, text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) = 0;
	END;
$_$;


ALTER FUNCTION public.port_eq(text, text) OWNER TO postgres;

--
-- Name: port_eq(port, port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_eq(port, port) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) = 0;
	END;
$_$;


ALTER FUNCTION public.port_eq(port, port) OWNER TO postgres;

--
-- Name: port_gt(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_gt(text, text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) > 0;
	END;
$_$;


ALTER FUNCTION public.port_gt(text, text) OWNER TO postgres;

--
-- Name: port_gt(port, port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_gt(port, port) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) > 0;
	END;
$_$;


ALTER FUNCTION public.port_gt(port, port) OWNER TO postgres;

--
-- Name: port_gte(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_gte(text, text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) >= 0;
	END;
$_$;


ALTER FUNCTION public.port_gte(text, text) OWNER TO postgres;

--
-- Name: port_gte(port, port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_gte(port, port) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) >= 0;
	END;
$_$;


ALTER FUNCTION public.port_gte(port, port) OWNER TO postgres;

--
-- Name: port_lt(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_lt(text, text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) < 0;
	END;
$_$;


ALTER FUNCTION public.port_lt(text, text) OWNER TO postgres;

--
-- Name: port_lt(port, port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_lt(port, port) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) < 0;
	END;
$_$;


ALTER FUNCTION public.port_lt(port, port) OWNER TO postgres;

--
-- Name: port_lte(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_lte(text, text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) <= 0;
	END;
$_$;


ALTER FUNCTION public.port_lte(text, text) OWNER TO postgres;

--
-- Name: port_lte(port, port); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION port_lte(port, port) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
	BEGIN
		RETURN port_cmp($1, $2) <= 0;
	END;
$_$;


ALTER FUNCTION public.port_lte(port, port) OWNER TO postgres;

--
-- Name: portinfo_building_update(); Type: FUNCTION; Schema: public; Owner: netdisco
--

CREATE FUNCTION portinfo_building_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
        IF NEW.building <> OLD.building THEN
		 UPDATE portinfo 
		 SET building_campus = building_name.campus, building_num = building_name.num
		 FROM building_name
		 WHERE building_name.name = NEW.building and building_name.name_type = 'SHORT' and portinfo.ip = NEW.ip and portinfo.port = NEW.port;
	END IF;

        
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.portinfo_building_update() OWNER TO netdisco;

--
-- Name: <#; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR <# (
    PROCEDURE = port_lt,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.<# (text, text) OWNER TO postgres;

--
-- Name: <=; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR <= (
    PROCEDURE = port_lt,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.<= (text, text) OWNER TO postgres;

--
-- Name: <=#; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR <=# (
    PROCEDURE = port_lte,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.<=# (text, text) OWNER TO postgres;

--
-- Name: =#; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR =# (
    PROCEDURE = port_eq,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.=# (text, text) OWNER TO postgres;

--
-- Name: >#; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR ># (
    PROCEDURE = port_gte,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.># (text, text) OWNER TO postgres;

--
-- Name: >=#; Type: OPERATOR; Schema: public; Owner: postgres
--

CREATE OPERATOR >=# (
    PROCEDURE = port_gte,
    LEFTARG = text,
    RIGHTARG = text
);


ALTER OPERATOR public.>=# (text, text) OWNER TO postgres;

--
-- Name: port_ops; Type: OPERATOR CLASS; Schema: public; Owner: postgres
--

CREATE OPERATOR CLASS port_ops
    FOR TYPE text USING btree AS
    OPERATOR 1 <#(text,text) ,
    OPERATOR 2 <=#(text,text) ,
    OPERATOR 3 =#(text,text) ,
    OPERATOR 4 >=#(text,text) ,
    OPERATOR 5 >#(text,text) ,
    FUNCTION 1 (text, text) port_cmp(text,text);


ALTER OPERATOR CLASS public.port_ops USING btree OWNER TO postgres;

SET search_path = pg_catalog;

--
-- Name: CAST (text AS public.port); Type: CAST; Schema: pg_catalog; Owner: 
--

CREATE CAST (text AS public.port) WITH FUNCTION public.cast_to_port(text);


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: admin; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE admin (
    job integer NOT NULL,
    entered timestamp without time zone DEFAULT now(),
    started timestamp without time zone,
    finished timestamp without time zone,
    device inet,
    port text,
    action text,
    subaction text,
    status text,
    username text,
    userip inet,
    log text,
    debug boolean,
    oldvlan text,
    newvlan text,
    bwuser text
);


ALTER TABLE public.admin OWNER TO netdisco;

--
-- Name: admin_job_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE admin_job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.admin_job_seq OWNER TO netdisco;

--
-- Name: admin_job_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: netdisco
--

ALTER SEQUENCE admin_job_seq OWNED BY admin.job;


--
-- Name: bs_ts_log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE bs_ts_log (
    userid character varying(10) NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    ip inet NOT NULL,
    username character varying(15) NOT NULL,
    service character varying(2) NOT NULL,
    result character varying(15)
);


ALTER TABLE public.bs_ts_log OWNER TO netdisco;

--
-- Name: bsocket_macs; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE bsocket_macs (
    mac macaddr NOT NULL
);


ALTER TABLE public.bsocket_macs OWNER TO netdisco;

--
-- Name: building; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE building (
    campus text NOT NULL,
    num text NOT NULL,
    address text,
    occup text
);


ALTER TABLE public.building OWNER TO netdisco;

--
-- Name: building_name; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE building_name (
    campus text NOT NULL,
    num text NOT NULL,
    name text NOT NULL,
    name_type text NOT NULL
);


ALTER TABLE public.building_name OWNER TO netdisco;

--
-- Name: community; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE community (
    ip inet NOT NULL,
    snmp_comm_rw text,
    snmp_auth_tag text
);


ALTER TABLE public.community OWNER TO netdisco;

--
-- Name: dbix_class_schema_versions; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE dbix_class_schema_versions (
    version character varying(10) NOT NULL,
    installed character varying(20) NOT NULL
);


ALTER TABLE public.dbix_class_schema_versions OWNER TO netdisco;

--
-- Name: device; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device (
    ip inet NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    dns text,
    description text,
    uptime bigint,
    contact text,
    name text,
    location text,
    layers character varying(8),
    ports integer,
    mac macaddr,
    serial text,
    model text,
    ps1_type text,
    ps2_type text,
    ps1_status text,
    ps2_status text,
    fan text,
    slots integer,
    vendor text,
    os text,
    os_ver text,
    log text,
    snmp_ver integer,
    snmp_comm text,
    vtp_domain text,
    last_discover timestamp without time zone,
    last_macsuck timestamp without time zone,
    last_arpnip timestamp without time zone,
    snmp_class text
);


ALTER TABLE public.device OWNER TO netdisco;

--
-- Name: device_info; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_info (
    ip inet NOT NULL,
    dns text NOT NULL,
    ups_type text,
    access_ctrl text,
    connected text
);


ALTER TABLE public.device_info OWNER TO netdisco;

--
-- Name: device_ip; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_ip (
    ip inet NOT NULL,
    alias inet NOT NULL,
    port text,
    dns text,
    creation timestamp without time zone DEFAULT now(),
    subnet cidr
);


ALTER TABLE public.device_ip OWNER TO netdisco;

--
-- Name: device_log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_log (
    ip inet NOT NULL,
    dns text,
    log text,
    creation timestamp with time zone DEFAULT now(),
    username text
);


ALTER TABLE public.device_log OWNER TO netdisco;

--
-- Name: device_log_report_1; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_log_report_1 (
    ip inet NOT NULL,
    dns text NOT NULL,
    uptime bigint,
    os_ver text
);


ALTER TABLE public.device_log_report_1 OWNER TO netdisco;

--
-- Name: device_log_report_2; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_log_report_2 (
    ip inet NOT NULL,
    dns text NOT NULL,
    slot text,
    value text
);


ALTER TABLE public.device_log_report_2 OWNER TO netdisco;

--
-- Name: device_module; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_module (
    ip inet NOT NULL,
    index integer NOT NULL,
    description text,
    type text,
    parent integer,
    name text,
    class text,
    pos integer,
    hw_ver text,
    fw_ver text,
    sw_ver text,
    serial text,
    model text,
    fru boolean,
    creation timestamp without time zone DEFAULT now(),
    last_discover timestamp without time zone
);


ALTER TABLE public.device_module OWNER TO netdisco;

--
-- Name: device_port; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port (
    ip inet NOT NULL,
    port text NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    descr text,
    up text,
    up_admin text,
    type text,
    duplex text,
    duplex_admin text,
    speed text,
    name text,
    mac macaddr,
    mtu integer,
    stp text,
    remote_ip inet,
    remote_port text,
    remote_type text,
    remote_id text,
    vlan text,
    portfast text,
    vlantype text,
    speed_admin text,
    lastchange bigint,
    pvid integer,
    manual_topo boolean DEFAULT false NOT NULL,
    is_uplink boolean,
    slave_of text,
    is_master boolean DEFAULT false NOT NULL
);


ALTER TABLE public.device_port OWNER TO netdisco;

--
-- Name: device_port2; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port2 (
    ip inet,
    port text,
    creation timestamp without time zone,
    descr text,
    up text,
    up_admin text,
    type text,
    duplex text,
    duplex_admin text,
    speed text,
    name text,
    mac macaddr,
    mtu integer,
    stp text,
    remote_ip inet,
    remote_port text,
    remote_type text,
    remote_id text,
    vlan text,
    portfast text,
    vlantype text,
    speed_admin text,
    lastchange bigint,
    pvid integer,
    manual_topo boolean,
    is_uplink boolean,
    slave_of text,
    is_master boolean
);


ALTER TABLE public.device_port2 OWNER TO netdisco;

--
-- Name: device_port3; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE device_port3 (
    port port
);


ALTER TABLE public.device_port3 OWNER TO postgres;

--
-- Name: device_port_log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port_log (
    id integer NOT NULL,
    ip inet,
    port text,
    reason text,
    log text,
    username text,
    userip inet,
    action text,
    creation timestamp without time zone DEFAULT now(),
    oldvlan text,
    newvlan text,
    bwuser text
);


ALTER TABLE public.device_port_log OWNER TO netdisco;

--
-- Name: device_port_log_id_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE device_port_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.device_port_log_id_seq OWNER TO netdisco;

--
-- Name: device_port_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: netdisco
--

ALTER SEQUENCE device_port_log_id_seq OWNED BY device_port_log.id;


--
-- Name: device_port_power; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port_power (
    ip inet NOT NULL,
    port text NOT NULL,
    module integer,
    admin text,
    status text,
    class text,
    power integer
);


ALTER TABLE public.device_port_power OWNER TO netdisco;

--
-- Name: device_port_ssid; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port_ssid (
    ip inet,
    port text,
    ssid text,
    broadcast boolean,
    bssid macaddr
);


ALTER TABLE public.device_port_ssid OWNER TO netdisco;

--
-- Name: device_port_vlan; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port_vlan (
    ip inet NOT NULL,
    port text NOT NULL,
    vlan integer NOT NULL,
    native boolean DEFAULT false NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    last_discover timestamp without time zone DEFAULT now(),
    vlantype text
);


ALTER TABLE public.device_port_vlan OWNER TO netdisco;

--
-- Name: device_port_wireless; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_port_wireless (
    ip inet,
    port text,
    channel integer,
    power integer
);


ALTER TABLE public.device_port_wireless OWNER TO netdisco;

--
-- Name: device_power; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_power (
    ip inet NOT NULL,
    module integer NOT NULL,
    power integer,
    status text
);


ALTER TABLE public.device_power OWNER TO netdisco;

--
-- Name: device_record; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_record (
    ip inet NOT NULL,
    dns text NOT NULL,
    mac macaddr,
    serial text,
    model text,
    creation timestamp without time zone
);


ALTER TABLE public.device_record OWNER TO netdisco;

--
-- Name: device_vlan; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE device_vlan (
    ip inet NOT NULL,
    vlan integer NOT NULL,
    description text,
    creation timestamp without time zone DEFAULT now(),
    last_discover timestamp without time zone DEFAULT now()
);


ALTER TABLE public.device_vlan OWNER TO netdisco;

--
-- Name: fiberinfo; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE fiberinfo (
    number text NOT NULL,
    oldnumber text,
    type text,
    end1 text,
    end1type text,
    end2 text,
    end2type text,
    size text,
    length text,
    channel text,
    status text,
    last_modified timestamp without time zone DEFAULT now(),
    last_modified_by text,
    comment text
);


ALTER TABLE public.fiberinfo OWNER TO netdisco;

--
-- Name: log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE log (
    id integer NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    class text,
    entry text,
    logfile text
);


ALTER TABLE public.log OWNER TO netdisco;

--
-- Name: log_id_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.log_id_seq OWNER TO netdisco;

--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: netdisco
--

ALTER SEQUENCE log_id_seq OWNED BY log.id;


--
-- Name: mac_inventory_report; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE mac_inventory_report (
    month_year character varying(6) NOT NULL,
    count integer
);


ALTER TABLE public.mac_inventory_report OWNER TO netdisco;

--
-- Name: machine_room; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE machine_room (
    ip inet NOT NULL,
    dns text,
    core boolean,
    ctrl boolean
);


ALTER TABLE public.machine_room OWNER TO netdisco;

--
-- Name: node; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE node (
    mac macaddr NOT NULL,
    switch inet NOT NULL,
    port text NOT NULL,
    active boolean,
    oui character varying(8),
    time_first timestamp without time zone DEFAULT now(),
    time_last timestamp without time zone DEFAULT now(),
    time_recent timestamp without time zone DEFAULT now(),
    vlan text DEFAULT '0'::text NOT NULL
);


ALTER TABLE public.node OWNER TO netdisco;

--
-- Name: node_ip; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE node_ip (
    mac macaddr NOT NULL,
    ip inet NOT NULL,
    active boolean,
    time_first timestamp without time zone DEFAULT now(),
    time_last timestamp without time zone DEFAULT now(),
    dns_record boolean,
    dns text
);


ALTER TABLE public.node_ip OWNER TO netdisco;

--
-- Name: node_monitor; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE node_monitor (
    mac macaddr NOT NULL,
    active boolean,
    why text,
    cc text,
    date timestamp without time zone DEFAULT now()
);


ALTER TABLE public.node_monitor OWNER TO netdisco;

--
-- Name: node_nbt; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE node_nbt (
    mac macaddr NOT NULL,
    ip inet,
    nbname text,
    domain text,
    server boolean,
    nbuser text,
    active boolean,
    time_first timestamp without time zone DEFAULT now(),
    time_last timestamp without time zone DEFAULT now()
);


ALTER TABLE public.node_nbt OWNER TO netdisco;

--
-- Name: node_wireless; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE node_wireless (
    mac macaddr NOT NULL,
    uptime integer,
    maxrate integer,
    txrate integer,
    sigstrength integer,
    sigqual integer,
    rxpkt bigint,
    txpkt bigint,
    rxbyte bigint,
    txbyte bigint,
    time_last timestamp without time zone DEFAULT now(),
    ssid text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.node_wireless OWNER TO netdisco;

--
-- Name: oui; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE oui (
    oui character varying(8) NOT NULL,
    company text,
    abbrev text
);


ALTER TABLE public.oui OWNER TO netdisco;

--
-- Name: port_inventory_report; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE port_inventory_report (
    month_year character varying(6) NOT NULL,
    ten_mbps_up smallint NOT NULL,
    ten_mbps_down smallint NOT NULL,
    hundred_mbps_up smallint NOT NULL,
    hundred_mbps_down smallint NOT NULL,
    one_gbps_copper_up smallint NOT NULL,
    one_gbps_copper_down smallint NOT NULL,
    one_gbps_fiber_up smallint NOT NULL,
    one_gbps_fiber_down smallint NOT NULL
);


ALTER TABLE public.port_inventory_report OWNER TO netdisco;

--
-- Name: port_service_log_id_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE port_service_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
    CYCLE;


ALTER TABLE public.port_service_log_id_seq OWNER TO netdisco;

--
-- Name: port_type; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE port_type (
    description text NOT NULL
);


ALTER TABLE public.port_type OWNER TO netdisco;

--
-- Name: portinfo; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE portinfo (
    ip inet NOT NULL,
    port text NOT NULL,
    port_excel text,
    room text,
    jack text,
    riser1 text,
    pairs1 text,
    riser2 text,
    pairs2 text,
    cable text,
    grid text,
    wired text,
    comment text,
    building text,
    last_modified timestamp without time zone DEFAULT now(),
    last_modified_by text,
    phoneext text,
    building_campus text,
    building_num text
);


ALTER TABLE public.portinfo OWNER TO netdisco;

--
-- Name: process; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE process (
    controller integer NOT NULL,
    device inet NOT NULL,
    action text NOT NULL,
    status text,
    count integer,
    creation timestamp without time zone DEFAULT now()
);


ALTER TABLE public.process OWNER TO netdisco;

--
-- Name: quarantine; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE quarantine (
    vtp text NOT NULL,
    vlan text NOT NULL
);


ALTER TABLE public.quarantine OWNER TO netdisco;

--
-- Name: rancid; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE rancid (
    ip inet NOT NULL,
    dns text NOT NULL,
    value text NOT NULL,
    last_update timestamp without time zone DEFAULT now(),
    delete boolean DEFAULT true
);


ALTER TABLE public.rancid OWNER TO netdisco;

--
-- Name: recent_node; Type: MATERIALIZED VIEW; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE MATERIALIZED VIEW recent_node AS
 SELECT t.mac,
    t.switch,
    t.port,
    t.active,
    t.oui,
    t.time_first,
    t.time_last,
    t.time_recent,
    t.vlan
   FROM ( SELECT t_1.mac,
            t_1.switch,
            t_1.port,
            t_1.active,
            t_1.oui,
            t_1.time_first,
            t_1.time_last,
            t_1.time_recent,
            t_1.vlan
           FROM getsomenodes(10, false) t_1(mac macaddr, switch inet, port text, active boolean, oui character varying(8), time_first timestamp without time zone, time_last timestamp without time zone, time_recent timestamp without time zone, vlan text)) t
  WITH NO DATA;


ALTER TABLE public.recent_node OWNER TO netdisco;

--
-- Name: recent_node_node_ip; Type: MATERIALIZED VIEW; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE MATERIALIZED VIEW recent_node_node_ip AS
 SELECT t.mac,
    t.switch,
    t.port,
    t.active,
    t.oui,
    t.time_first,
    t.time_last,
    t.time_recent,
    t.vlan,
    node_ip.ip,
    node_ip.active AS ip_active,
    node_ip.time_first AS ip_time_first,
    node_ip.time_last AS ip_time_last,
    node_ip.dns_record,
    node_ip.dns
   FROM (( SELECT t_1.mac,
            t_1.switch,
            t_1.port,
            t_1.active,
            t_1.oui,
            t_1.time_first,
            t_1.time_last,
            t_1.time_recent,
            t_1.vlan
           FROM getsomenodes(10, false) t_1(mac macaddr, switch inet, port text, active boolean, oui character varying(8), time_first timestamp without time zone, time_last timestamp without time zone, time_recent timestamp without time zone, vlan text)) t
     LEFT JOIN node_ip ON (((t.mac = node_ip.mac) AND (t.active = node_ip.active))))
  ORDER BY t.switch, t.port
  WITH NO DATA;


ALTER TABLE public.recent_node_node_ip OWNER TO netdisco;

--
-- Name: resnet_report; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE resnet_report (
    month_year character varying(6) NOT NULL,
    keele_ugrad_active smallint NOT NULL,
    keele_ugrad_inactive smallint NOT NULL,
    keele_grad_active smallint NOT NULL,
    keele_grad_inactive smallint NOT NULL,
    glendon_active smallint NOT NULL,
    glendon_inactive smallint NOT NULL
);


ALTER TABLE public.resnet_report OWNER TO netdisco;

--
-- Name: search_log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE search_log (
    search_id integer NOT NULL,
    "time" timestamp with time zone,
    session_id numeric,
    uri text
);


ALTER TABLE public.search_log OWNER TO netdisco;

--
-- Name: TABLE search_log; Type: COMMENT; Schema: public; Owner: netdisco
--

COMMENT ON TABLE search_log IS 'Records history of various searches from the web interface.';


--
-- Name: search_log_search_id_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE search_log_search_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.search_log_search_id_seq OWNER TO netdisco;

--
-- Name: search_log_search_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: netdisco
--

ALTER SEQUENCE search_log_search_id_seq OWNED BY search_log.search_id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE sessions (
    id character(32) NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    a_session text
);


ALTER TABLE public.sessions OWNER TO netdisco;

--
-- Name: subnets; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE subnets (
    net cidr NOT NULL,
    creation timestamp without time zone DEFAULT now(),
    last_discover timestamp without time zone DEFAULT now()
);


ALTER TABLE public.subnets OWNER TO netdisco;

--
-- Name: topology; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE topology (
    dev1 inet NOT NULL,
    port1 text NOT NULL,
    dev2 inet NOT NULL,
    port2 text NOT NULL
);


ALTER TABLE public.topology OWNER TO netdisco;

--
-- Name: user_log; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE user_log (
    entry integer NOT NULL,
    username character varying(50),
    userip inet,
    event text,
    details text,
    creation timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_log OWNER TO netdisco;

--
-- Name: user_log_entry_seq; Type: SEQUENCE; Schema: public; Owner: netdisco
--

CREATE SEQUENCE user_log_entry_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_log_entry_seq OWNER TO netdisco;

--
-- Name: user_log_entry_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: netdisco
--

ALTER SEQUENCE user_log_entry_seq OWNED BY user_log.entry;


--
-- Name: users; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE users (
    username character varying(50) NOT NULL,
    password text,
    creation timestamp without time zone DEFAULT now(),
    last_on timestamp without time zone,
    port_control boolean DEFAULT false,
    admin boolean DEFAULT false,
    fullname text,
    note text,
    usergroup text,
    ldap boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO netdisco;

--
-- Name: voice_buildings; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE voice_buildings (
    building text
);


ALTER TABLE public.voice_buildings OWNER TO netdisco;

--
-- Name: voiceinfo; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE voiceinfo (
    room text,
    h_cbl text,
    c_rm text,
    type text,
    ext text,
    mdf text,
    idf text,
    bld text,
    l_m_b text,
    l_m timestamp without time zone DEFAULT now(),
    cmmnt text
);


ALTER TABLE public.voiceinfo OWNER TO netdisco;

--
-- Name: york_buildings; Type: TABLE; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE TABLE york_buildings (
    building text NOT NULL,
    yorknet_name text
);


ALTER TABLE public.york_buildings OWNER TO netdisco;

--
-- Name: job; Type: DEFAULT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY admin ALTER COLUMN job SET DEFAULT nextval('admin_job_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY device_port_log ALTER COLUMN id SET DEFAULT nextval('device_port_log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY log ALTER COLUMN id SET DEFAULT nextval('log_id_seq'::regclass);


--
-- Name: search_id; Type: DEFAULT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY search_log ALTER COLUMN search_id SET DEFAULT nextval('search_log_search_id_seq'::regclass);


--
-- Name: entry; Type: DEFAULT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY user_log ALTER COLUMN entry SET DEFAULT nextval('user_log_entry_seq'::regclass);


--
-- Name: admin_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY admin
    ADD CONSTRAINT admin_pkey PRIMARY KEY (job);


--
-- Name: bsocket_macs_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY bsocket_macs
    ADD CONSTRAINT bsocket_macs_pkey PRIMARY KEY (mac);


--
-- Name: building_name_unique; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY building_name
    ADD CONSTRAINT building_name_unique UNIQUE (campus, num, name, name_type);


--
-- Name: building_name_unique_official; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY building_name
    ADD CONSTRAINT building_name_unique_official EXCLUDE USING btree (campus WITH =, num WITH =) WHERE ((name_type = 'OFFICIAL'::text));


--
-- Name: building_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY building
    ADD CONSTRAINT building_pkey PRIMARY KEY (campus, num);


--
-- Name: community_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY community
    ADD CONSTRAINT community_pkey PRIMARY KEY (ip);


--
-- Name: dbix_class_schema_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY dbix_class_schema_versions
    ADD CONSTRAINT dbix_class_schema_versions_pkey PRIMARY KEY (version);


--
-- Name: device_ip_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_ip
    ADD CONSTRAINT device_ip_pkey PRIMARY KEY (ip, alias);


--
-- Name: device_module_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_module
    ADD CONSTRAINT device_module_pkey PRIMARY KEY (ip, index);


--
-- Name: device_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device
    ADD CONSTRAINT device_pkey PRIMARY KEY (ip);


--
-- Name: device_port_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_port
    ADD CONSTRAINT device_port_pkey PRIMARY KEY (port, ip);


--
-- Name: device_port_power_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_port_power
    ADD CONSTRAINT device_port_power_pkey PRIMARY KEY (port, ip);


--
-- Name: device_port_vlan_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_port_vlan
    ADD CONSTRAINT device_port_vlan_pkey PRIMARY KEY (ip, port, vlan, native);


--
-- Name: device_power_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_power
    ADD CONSTRAINT device_power_pkey PRIMARY KEY (ip, module);


--
-- Name: device_vlan_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY device_vlan
    ADD CONSTRAINT device_vlan_pkey PRIMARY KEY (ip, vlan);


--
-- Name: node_ip_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY node_ip
    ADD CONSTRAINT node_ip_pkey PRIMARY KEY (mac, ip);


--
-- Name: node_monitor_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY node_monitor
    ADD CONSTRAINT node_monitor_pkey PRIMARY KEY (mac);


--
-- Name: node_nbt_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY node_nbt
    ADD CONSTRAINT node_nbt_pkey PRIMARY KEY (mac);


--
-- Name: node_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY node
    ADD CONSTRAINT node_pkey PRIMARY KEY (mac, switch, port, vlan);


--
-- Name: node_wireless_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY node_wireless
    ADD CONSTRAINT node_wireless_pkey PRIMARY KEY (mac, ssid);


--
-- Name: oui_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY oui
    ADD CONSTRAINT oui_pkey PRIMARY KEY (oui);


--
-- Name: phone_buildings_building_key; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY voice_buildings
    ADD CONSTRAINT phone_buildings_building_key UNIQUE (building);


--
-- Name: port_inventory_report_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY port_inventory_report
    ADD CONSTRAINT port_inventory_report_pkey PRIMARY KEY (month_year);


--
-- Name: portinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY portinfo
    ADD CONSTRAINT portinfo_pkey PRIMARY KEY (ip, port);


--
-- Name: search_log_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY search_log
    ADD CONSTRAINT search_log_pkey PRIMARY KEY (search_id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: subnets_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY subnets
    ADD CONSTRAINT subnets_pkey PRIMARY KEY (net);


--
-- Name: topology_dev1_port1; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY topology
    ADD CONSTRAINT topology_dev1_port1 UNIQUE (dev1, port1);


--
-- Name: topology_dev2_port2; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY topology
    ADD CONSTRAINT topology_dev2_port2 UNIQUE (dev2, port2);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: netdisco; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: aidx_node_ip_active_time_last; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX aidx_node_ip_active_time_last ON node_ip USING btree (active, time_last);


--
-- Name: aidx_node_ip_dns_uc; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX aidx_node_ip_dns_uc ON node_ip USING btree (upper(dns) varchar_pattern_ops);


--
-- Name: INDEX aidx_node_ip_dns_uc; Type: COMMENT; Schema: public; Owner: netdisco
--

COMMENT ON INDEX aidx_node_ip_dns_uc IS 'Uppercase dns column index for case-insensitive searches';


--
-- Name: aidx_node_ip_mac_time_last; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX aidx_node_ip_mac_time_last ON node_ip USING btree (mac, time_last);


--
-- Name: aidx_node_ip_time_last; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX aidx_node_ip_time_last ON node_ip USING btree (time_last);


--
-- Name: device_port_power_idx_ip_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX device_port_power_idx_ip_port ON device_port_power USING btree (ip, port);


--
-- Name: fki_building_name_building; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX fki_building_name_building ON building_name USING btree (campus, num);


--
-- Name: idx_admin_action; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_admin_action ON admin USING btree (action);


--
-- Name: idx_admin_entered; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_admin_entered ON admin USING btree (entered);


--
-- Name: idx_admin_status; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_admin_status ON admin USING btree (status);


--
-- Name: idx_building_name_name; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_building_name_name ON building_name USING btree (name);


--
-- Name: idx_building_name_name_name_type; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_building_name_name_name_type ON building_name USING btree (name, name_type);


--
-- Name: idx_building_name_name_type; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_building_name_name_type ON building_name USING btree (name_type);


--
-- Name: idx_device_dns; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_dns ON device USING btree (dns);


--
-- Name: idx_device_ip_alias; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_ip_alias ON device_ip USING btree (alias);


--
-- Name: idx_device_ip_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_ip_ip ON device_ip USING btree (ip);


--
-- Name: idx_device_ip_ip_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_ip_ip_port ON device_ip USING btree (ip, port);


--
-- Name: idx_device_layers; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_layers ON device USING btree (layers);


--
-- Name: idx_device_model; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_model ON device USING btree (model);


--
-- Name: idx_device_port2_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port2_ip ON device_port2 USING btree (ip);


--
-- Name: idx_device_port2_ip_port_duplex; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port2_ip_port_duplex ON device_port2 USING btree (ip, port, duplex);


--
-- Name: idx_device_port2_ip_up_admin; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port2_ip_up_admin ON device_port2 USING btree (ip, up_admin);


--
-- Name: idx_device_port2_mac; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port2_mac ON device_port2 USING btree (mac);


--
-- Name: idx_device_port2_remote_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port2_remote_ip ON device_port2 USING btree (remote_ip);


--
-- Name: idx_device_port_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_ip ON device_port USING btree (ip);


--
-- Name: idx_device_port_ip_port_duplex; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_ip_port_duplex ON device_port USING btree (ip, port, duplex);


--
-- Name: idx_device_port_ip_up_admin; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_ip_up_admin ON device_port USING btree (ip, up_admin);


--
-- Name: idx_device_port_log_1; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_log_1 ON device_port_log USING btree (ip, port);


--
-- Name: idx_device_port_log_user; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_log_user ON device_port_log USING btree (username);


--
-- Name: idx_device_port_mac; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_mac ON device_port USING btree (mac);


--
-- Name: idx_device_port_port_proper; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_port_proper ON device_port2 USING btree (port port_ops);


--
-- Name: idx_device_port_remote_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_remote_ip ON device_port USING btree (remote_ip);


--
-- Name: idx_device_port_ssid_ip_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_ssid_ip_port ON device_port_ssid USING btree (ip, port);


--
-- Name: idx_device_port_wireless_ip_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_port_wireless_ip_port ON device_port_wireless USING btree (ip, port);


--
-- Name: idx_device_vendor; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_device_vendor ON device USING btree (vendor);


--
-- Name: idx_ip_device_port_log; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_ip_device_port_log ON device_port_log USING btree (ip);


--
-- Name: idx_node_ip_dns; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_ip_dns ON node_ip USING btree (dns);


--
-- Name: idx_node_ip_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_ip_ip ON node_ip USING btree (ip);


--
-- Name: idx_node_ip_ip_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_ip_ip_active ON node_ip USING btree (ip, active);


--
-- Name: idx_node_ip_mac; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_ip_mac ON node_ip USING btree (mac);


--
-- Name: idx_node_ip_mac_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_ip_mac_active ON node_ip USING btree (mac, active);


--
-- Name: idx_node_mac; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_mac ON node USING btree (mac);


--
-- Name: idx_node_mac_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_mac_active ON node USING btree (mac, active);


--
-- Name: idx_node_nbt_domain; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_nbt_domain ON node_nbt USING btree (domain);


--
-- Name: idx_node_nbt_mac; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_nbt_mac ON node_nbt USING btree (mac);


--
-- Name: idx_node_nbt_mac_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_nbt_mac_active ON node_nbt USING btree (mac, active);


--
-- Name: idx_node_nbt_nbname; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_nbt_nbname ON node_nbt USING btree (nbname);


--
-- Name: idx_node_switch; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_switch ON node USING btree (switch);


--
-- Name: idx_node_switch_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_switch_port ON node USING btree (switch, port);


--
-- Name: idx_node_switch_port_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_node_switch_port_active ON node USING btree (switch, port, active);


--
-- Name: idx_port_device_port_log; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_port_device_port_log ON device_port_log USING btree (port);


--
-- Name: idx_portinfo_building; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_building ON portinfo USING btree (building);


--
-- Name: idx_portinfo_buildling_room; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_buildling_room ON portinfo USING btree (building, room);


--
-- Name: idx_portinfo_buildling_room_jack; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_buildling_room_jack ON portinfo USING btree (building, room, jack);


--
-- Name: idx_portinfo_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_ip ON portinfo USING btree (ip);


--
-- Name: idx_portinfo_ip_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_ip_port ON portinfo USING btree (ip, port);


--
-- Name: idx_portinfo_ip_port_excel; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_portinfo_ip_port_excel ON portinfo USING btree (ip, port_excel);


--
-- Name: idx_rancid_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_rancid_ip ON rancid USING btree (ip);


--
-- Name: idx_recent_node_node_ip_switch_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_recent_node_node_ip_switch_port ON recent_node_node_ip USING btree (switch, port);


--
-- Name: idx_recent_node_switch_port; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_recent_node_switch_port ON recent_node USING btree (switch, port);


--
-- Name: idx_recent_node_unique; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE UNIQUE INDEX idx_recent_node_unique ON recent_node USING btree (mac, switch, port, vlan);


--
-- Name: idx_unique_recent_node_node_ip; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_recent_node_node_ip ON recent_node_node_ip USING btree (mac, switch, port, vlan, ip);


--
-- Name: idx_voiceinfo_bld; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_voiceinfo_bld ON voiceinfo USING btree (bld);


--
-- Name: idx_voiceinfo_ext; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_voiceinfo_ext ON voiceinfo USING btree (ext);


--
-- Name: idx_voiceinfo_mdf; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX idx_voiceinfo_mdf ON voiceinfo USING btree (mdf);


--
-- Name: node_ip_idx_ip_active; Type: INDEX; Schema: public; Owner: netdisco; Tablespace: 
--

CREATE INDEX node_ip_idx_ip_active ON node_ip USING btree (ip, active);


--
-- Name: building_name_campus_fkey; Type: FK CONSTRAINT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY building_name
    ADD CONSTRAINT building_name_campus_fkey FOREIGN KEY (campus, num) REFERENCES building(campus, num);


--
-- Name: portinfo_building_fkey; Type: FK CONSTRAINT; Schema: public; Owner: netdisco
--

ALTER TABLE ONLY portinfo
    ADD CONSTRAINT portinfo_building_fkey FOREIGN KEY (building_campus, building_num) REFERENCES building(campus, num);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: admin; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE admin FROM PUBLIC;
REVOKE ALL ON TABLE admin FROM netdisco;
GRANT ALL ON TABLE admin TO netdisco;
GRANT SELECT ON TABLE admin TO netinfo;


--
-- Name: admin_job_seq; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON SEQUENCE admin_job_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE admin_job_seq FROM netdisco;
GRANT ALL ON SEQUENCE admin_job_seq TO netdisco;
GRANT SELECT ON SEQUENCE admin_job_seq TO netinfo;


--
-- Name: bs_ts_log; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE bs_ts_log FROM PUBLIC;
REVOKE ALL ON TABLE bs_ts_log FROM netdisco;
GRANT ALL ON TABLE bs_ts_log TO netdisco;
GRANT SELECT ON TABLE bs_ts_log TO netinfo;


--
-- Name: bsocket_macs; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE bsocket_macs FROM PUBLIC;
REVOKE ALL ON TABLE bsocket_macs FROM netdisco;
GRANT ALL ON TABLE bsocket_macs TO netdisco;
GRANT SELECT ON TABLE bsocket_macs TO netinfo;


--
-- Name: device; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device FROM PUBLIC;
REVOKE ALL ON TABLE device FROM netdisco;
GRANT ALL ON TABLE device TO netdisco;
GRANT SELECT ON TABLE device TO netinfo;


--
-- Name: device_info; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_info FROM PUBLIC;
REVOKE ALL ON TABLE device_info FROM netdisco;
GRANT ALL ON TABLE device_info TO netdisco;
GRANT SELECT ON TABLE device_info TO netinfo;


--
-- Name: device_ip; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_ip FROM PUBLIC;
REVOKE ALL ON TABLE device_ip FROM netdisco;
GRANT ALL ON TABLE device_ip TO netdisco;
GRANT SELECT ON TABLE device_ip TO netinfo;


--
-- Name: device_log; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_log FROM PUBLIC;
REVOKE ALL ON TABLE device_log FROM netdisco;
GRANT ALL ON TABLE device_log TO netdisco;
GRANT SELECT ON TABLE device_log TO netinfo;


--
-- Name: device_log_report_1; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_log_report_1 FROM PUBLIC;
REVOKE ALL ON TABLE device_log_report_1 FROM netdisco;
GRANT ALL ON TABLE device_log_report_1 TO netdisco;
GRANT SELECT ON TABLE device_log_report_1 TO netinfo;


--
-- Name: device_log_report_2; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_log_report_2 FROM PUBLIC;
REVOKE ALL ON TABLE device_log_report_2 FROM netdisco;
GRANT ALL ON TABLE device_log_report_2 TO netdisco;
GRANT SELECT ON TABLE device_log_report_2 TO netinfo;


--
-- Name: device_port; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_port FROM PUBLIC;
REVOKE ALL ON TABLE device_port FROM netdisco;
GRANT ALL ON TABLE device_port TO netdisco;
GRANT SELECT ON TABLE device_port TO netinfo;


--
-- Name: device_port_log; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_port_log FROM PUBLIC;
REVOKE ALL ON TABLE device_port_log FROM netdisco;
GRANT ALL ON TABLE device_port_log TO netdisco;
GRANT SELECT ON TABLE device_port_log TO netinfo;


--
-- Name: device_port_log_id_seq; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON SEQUENCE device_port_log_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE device_port_log_id_seq FROM netdisco;
GRANT ALL ON SEQUENCE device_port_log_id_seq TO netdisco;
GRANT SELECT ON SEQUENCE device_port_log_id_seq TO netinfo;


--
-- Name: device_record; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE device_record FROM PUBLIC;
REVOKE ALL ON TABLE device_record FROM netdisco;
GRANT ALL ON TABLE device_record TO netdisco;
GRANT SELECT ON TABLE device_record TO netinfo;


--
-- Name: fiberinfo; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE fiberinfo FROM PUBLIC;
REVOKE ALL ON TABLE fiberinfo FROM netdisco;
GRANT ALL ON TABLE fiberinfo TO netdisco;
GRANT SELECT ON TABLE fiberinfo TO netinfo;


--
-- Name: log; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE log FROM PUBLIC;
REVOKE ALL ON TABLE log FROM netdisco;
GRANT ALL ON TABLE log TO netdisco;
GRANT SELECT ON TABLE log TO netinfo;


--
-- Name: log_id_seq; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON SEQUENCE log_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE log_id_seq FROM netdisco;
GRANT ALL ON SEQUENCE log_id_seq TO netdisco;
GRANT SELECT ON SEQUENCE log_id_seq TO netinfo;


--
-- Name: mac_inventory_report; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE mac_inventory_report FROM PUBLIC;
REVOKE ALL ON TABLE mac_inventory_report FROM netdisco;
GRANT ALL ON TABLE mac_inventory_report TO netdisco;
GRANT SELECT ON TABLE mac_inventory_report TO netinfo;


--
-- Name: machine_room; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE machine_room FROM PUBLIC;
REVOKE ALL ON TABLE machine_room FROM netdisco;
GRANT ALL ON TABLE machine_room TO netdisco;
GRANT SELECT ON TABLE machine_room TO netinfo;


--
-- Name: node; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE node FROM PUBLIC;
REVOKE ALL ON TABLE node FROM netdisco;
GRANT ALL ON TABLE node TO netdisco;
GRANT SELECT ON TABLE node TO netinfo;


--
-- Name: node_ip; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE node_ip FROM PUBLIC;
REVOKE ALL ON TABLE node_ip FROM netdisco;
GRANT ALL ON TABLE node_ip TO netdisco;
GRANT SELECT ON TABLE node_ip TO netinfo;


--
-- Name: oui; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE oui FROM PUBLIC;
REVOKE ALL ON TABLE oui FROM netdisco;
GRANT ALL ON TABLE oui TO netdisco;
GRANT SELECT ON TABLE oui TO netinfo;


--
-- Name: port_inventory_report; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE port_inventory_report FROM PUBLIC;
REVOKE ALL ON TABLE port_inventory_report FROM netdisco;
GRANT ALL ON TABLE port_inventory_report TO netdisco;
GRANT SELECT ON TABLE port_inventory_report TO netinfo;


--
-- Name: port_service_log_id_seq; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON SEQUENCE port_service_log_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE port_service_log_id_seq FROM netdisco;
GRANT ALL ON SEQUENCE port_service_log_id_seq TO netdisco;
GRANT SELECT ON SEQUENCE port_service_log_id_seq TO netinfo;


--
-- Name: port_type; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE port_type FROM PUBLIC;
REVOKE ALL ON TABLE port_type FROM netdisco;
GRANT ALL ON TABLE port_type TO netdisco;
GRANT SELECT ON TABLE port_type TO netinfo;


--
-- Name: portinfo; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE portinfo FROM PUBLIC;
REVOKE ALL ON TABLE portinfo FROM netdisco;
GRANT ALL ON TABLE portinfo TO netdisco;
GRANT SELECT ON TABLE portinfo TO netinfo;


--
-- Name: quarantine; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE quarantine FROM PUBLIC;
REVOKE ALL ON TABLE quarantine FROM netdisco;
GRANT ALL ON TABLE quarantine TO netdisco;
GRANT SELECT ON TABLE quarantine TO netinfo;


--
-- Name: rancid; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE rancid FROM PUBLIC;
REVOKE ALL ON TABLE rancid FROM netdisco;
GRANT ALL ON TABLE rancid TO netdisco;
GRANT SELECT ON TABLE rancid TO netinfo;


--
-- Name: resnet_report; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE resnet_report FROM PUBLIC;
REVOKE ALL ON TABLE resnet_report FROM netdisco;
GRANT ALL ON TABLE resnet_report TO netdisco;
GRANT SELECT ON TABLE resnet_report TO netinfo;


--
-- Name: sessions; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE sessions FROM PUBLIC;
REVOKE ALL ON TABLE sessions FROM netdisco;
GRANT ALL ON TABLE sessions TO netdisco;
GRANT ALL ON TABLE sessions TO netinfo;


--
-- Name: users; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE users FROM PUBLIC;
REVOKE ALL ON TABLE users FROM netdisco;
GRANT ALL ON TABLE users TO netdisco;
GRANT SELECT ON TABLE users TO netinfo;


--
-- Name: voice_buildings; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE voice_buildings FROM PUBLIC;
REVOKE ALL ON TABLE voice_buildings FROM netdisco;
GRANT ALL ON TABLE voice_buildings TO netdisco;
GRANT SELECT ON TABLE voice_buildings TO netinfo;


--
-- Name: voiceinfo; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE voiceinfo FROM PUBLIC;
REVOKE ALL ON TABLE voiceinfo FROM netdisco;
GRANT ALL ON TABLE voiceinfo TO netdisco;
GRANT SELECT ON TABLE voiceinfo TO netinfo;


--
-- Name: york_buildings; Type: ACL; Schema: public; Owner: netdisco
--

REVOKE ALL ON TABLE york_buildings FROM PUBLIC;
REVOKE ALL ON TABLE york_buildings FROM netdisco;
GRANT ALL ON TABLE york_buildings TO netdisco;
GRANT SELECT ON TABLE york_buildings TO netinfo;


--
-- PostgreSQL database dump complete
--

