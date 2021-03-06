package App::NetdiscoX::Web::Auth::Provider::YorkLDAP;

use strict;
use warnings;

use base 'Dancer::Plugin::Auth::Extensible::Provider::Base';

# with thanks to yanick's patch at
# https://github.com/bigpresh/Dancer-Plugin-Auth-Extensible/pull/24

use Dancer ':syntax';
use Dancer::Plugin::Passphrase;
use Digest::MD5;
use Net::LDAP;
use Net::LDAP::Util qw/escape_filter_value/;
use Try::Tiny;

my %roles_cache = ();

sub authenticate_user {
    my ($self, $username, $password) = @_;
    debug "using York LDAP authentication";
    return unless defined $username;
    return $self->authenticate_with_ldap($password, $username);
}

# implement barebones, no important passport york info needed
sub get_user_details {
    my ($self, $username) = @_;
    return $username;
}

# login on ldap server as $user, then login as netdisco
# to verify the $user has the appropriate role
sub authenticate_with_ldap {
    my($self, $pass, $user) = @_;

    return unless setting('ldap') and ref {} eq ref setting('ldap');
    my $conf = setting('ldap');

    my $ldapuser = $conf->{user_string};
    $ldapuser =~ s/\%USER\%?/$user/egi;

    # If we can bind as anonymous or proxy user,
    # search for user's distinguished name
    return unless $conf->{proxy_user};
    return unless $conf->{proxy_pass};
    my $u   = $conf->{proxy_user};
    my $p   = $conf->{proxy_pass};
    my $a  = ['distinguishedName'];
    my $r = _ldap_search($ldapuser, $a, $u, $p);
    my $ldapuserentry  = $r->[0] if ($r->[0]);
    
    foreach my $server (@{$conf->{servers}}) {
        debug "using ldap server $server";
        my $opts = $conf->{opts} || {};
        my $ldap = Net::LDAP->new($server, %$opts) or next;
        my $msg  = undef;
        if ($conf->{tls_opts} ) {
          $msg = $ldap->start_tls(%{$conf->{tls_opts}});
        }
        debug "start_tls returned ". $msg->error if $msg ne 'Success';
        # check that the user can authenticate with the given password
        $msg = $ldap->bind($ldapuserentry, password => $pass);
        debug "ldap server bind returned ".$msg->error;
        $ldap->unbind(); # take down session
        return undef if $msg->code();
        

        # try and look for the login flag in ldap
        $ldap = Net::LDAP->new($server, %$opts) or next;
        my $netdiscouser = $conf->{'proxy_user'};
        my $netdiscopass = $conf->{'proxy_pass'};

        my $results = _ldap_search($ldapuser, [], $netdiscouser, $netdiscopass);
        return undef unless scalar @$results == 1;
        my $entry = $results->[0];
        my $flags = $entry->get_value('pyAccessFlag', asref => 1) || [];
        # create a hash of flags for easy lookup
        my %flaghash = map { $_ => 1 } @$flags;
        return 1 if $flaghash{'NETDISCO_BASIC'};
    }

    return undef;
}

use Data::Dumper;
sub get_user_roles {
    my ($self, $username) = @_;
    return unless defined $username;
    
    # check the cache before querying the servers
    if ($roles_cache{$username}){
	my %user_roles_cache = %{$roles_cache{$username}};
        my $maxCacheTime = setting('max_ldap_cache_time') || 0; # number of minutes to cache
        my $timeDiff = (time - $user_roles_cache{"lastTime"}) % 60; # time difference in minutes
        return $user_roles_cache{"roles"} if $timeDiff < $maxCacheTime;
    }
    
    return unless setting('ldap') and ref {} eq ref setting('ldap');
    my $conf = setting('ldap');

    my $ldapuser = $conf->{user_string};
    $ldapuser =~ s/\%USER\%?/$username/egi;

    # login as netdisco on ldap server
    return unless $conf->{'proxy_user'};
    return unless $conf->{'proxy_pass'};
    my $netdiscouser = $conf->{'proxy_user'};
    my $netdiscopass = $conf->{'proxy_pass'};
    
    foreach my $server (@{$conf->{servers}}) {
        my $opts = $conf->{opts} || {};
        my $ldap = Net::LDAP->new($server, %$opts) or next;
        my $msg  = undef;
        if ($conf->{tls_opts} ) {
          $msg = $ldap->start_tls(%{$conf->{tls_opts}});
        }

        # try and look for the roles in ldap
        $ldap = Net::LDAP->new($server, %$opts) or next;

        my $results = _ldap_search($ldapuser, [], $netdiscouser, $netdiscopass);
        return undef unless $results and scalar @$results == 1;
        my $entry = $results->[0];
        my $flags = $entry->get_value('pyAccessFlag', asref => 1) || [];
        
        # create a hash of flags for easy lookup
        my %flaghash = map { $_ => 1 } @$flags;
        my $roles = [];
        # match york ldap flags to roles
        push @$roles, "port_control" if $flaghash{'NETDISCO_PORTCONTROL'};
        push @$roles, "admin" if $flaghash{'NETDISCO_ADMIN'};
        push @$roles, "ldap"; #indicate password can't be changed from netdisco because
                              # user is authenticated by remote ldap server
        
        # cache the results
        my %user_roles_cache = ();
        $user_roles_cache{"lastTime"} = time;
        $user_roles_cache{"roles"} = $roles;
        $roles_cache{$username} = \%user_roles_cache;

        return $roles if scalar @$roles;
    }
    
    return undef;
}

sub _ldap_search {
    my ($filter, $attrs, $user, $pass) = @_;
    my $conf = setting('ldap');

    return undef unless defined($filter);
    return undef if (defined $attrs and ref [] ne ref $attrs);

    foreach my $server (@{$conf->{servers}}) {
        my $opts = $conf->{opts} || {};
        my $ldap = Net::LDAP->new($server, %$opts) or next;
        my $msg  = undef;

        if ($conf->{tls_opts}) {
            $msg = $ldap->start_tls(%{$conf->{tls_opts}});
        }

        if ( $user and $user ne 'anonymous' ) {
            $msg = $ldap->bind($user, password => $pass);
        }
        else {
            $msg = $ldap->bind();
        }

        $msg = $ldap->search(
          base   => $conf->{base},
          filter => "($filter)",
          attrs  => $attrs,
        );

        $ldap->unbind(); # take down session

        my $entries = [$msg->entries];
        return $entries unless $msg->code();
    }

    return undef;
}

1;
