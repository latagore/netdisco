package App::Netdisco::DB::ResultSet::DevicePort;
use base 'App::Netdisco::DB::ResultSet';
use Data::Dumper;

use strict;
use warnings;

__PACKAGE__->load_components(qw/
  +App::Netdisco::DB::ExplicitLocking
/);

=head1 ADDITIONAL METHODS

=head2 with_times

This is a modifier for any C<search()> (including the helpers below) which
will add the following additional synthesized columns to the result set:

=over 4

=item lastchange_stamp

=back

=cut

sub with_times {
  my ($rs, $cond, $attrs) = @_;

  return $rs
    ->search_rs($cond, $attrs)
    ->search({},
      {
        '+columns' => { lastchange_stamp =>
          \("to_char(device.last_discover - (device.uptime - me.lastchange) / 100 * interval '1 second', "
            ."'YYYY-MM-DD HH24:MI:SS')") },
        join => 'device',
      });
}

=head2 with_free_ports

This is a modifier for any C<search()> (including the helpers below) which
will add the following additional synthesized columns to the result set:

=over 4

=item is_free

=back

In the C<$cond> hash (the first parameter) pass in the C<age_num> which must
be an integer, and the C<age_unit> which must be a string of either C<days>,
C<weeks>, C<months> or C<years>.

=cut

sub with_is_free {
  my ($rs, $cond, $attrs) = @_;

  my $interval = (delete $cond->{age_num}) .' '. (delete $cond->{age_unit});

  return $rs
    ->search_rs($cond, $attrs)
    ->search({},
      {
        '+columns' => { 
          # hard code the sql query because the perl DB interface is the bane
          # of existence and very difficult to do simple nested queries
          is_free => \[
            "me.up != 'up' and me.remote_ip IS NULL AND NOT EXISTS("
              ."select node.switch from node where now() - node.time_last <= "
              ."?::interval and node.switch = me.ip and node.port = me.port)"
              ."AND me.type != 'propVirtual'"
            , $interval]
        }
      });
}

=head2 only_free_ports

This is a modifier for any C<search()> (including the helpers below) which
will restrict results based on whether the port is considered "free".

In the C<$cond> hash (the first parameter) pass in the C<age_num> which must
be an integer, and the C<age_unit> which must be a string of either C<days>,
C<weeks>, C<months> or C<years>.

=cut

sub only_free_ports {
  my ($rs, $cond, $attrs) = @_;

  my $interval = (delete $cond->{age_num}) .' '. (delete $cond->{age_unit});

  return $rs
    ->search_rs($cond, $attrs)
    ->search(
      {
        'me.up' => { '!=' => 'up' },
      },{
        '+columns' => { 
          # hard code the sql query because the perl DB interface is the bane
          # of existence and very difficult to do simple nested queries
          is_free => \[
            "me.remote_ip IS NULL AND NOT EXISTS("
              ."select node.switch from node where now() - node.time_last <= "
              ."?::interval and node.switch = me.ip and node.port = me.port)"
              ."AND me.type != 'propVirtual'"
            , $interval]
        },
        where => \[
            "me.remote_ip IS NULL AND NOT EXISTS("
              ."select node.switch from node where now() - node.time_last <= "
              ."?::interval and node.switch = me.ip and node.port = me.port)"
              ."AND me.type != 'propVirtual'"
            , $interval]
        },
    );
}

=head2 with_vlan_count

This is a modifier for any C<search()> (including the helpers below) which
will add the following additional synthesized columns to the result set:

=over 4

=item vlan_count

=back

=cut

sub with_vlan_count {
  my ($rs, $cond, $attrs) = @_;

  return $rs
    ->search_rs($cond, $attrs)
    ->search({},
      {
        prefetch => "vlan_stats",
        '+columns' => {"me.vlan_count" => "vlan_stats.vlan_count" }
      });
}

=head2 with_node_count

