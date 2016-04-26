package App::Netdisco::SSHCollector::Platform::FWSM;

=head1 NAME

App::Netdisco::SSHCollector::Platform::FWSM

=head1 DESCRIPTION

Collect ARP entries from firewall service module systems. ACEs have multiple
virtual contexts with individual ARP tables. Contexts are enumerated
with C<show context>, afterwards the commands C<changeto CONTEXTNAME> and
C<show arp> must be executed for every context.

The IOS shell does not permit to combine mulitple commands in a single
line, and Net::OpenSSH uses individual connections for individual commands,
so we need to use Expect to execute the changeto and show commands in
the same context.

=cut

use strict;
use warnings;

use Dancer ':script';
use Expect;
use Moo;

=head1 PUBLIC METHODS

=over 4

=item B<arpnip($host, $ssh)>

Retrieve ARP entries from device. C<$host> is the hostname or IP address
of the device. C<$ssh> is a Net::OpenSSH connection to the device.

Returns a list of hashrefs in the format C<{ mac => MACADDR, ip => IPADDR }>.

=cut

sub arpnip{
    my ($self, $hostlabel, $ssh, $args) = @_;

    debug "$hostlabel $$ arpnip()";

    my ($pty, $pid) = $ssh->open2pty or die "unable to run remote command";
    my $expect = Expect->init($pty);
    
    my ($pos, $error, $match, $before, $after);
    my $prompt;

    if ($args->{enable_password}) {
       $prompt = qr/>/;
       ($pos, $error, $match, $before, $after) = $expect->expect(10, -re, $prompt);

       $expect->send("enable\n");

       $prompt = qr/Password:/;
       ($pos, $error, $match, $before, $after) = $expect->expect(10, -re, $prompt);

       $expect->send( $args->{enable_password} ."\n" );
    }
    
    $prompt = qr/#/;
    ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);
    
    $expect->send("terminal pager 0\n");
    ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);

    $expect->send("change context sys\n");
    ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);
    
    # exclude lines with interfaces that wrap to the next line for the same context
    $expect->send("show context | exclude ^[ ][ ]\n");
    ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);
    
    my @ctx;
    my @arpentries;
    my $linereg = qr/[a-zA-Z0-9\-\.]+\s([a-zA-Z0-9\-\.]+)\s
      ([0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\.[0-9a-fA-F]{4})/x;

    # exclude first line with column headers
    # and last three lines with total number of contexts
    my @lines = split(/\n/, $before);
    @lines = @lines[1..scalar (@lines)-3];
    for (@lines){
        # check the line is actually a context
        if (m/(?:\s|\*)(\S+)/){
            push(@ctx, $1);
            $expect->send("change context $1\n");
            ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);
            $expect->send("show arp\n");
            ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);
            foreach my $line (split(/\n/, $before)){
                if ($line =~ $linereg) {
                    my ($ip, $mac) = ($1, $2);
                    push @arpentries, { mac => $mac, ip => $ip };
                }
            }

        }
    }

    $expect->send("exit\n");
    $expect->soft_close();

    return @arpentries;
}

1;
