use utf8;
package App::Netdisco::DB::Result::Building;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::Building

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<building>

=cut

__PACKAGE__->table("building");

=head1 ACCESSORS

=head2 campus

  data_type: 'text'
  is_nullable: 0

=head2 num

  data_type: 'text'
  is_nullable: 0

=head2 address

  data_type: 'text'
  is_nullable: 1

=head2 occup

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "campus",
  { data_type => "text", is_nullable => 0 },
  "num",
  { data_type => "text", is_nullable => 0 },
  "address",
  { data_type => "text", is_nullable => 1 },
  "occup",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</campus>

=item * L</num>

=back

=cut

__PACKAGE__->set_primary_key("campus", "num");

=head1 RELATIONS

=head2 building_names

Type: has_many

Related object: L<App::Netdisco::DB::Result::BuildingName>

=cut

__PACKAGE__->has_many(
  "building_names",
  "App::Netdisco::DB::Result::BuildingName",
  { "foreign.campus" => "self.campus", "foreign.num" => "self.num" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-14 12:21:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZAmprWYlmgQZmdpQ3pUbZg

=head2 official_name

Returns the official name for this Building, if any.

=cut

__PACKAGE__->might_have(
    official_name => 'App::Netdisco::DB::Result::BuildingName',
        {
          'foreign.campus' => 'self.campus',
          'foreign.num' => 'self.num',
        }, {
          where => { name_type => 'OFFICIAL' }
        }
);

=head2 short_name

Returns the short name for this Building, if any.

=cut

__PACKAGE__->might_have(
    short_name => 'App::Netdisco::DB::Result::BuildingName',
        {
          'foreign.campus' => 'self.campus',
          'foreign.num' => 'self.num',
        }, {
          where => { name_type => 'SHORT' }
        }
);

=head2 uit_name

Returns the short name for this Building, if any.

=cut

__PACKAGE__->might_have(
    short_name => 'App::Netdisco::DB::Result::BuildingName',
        {
          'foreign.campus' => 'self.campus',
          'foreign.num' => 'self.num',
        }, {
          where => { name_type => 'SHORT' }
        }
);

=head2 other_names

Returns the other names for this Building, if any.

=cut

__PACKAGE__->has_many(
    other_names => 'App::Netdisco::DB::Result::BuildingName',
        {
          'foreign.campus' => 'self.campus',
          'foreign.num' => 'self.num',
        }, {
          where => { name_type => 'OTHER' }
        }
);
        
1;