This is a modifier for any C<search()> (including the helpers below) which
will add the following additional synthesized columns to the result set:

=over 4

=item node_count

=back

=cut

sub with_node_count {
  my ($rs, $cond, $attrs) = @_;
  
  my $alias = $rs->current_source_alias;
  return $rs
    ->search_rs($cond, $attrs)
    ->search({},
      {
        '+select' => \"(select count(*) from node where node.switch = ${alias}.ip and node.port = ${alias}.port) as node_count",
        '+as' => 'node_count'
      });
}

=head2 with_active_node_count

This is a modifier for any C<search()> (including the helpers below) which
will add the following additional synthesized columns to the result set:

=over 4

=item node_count

=back

=cut

sub with_active_node_count {
  my ($rs, $cond, $attrs) = @_;
  
  my $alias = $rs->current_source_alias;
  return $rs
    ->search_rs($cond, $attrs)
    ->search({},
      {
        '+select' => \"(select count(*) from node where node.switch = ${alias}.ip and node.port = ${alias}.port and active) as node_count",
        '+as' => 'node_count'
      });
}

=head2 merge_rs

This is a utility which merges the information from other device
port result sets. For example, $rs->merge_rs($ports_rs->all_port_vlans)
adds the all_port_vlans information to $rs.

=over 4

=item TODO

=back

=cut

sub merge_rs {
  my ($rs, $others) = @_;
  
  die 'undefined $others result set' 
    unless defined $others;
  
  if (!ref($others) eq 'array'){
    $others = [$others];
  }
  
  my @hri = $rs->hri->all;
  
    use Data::Dumper;
  
  
  # get the information from other result sets and
  # store them in hashrefs for quick lookup;
  # this way, we only have to iterate through each result
  # set at most a constant number of times.
  my @other_hrs;
  for my $other (@$others) {
    my @other_hri = $other->hri->all;
    
    my %other_hr;
    for my $row (@other_hri){
      my $ip = $row->{ip};
      my $port = $row->{port};
      die 'no ip column in $other result set' 
        unless defined $ip;
      die 'no port column in $other result set'
        unless defined $port;
      $other_hr{$ip}{$port} = $row;
    }
    push @other_hrs, \%other_hr;
  }
  
  # iterate through all the entries in $rs
  for my $row (@hri){
    my $ip = $row->{ip};
    my $port = $row->{port};
    
    # add additional information other result sets
    for my $other_hr (@other_hrs){
      if (exists $other_hr->{$ip}{$port}){
        my $entry = $other_hr->{$ip}{$port};
        # go through each piece of information that the row 
        # has that isn't in the original set and add it
        for my $key (keys $entry){ 
          unless (exists $row->{$key}){
            $row->{$key} = $entry->{$key};
          }
        }
      }
    }
  }
  return @hri;
}

=head2 with_york_port_info

This is a modifier for any C<search()> which adds the York port info that
matches the DNS name for the device.

=over 4

=item TODO

=back

=cut

sub with_york_port_info {
  my ($rs, $cond, $attrs) = @_;

  return $rs
    ->search_rs($cond, $attrs)
    ->search(
      {},
      {
	      prefetch => [ 'port_info']
      }
    );
}


=head1 SPECIAL METHODS

=head2 delete( \%options? )

Overrides the built-in L<DBIx::Class> delete method to more efficiently
handle the removal or archiving of nodes.

=cut

sub delete {
  my $self = shift;

  my $schema = $self->result_source->schema;
  my $ports = $self->search(undef, { columns => 'ip' });

  foreach my $set (qw/
    DevicePortPower
    DevicePortVlan
    DevicePortWireless
    DevicePortSsid
  /) {
      $schema->resultset($set)->search(
        { ip => { '-in' => $ports->as_query }},
      )->delete;
  }

  $schema->resultset('Node')->search(
    { switch => { '-in' => $ports->as_query }},
  )->delete(@_);

  # now let DBIC do its thing
  return $self->next::method();
}

1;
