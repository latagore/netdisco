package App::Netdisco::SSHCollector::Platform::Linux;

=head1 NAME

App::Netdisco::SSHCollector::Platform::Linux

=head1 DESCRIPTION

Collect ARP entries from Linux routers

This collector uses "C<arp>" as the command for the arp utility on your
system.  If you wish to specify an absolute path, then add an C<arp_command>
item to your configuration:

 sshcollector:
   - ip: '192.0.2.1'
     user: oliver
     password: letmein
     platform: Linux
     arp_command: '/usr/sbin/arp'

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

sub arpnip {
    my ($self, $hostlabel, $ssh, $args) = @_;

    debug "$hostlabel $$ arpnip()";

    my ($pty, $pid) = $ssh->open2pty or die "unable to run remote command";
    my $expect = Expect->init($pty);

    my ($pos, $error, $match, $before, $after);
    my $prompt = qr/\$/;

    ($pos, $error, $match, $before, $after) = $expect->expect(10, -re, $prompt);

    my $command = ($args->{arp_command} || 'arp');
    $expect->send("$command -n | tail -n +2\n");
    ($pos, $error, $match, $before, $after) = $expect->expect(5, -re, $prompt);

    my @arpentries = ();
    my @lines = split(m/\n/, $before);

    # 192.168.1.1 ether 00:b6:aa:f5:bb:6e C eth1
    my $linereg = qr/([0-9\.]+)\s+ether\s+([a-f0-9:]+)/;

    foreach my $line (@lines) {
        if ($line =~ $linereg) {
            my ($ip, $mac) = ($1, $2);
            push @arpentries, { mac => $mac, ip => $ip };
        }
    }

    $expect->send("exit\n");
    $expect->soft_close();

    return @arpentries;
}

1;
