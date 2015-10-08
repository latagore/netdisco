package App::Netdisco::Web::Plugin::Upload;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use App::Netdisco::Web::Plugin;
use Text::CSV;

my %CSV_MAP = (
  "Port" => "port",
  "Pigtail" => "cable",
  "Cable" => "jack",
  "Pairs 1" => "pairs1",
  "Pairs 2" => "pairs2",
  "Building" => "building",
  "Riser Room 1" => "riser1",
  "Riser Room 2" => "riser2",
  "Room" => "room",
  "Grid" => "grid",
  "Phone Extension" => "phoneext",
  "Comment" => "comment"
);

#map csv columns to DB primary key
my %DB_MAP = (
  "building" => 
  {
    "column" => "name",
    "resultclass" => "BuildingName",
    "constraints" => { "name_type" => "OFFICIAL" },
    "key_columns" => [ "campus", "num" ],
    "key_columns_as" => 
    { 
      "campus" => "building_campus",
      "num" => "building_num"
    }
  }
);

# get the DB primary key given some conditions
sub get_pkey {
  # TODO validate parameters
  my ($value, $column, $resultclass, $constraints, $key_columns) = @_;
  my $rs = schema('netdisco')->resultset($resultclass)->search(
    { $column => $value, %$constraints },
    { columns => $key_columns });
  return false if $rs->count != 1;
  return true, $rs->hri->single;
}

# allows uploading of port info data from CSV
post '/ajax/upload/ports' => require_role 'admin' => sub {
    my $device = schema('netdisco')->resultset('Device')
       ->search_for_device(param('device')) or send_error('Bad device', 400);
    my $ip = $device->ip;
    my @files = request->upload('file');
    send_error('Must send only one file') if scalar @files != 1;

    # TODO check HTTP header for content type
    my $file = $files[0]->file_handle;
    
    my $csv = Text::CSV->new ( { binary => 1 } );  # should set binary attribute.
    
    my $csv_header = $csv->getline($file);
    my $col_header;
    foreach my $col (@$csv_header){
      push @$col_header, ($CSV_MAP{$col} || "");
    }

    $csv->column_names (@$col_header);    
    my $data = $csv->getline_hr_all($file);
    # TODO validate that the CSV parses correctly
    
    # insert the data in the database
    schema('netdisco')->txn_do(sub {
      foreach my $datarow (@$data){
        my $result = schema('netdisco')->resultset('Portinfo')->find_or_new(
            {ip => $ip, port => $datarow->{port}});
            
        # save column data into result object
        foreach my $col (keys %$datarow){
          next unless $col
            and $col ne 'port';
          
          if ($DB_MAP{$col}){
            my $b = $DB_MAP{building};
            my ($success, $pkeycols) = get_pkey($datarow->{$col}, 
              $b->{column},
              $b->{resultclass},
              $b->{constraints},
              $b->{key_columns}
            );
            
            if ($success){
              foreach my $pkeycol (keys %$pkeycols){
                $result->set_column($b->{key_columns_as}->{$pkeycol}, $pkeycols->{$pkeycol});
              }
            } else {
              # TODO error
            }
          } else {
            $result->set_column($col, $datarow->{$col});
          }
          
        }
        $result->update_or_insert;
      }
    });
    # TODO print success status
    # log csv upload
};

1;
