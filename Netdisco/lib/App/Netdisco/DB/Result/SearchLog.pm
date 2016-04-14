use utf8;
package App::Netdisco::DB::Result::SearchLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::SearchLog - Records history of various searches from the web interface.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<search_log>

=cut

__PACKAGE__->table("search_log");

=head1 ACCESSORS

=head2 search_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'search_log_search_id_seq'

=head2 time

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 session_id

  data_type: 'numeric'
  is_nullable: 1

=head2 uri

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "search_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "search_log_search_id_seq",
  },
  "time",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "session_id",
  { data_type => "numeric", is_nullable => 1 },
  "uri",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</search_id>

=back

=cut

__PACKAGE__->set_primary_key("search_id");


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2016-04-14 10:57:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M+algmnHkE1h9hvbKgXTkQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
