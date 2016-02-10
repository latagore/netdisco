package App::Netdisco::Web::Plugin::Upload;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Auth::Extensible;

use Try::Tiny;
use App::Netdisco::Web::Plugin;
use Text::CSV;

my %CSV_MAP = (
  "Port ID" => "port",
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
    
    # user messages for warnings and errors
    my @warnings = ();
    my @errors = ();
    content_type 'application/json';
    
    # validation
    push @errors, 'Must send only one file' if scalar @files != 1;
    push @errors, "Wrong file type." # check HTTP header for content type
      unless $files[0]->headers->{"Content-Type"} eq "text/comma-separated-values"
          or $files[0]->headers->{"Content-Type"} eq "text/csv"
          or $files[0]->headers->{"Content-Type"} eq "application/vnd.ms-excel";
          
    status 400 if scalar @errors;
    return to_json( { errors => \@errors } ) if scalar @errors;
    
    # read the file
    my $file = $files[0]->file_handle;
    my $csv = Text::CSV->new ( { binary => 1 } );  # should set binary attribute.
    my $csv_header = $csv->getline($file);
    my $col_header;
    foreach my $col (@$csv_header){
      push @$col_header, ($CSV_MAP{$col} || "");
      push @warnings, "'$col' is not a cable data column. Ignoring."
          unless $CSV_MAP{$col};
    }
    $csv->column_names (@$col_header);
    my $data = $csv->getline_hr_all($file);
    
    # insert the data in the database
    schema('netdisco')->txn_do(sub {
      schema('netdisco')->resultset('UserLog')->create({
        username => session('logged_in_user'),
        userip => request->remote_address,
        event => "Cable Data CSV Upload",
        details => $ip,
      });
      
      # keep track of the line number for error reporting
      my $linenumber = 1;
      DATA: foreach my $datarow (@$data){
        $linenumber++;
        unless (schema('netdisco')->resultset('DevicePort')
          ->find({ip => $ip, port => $datarow->{port}}))
        {
          push @warnings,  "'".$datarow->{port}."' is not a port on the device. Ignoring.";
          next DATA;
        } 
        my $result = schema('netdisco')->resultset('Portinfo')->find_or_new(
            {ip => $ip, port => $datarow->{port}});
            
        # save column data into result object
        foreach my $col (keys %$datarow){
          next unless $col
            and $col ne 'port';
          
          if ($DB_MAP{$col}){
            # skip if value is blank or null, no point looking up
            next unless defined $datarow->{$col} and $datarow->{$col} ne '';
            my $b = $DB_MAP{$col};
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
              push @errors, "Failed to get $col \"$datarow->{$col}\" for line $linenumber";
              last DATA;
            }
          } else {
            $result->set_column($col, $datarow->{$col});
          }
          
        }
        try {
          $result->update_or_insert;
        } catch {
          push @errors, "Failed to update or insert line $linenumber: ".$_;
          last DATA;
        }
      }
    });

    status 400 if scalar @errors;
    return to_json(
        {   errors      => \@errors,
            warnings    => \@warnings,
        }
    );    
};

1;
