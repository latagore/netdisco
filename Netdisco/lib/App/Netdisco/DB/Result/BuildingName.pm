use utf8;
package App::Netdisco::DB::Result::BuildingName;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::Netdisco::DB::Result::BuildingName

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<building_name>

=cut

__PACKAGE__->table("building_name");

=head1 ACCESSORS

=head2 campus

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 num

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 name_type

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "campus",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "num",
  { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "name_type",
  { data_type => "text", is_nullable => 0 },
);

__PACKAGE__->add_unique_constraint(
  "building_name_unique",
    ["campus", "num", "name", "name_type"],
    );

=head1 RELATIONS

=head2 building

Type: belongs_to

Related object: L<App::Netdisco::DB::Result::Building>

=cut

__PACKAGE__->belongs_to(
  "building",
  "App::Netdisco::DB::Result::Building",
  { campus => "campus", num => "num" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-09-14 12:21:56
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qnHwhwkNmIMvPtTXUVYIAQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
