#!/usr/bin/perl

package GatewayHandler;

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Spec;
use lib File::Spec->catdir(File::Basename::dirname(Cwd::abs_path __FILE__), "../../../cterm");

use JSON;

use CTerm::CTermInterface;

$| = 1;


#PRIVAT#

my $connect = sub {
	my ($self, $options) = @_; #required: - ; optional: connect (flag) 
	
	if (defined($options->{connect})) {
		if ($options->{connect}) {
			my @required;
			push @required, "gateway:ip" if (!defined(${$self->{gateway}}->{ip}));
			push @required, "gateway:port" if (!defined(${$self->{gateway}}->{port}));
			my $req = join(", ", @required);
			die "$req required" if (scalar(@required));
			
			$self->{ctermInterface}->command("connect", ${$self->{gateway}}->{ip}, ${$self->{gateway}}->{port});
		}
	} else {
		$self->{ctermInterface}->command("connect", ${$self->{gateway}}->{ip}, ${$self->{gateway}}->{port}) if (defined(${$self->{gateway}}->{ip} && ${$self->{gateway}}->{port}));
	}
};

my $disconnect = sub {
	my ($self, $options) = @_; #required: - ; optional: disconnect (flag) 
	
	if (defined($options->{disconnect})) {
		if ($options->{disconnect}) {
			$self->{ctermInterface}->command("disconnect");
		}
	} else {
		$self->{ctermInterface}->command("disconnect") if (defined(${$self->{gateway}}->{ip} && ${$self->{gateway}}->{port}));
	}
};


#CONSTRUCTOR#

sub new {
	my $class = shift;
	my $self = {
		options => shift, #required: gateway, cterm ; optional: -
		gateway => undef,
		ctermInterface => undef	
	};
	bless $self, $class;
	my $sub = (caller(0))[3];
	
	eval {
		my @required;
		push @required, "gateway" if (!defined($self->{options}->{gateway}));
		push @required, "cterm" if (!defined($self->{options}->{cterm}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		$self->{gateway} = $self->{options}->{gateway};
		$self->{ctermInterface} = new CTermInterface({cterm => $self->{options}->{cterm}});
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $self;
	}
}


#PUBLIC#

sub sendGatewayCommand {
	my ($self, $options) = @_; #required: gatewayCommand ; optional: gatewayCommandParameters, connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $answer = 0;
	eval {
		my @required;
		push @required, "gatewayCommand" if (!defined($options->{gatewayCommand}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }
		eval {
			if (defined($options->{gatewayCommandParameters})) {
				$answer = $self->{ctermInterface}->command($options->{gatewayCommand}, @{$options->{gatewayCommandParameters}});
			} else {
				$answer = $self->{ctermInterface}->command($options->{gatewayCommand});
			}
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return $answer;
	}
}

sub isGatewayAvailable {
	my ($self, $options) = @_; #required: - ; optional: -
	my $sub = (caller(0))[3];
	
	my $status = 0;
	eval {						
		eval {
			$self->$connect;
			$self->$disconnect;
			$status = 1;
		}; if ($@) { $status = 0; }
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $status;
	}
}


sub DESTROY {
	local($., $@, $!, $^E, $?);
	my ($self) = @_;
	my $sub = (caller(0))[3];
	
	$self->{ctermInterface}->DESTROY;
}

1;
