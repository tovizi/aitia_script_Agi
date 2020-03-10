#!/usr/bin/perl

package AppHandler;

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Spec;
use lib File::Spec->catdir(File::Basename::dirname(Cwd::abs_path __FILE__), "../../../cterm");

use JSON;

use CTerm::CTermInterface;

use List::MoreUtils qw(first_index);

use Time::HiRes qw( usleep );

$| = 1;


#PRIVAT#

my $connect = sub {
	my ($self, $options) = @_; #required: - ; optional: connect (flag) 
	
	if (defined($options->{connect})) {
		if ($options->{connect}) {
			my @required;
			push @required, "gateway" if (!defined($self->{options}->{gateway}));
			my $req = join(", ", @required);
			die "$req required" if (scalar(@required));
			
			usleep(100000);
			$self->{ctermInterface}->command("connect", ${$self->{gateway}}->{ip}, ${$self->{gateway}}->{port});
		}
	} else {
		if (defined(${$self->{gateway}}->{ip}) && defined(${$self->{gateway}}->{port})) {
			usleep(100000);
			$self->{ctermInterface}->command("connect", ${$self->{gateway}}->{ip}, ${$self->{gateway}}->{port});
		}
	}
};

my $disconnect = sub {
	my ($self, $options) = @_; #required: - ; optional: disconnect (flag) 
	
	
	if (defined($options->{disconnect})) {
		if ($options->{disconnect}) {
			usleep(100000);
			$self->{ctermInterface}->command("disconnect");
		}
	} else {
		if (defined(${$self->{gateway}}->{ip}) && defined(${$self->{gateway}}->{port})) {
			usleep(100000);
			$self->{ctermInterface}->command("disconnect");
		}
	}
};


#CONSTRUCTOR#

sub new {
	my $class = shift;
	my $self = {
		options => shift, #required: app, cterm ; optional: gateway
		app => undef,
		gateway => undef,
		ctermInterface => undef	
	};
	bless $self, $class;
	my $sub = (caller(0))[3];
	
	eval {
		my @required;
		push @required, "app" if (!defined($self->{options}->{app}));
		push @required, "app:name" if (!defined(${$self->{options}->{app}}->{name}));
		if (defined(${$self->{options}->{app}}->{gatewayName})) {
			if (!defined($self->{options}->{gateway})) {
				push @required, "gateway";
			} else {
				push @required, "gateway:ip" if (!defined(${$self->{options}->{gateway}}->{ip}));
				push @required, "gateway:port" if (!defined(${$self->{options}->{gateway}}->{port}));
			}
		}
		push @required, "cterm" if (!defined($self->{options}->{cterm}));
		my $req = join(", ", @required);		
		die "$req required" if (scalar(@required));
		
		$self->{app} = $self->{options}->{app};
		$self->{gateway} = $self->{options}->{gateway} if (defined($self->{options}->{gateway}));
		$self->{ctermInterface} = new CTermInterface({cterm => $self->{options}->{cterm}});
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $self;
	}
}


#PUBLIC#

sub sendAppCommand {
	my ($self, $options) = @_; #required: appCommand ; optional: appCommandParameters, connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $answer = 0;
	eval {
		my @required;
		push @required, "appCommand" if (!defined($options->{appCommand}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }
		eval {
			if (defined($options->{appCommandParameters})) {
				$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, $options->{appCommand}, @{$options->{appCommandParameters}});
			} else {
				$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, $options->{appCommand});
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

sub startApp {

	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {	
		my @required;
		push @required, "app:binApp" if (!defined(${$self->{app}}->{binApp}));
		push @required, "app:binPath" if (!defined(${$self->{app}}->{binPath}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			${$self->{app}}->{pid} = $self->{ctermInterface}->command("pcreate", ${$self->{app}}->{binPath}."/".${$self->{app}}->{binApp}, "-t", ${$self->{app}}->{port});
			my $pid = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.procid");
			if (${$self->{app}}->{pid} ne $pid) {
				$self->{ctermInterface}->command("pdelpid", ${$self->{app}}->{pid});
				$self->{ctermInterface}->command("ptestpid", ${$self->{app}}->{pid});
				die "another app (pid: $pid) is running on ${$self->{app}}->{port}";
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
		return "ok";
	}
}

sub stopApp {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			${$self->{app}}->{pid} = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.procid");
			$self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.abort");
			$self->{ctermInterface}->ptestpid(${$self->{app}}->{pid});
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}	
}

sub isAppAvailable {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $status = 0;
	eval {	
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.procid");
			$answer =~ s/^\s+|\s+$//g;
			$status = $answer;
		}; if ($@) { $status = 0; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return $status;
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

sub getAppProperties {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $properties;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.name");
			$properties->{name} = $answer;
			$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.description");
			$properties->{description} = $answer;
			$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.procid");
			$properties->{procid} = $answer;
			$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.version", "v");
			$properties->{version} = $answer;
			$answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.version", "b");
			$properties->{build} = $answer;
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return $properties;
	}
}

sub uploadAppBinElement {
	my ($self, $options) = @_; #required: localFilePath, localFileName ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, "localFilePath" if (!defined($options->{localFilePath}));
		push @required, "localFilePath" if (!defined($options->{localFileName}));
		push @required, "app:binPath" if (!defined(${$self->{app}}->{binPath}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			$self->{ctermInterface}->command("fput", "$options->{localFilePath}/$options->{localFileName}", "${$self->{app}}->{binPath}/$options->{localFileName}");
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub isAppBinElementEqual {
	my ($self, $options) = @_; #required: localFilePath, localFileName ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $status = 0;
	eval {		
		my @required;
		push @required, "localFilePath" if (!defined($options->{localFilePath}));
		push @required, "localFilePath" if (!defined($options->{localFileName}));
		push @required, "app:binPath" if (!defined(${$self->{app}}->{binPath}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		my $hashLocal = $self->{ctermInterface}->command("fhash", "$options->{localFilePath}/$options->{localFileName}");
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {			
			my $hashRemote = $self->{ctermInterface}->command("fhash", "${$self->{app}}->{binPath}/$options->{localFileName}");
			if ($hashLocal eq $hashRemote) {
				$status = 1;
			} else {
				$status = 0;
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
		return $status;
	}
}

sub downloadAppIni {
	my ($self, $options) = @_; #required: localFilePath, localFileName ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, "localFilePath" if (!defined($options->{localFilePath}));
		push @required, "localFilePath" if (!defined($options->{localFileName}));
		push @required, "app:binPath" if (!defined(${$self->{app}}->{binPath}));
		push @required, "app:binApp" if (!defined(${$self->{app}}->{binApp}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {
			my $ini = substr(basename(${$self->{app}}->{binApp}), 0, rindex(basename(${$self->{app}}->{binApp}), '.')).".ini";
			$self->{ctermInterface}->command("fget", "${$self->{app}}->{binPath}/$ini", "$options->{localFilePath}/$options->{localFileName}");
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}


sub clearCounters {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "counters.clear");
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub saveCounters {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }					
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "counters.save");
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub getCounter {
	my ($self, $options) = @_; #required: counterPath, counterType ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $counter;
	eval {		
		my @required;
		push @required, 'counterPath' if (!defined($options->{counterPath}));
		push @required, 'counterType' if (!defined($options->{counterType}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			my $answer = decode_json($self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "counters.get", $options->{counterPath}, "87"));
			die "$options->{counterPath}:$options->{counterType} required" if (!defined($answer->{$options->{counterType}}));
			##### type:double #####
			$answer->{$options->{counterType}} = sprintf("%.2f", $answer->{$options->{counterType}}) if ($answer->{type} eq "double");
			$counter->{value} = $answer->{$options->{counterType}};
			$counter->{unit} = $answer->{unit} if ($options->{counterType} eq "value" && defined($answer->{unit}));
			$counter->{unit} = $answer->{unit}."*"."(".$answer->{speedeval}."/".$answer->{speedunit}.")" if ($options->{counterType} eq "speed" && defined($answer->{unit}) && defined($answer->{speedeval}) && defined($answer->{speedunit}));
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return $counter;
	}
}

sub getCounters {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my @counters;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {			
			my $answer = decode_json($self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "counters.get", "/", "87"));
			@counters = @{$answer->{groups}};
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return @counters;
	}
}


sub clearState {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {	
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "state.clear");
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub deleteState {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'app:statePath' if (!defined(${$self->{app}}->{statePath}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			$self->{ctermInterface}->command("fdelete", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub flushState {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {	
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "state.flush");
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub loadState {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'app:statePath' if (!defined(${$self->{app}}->{statePath}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			##### TODO: statefile existence checking change to ffind if ffind works #####
			eval {
				$self->{ctermInterface}->command("fcreate", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
				$self->{ctermInterface}->command("fdelete", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
			}; if ($@) { } else {
				die "Not found ${$self->{app}}->{statePath}/${$self->{app}}->{name}.state";
			}
			##### TODO: statefile existence checking change to ffind if ffind works #####
			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "state.load", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
			##### TODO: error checking #####
			print "$answer\n";
			$self->{ctermInterface}->command("fdelete", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub saveState {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'app:statePath' if (!defined(${$self->{app}}->{statePath}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "state.save", ${$self->{app}}->{statePath}."/".${$self->{app}}->{name}.".state");
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}


sub startProc {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.startproc");
			##### TODO: error checking #####
			print "$answer\n";
			die "ProcState is still inactive" if (!$self->isProcActivated({connect => 0, disconnect => 0}));
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}	
}

sub stopProc {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.stopproc");
			##### TODO: error checking #####
			print "$answer\n";
			die "ProcState is still active" if ($self->isProcActivated({connect => 0, disconnect => 0}));
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub isProcActivated {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $status = 0;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }					
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "app.getProcState");
			$answer =~ s/^\s+|\s+$//g;
			if($answer eq "active") {
				$status = 1;
			} elsif ($answer eq "inactive") {
				$status = 0;
			} else {
				die "unexpected processing state: $answer"
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
		return $status;
	}
}


sub compareConfig {
	my ($self, $options) = @_; #required: config, configRef ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $result;
	eval {		
		my @required;
		push @required, "config" if (!defined($options->{config}));
		push @required, "configRef" if (!defined($options->{configRef}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
			
		foreach my $section (@{${$options->{config}}}) {
			my $sectionIndex = first_index { $_->{Section} eq "$section->{Section}" } @{${$options->{configRef}}};
			if ($sectionIndex != -1) {
				foreach my $parameter (@{$section->{Parameters}}) {
					my $parameterIndex = first_index { $_->{Parameter} eq "$parameter->{Parameter}" } @{${$options->{configRef}}->[$sectionIndex]->{Parameters}};
					if ($parameterIndex != -1) {
						if (${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value} ne $parameter->{Value} && ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description} ne $parameter->{Description}) {
							my $tmp->{Section} = $section->{Section};
							$tmp->{SectionDescription} = $section->{Description};
							$tmp->{Parameter} = $parameter->{Parameter};
							$tmp->{ParameterDescription} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description};
							$tmp->{NewParameterDescription} = $parameter->{Description};
							$tmp->{Value} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value};
							$tmp->{NewValue} = $parameter->{Value};
							push @{$result->{modifiedParameters}}, $tmp;
						}
						if (${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value} ne $parameter->{Value} && ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description} eq $parameter->{Description}) {
							my $tmp->{Section} = $section->{Section};
							$tmp->{SectionDescription} = $section->{Description};
							$tmp->{Parameter} = $parameter->{Parameter};
							$tmp->{ParameterDescription} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description};
							$tmp->{Value} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value};
							$tmp->{NewValue} = $parameter->{Value};
							push @{$result->{modifiedParameters}}, $tmp;
						}
						if (${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value} eq $parameter->{Value} && ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description} ne $parameter->{Description}) {
							my $tmp->{Section} = $section->{Section};
							$tmp->{SectionDescription} = $section->{Description};
							$tmp->{Parameter} = $parameter->{Parameter};
							$tmp->{ParameterDescription} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Description};
							$tmp->{NewParameterDescription} = $parameter->{Description};
							$tmp->{Value} = ${$options->{configRef}}->[$sectionIndex]->{Parameters}->[$parameterIndex]->{Value};							
							push @{$result->{modifiedParameters}}, $tmp;							
						}
					} else {
						my $tmp->{Section} = $section->{Section};
						$tmp->{SectionDescription} = $section->{Description};
						$tmp->{Parameter} = $parameter->{Parameter};
						$tmp->{ParameterDescription} = $parameter->{Description};
						$tmp->{Value} = $parameter->{Value};
						push @{$result->{addedParameters}}, $tmp;
					}
				}
				foreach my $parameter (@{${$options->{configRef}}->[$sectionIndex]->{Parameters}}) {
					my $parameterIndex = first_index { $_->{Parameter} eq "$parameter->{Parameter}" } @{$section->{Parameters}};
					if ($parameterIndex == -1) {
						my $tmp->{Section} = $section->{Section};
						$tmp->{SectionDescription} = $section->{Description};
						$tmp->{Parameter} = $parameter->{Parameter};
						$tmp->{ParameterDescription} = $parameter->{Description};
						$tmp->{Value} = $parameter->{Value};
						push @{$result->{removedParameters}}, $tmp;
					}
				}
			} else {
				my $tmp->{Section} = $section->{Section};
				$tmp->{SectionDescription} = $section->{Description};
				foreach my $parameter (@{$section->{Parameters}}) {
					push @{$tmp->{Parameters}}, $parameter;
				}
				push @{$result->{addedSections}}, $tmp;
			}
		}
		foreach my $section (@{${$options->{configRef}}}) {
			my $sectionIndex = first_index { $_->{Section} eq "$section->{Section}" } @{${$options->{config}}};
			if ($sectionIndex == -1) {
				my $tmp->{Section} = $section->{Section};
				$tmp->{SectionDescription} = $section->{Description};
				foreach my $parameter (@{$section->{Parameters}}) {
					push @{$tmp->{Parameters}}, $parameter;
				}
				push @{$result->{removedSections}}, $tmp;
			}
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $result;
	}
}


sub setConfig {
	my ($self, $options) = @_; #required: iniSection, iniParameter, iniParameterValue ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'iniSection' if (!defined($options->{iniSection}));
		push @required, 'iniParameter' if (!defined($options->{iniParameter}));
		push @required, 'iniParameterValue' if (!defined($options->{iniParameterValue}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "config.set", $options->{iniSection}, $options->{iniParameter}, $options->{iniParameterValue});
			##### TODO: error checking #####
			print "$answer\n";		
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}


sub closeConnection {
	my ($self, $options) = @_; #required: - ,connectionDirection, connectionID ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'connectionDirection' if (!defined($options->{connectionDirection}));
		push @required, 'connectionID' if (!defined($options->{connectionID}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "connections.close", $options->{connectionDirection}, $options->{connectionID});
			##### TODO: error checking #####
			print "$answer\n";
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub openConnection {
	my ($self, $options) = @_; #required: connectionDirection, connectionUri ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'connectionDirection' if (!defined($options->{connectionDirection}));
		push @required, 'connectionUri' if (!defined($options->{connectionUri}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {
			my $answer = $self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "connections.open", $options->{connectionDirection}, $options->{connectionUri});
			##### TODO: error checking #####
			print "$answer\n";		
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub reconnectConnection {
	my ($self, $options) = @_; #required: connectionDirection, connectionUri, connectionID ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {		
		my @required;
		push @required, 'connectionDirection' if (!defined($options->{connectionDirection}));
		push @required, 'connectionUri' if (!defined($options->{connectionUri}));
		push @required, 'connectionID' if (!defined($options->{connectionID}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));

		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			$self->closeConnection({connectionDirection => $options->{connectionDirection}, connectionID => $options->{connectionID}, connect => 0 , disconnect => 0})	;
			$self->openConnection({connectionDirection => $options->{connectionDirection}, connectionUri => $options->{connectionUri}, connect => 0 , disconnect => 0});
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub getConnectionStatus {
	my ($self, $options) = @_; #required: connectionID ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my $connectionStatus;
	eval {
		my @required;
		push @required, 'connectionID' if (!defined($options->{connectionID}));
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));	
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {
			my $answer = @ {decode_json($self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "connections.info", $options->{connectionID}))->{channels}}[0]->{state};
			if ($answer ne "Opening" && $answer ne "Closed") {
				$connectionStatus = $answer;
			} else {
				eval {
					local $SIG{ALRM} = sub { die "TimeOut"; };
					alarm(1);
					while($answer eq "Opening" || $answer eq "Closed") {
						$answer = @ {decode_json($self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "connections.info", $options->{connectionID}))->{channels}}[0]->{state};
					}
					alarm(0);
				}; if ($@) {
					if (index($@, "TimeOut") != -1) {
						$connectionStatus = $answer;
					} else {
						die $@;
					}
				}
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
		return $connectionStatus;
	}
}

sub checkConnectionsStatus {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my %failedConnections;
	eval {		
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
	
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }			
		eval {			
			my @connections = $self->getConnectionListFromApp({connect => 0, disconnect => 0});
			foreach my $connection (@connections) {
				my $answer = $self->getConnectionStatus({connectionID => $connection, connect => 0, disconnect => 0});
				$failedConnections{$connection} = $answer if ($answer ne "Opened" && $answer ne "Active");		
			}	
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
		die join(", ", map { "$_ status is $failedConnections{$_}" } keys %failedConnections) if (keys %failedConnections);
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return "ok";
	}
}

sub getConnectionListFromApp {
	my ($self, $options) = @_; #required: - ; optional: connectionDirection, connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	my @connections;
	eval {
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connectionDirection})) {
			die "$options->{connectionDirection} required" if ($options->{connectionDirection} ne "in" && $options->{connectionDirection} ne "out" && $options->{connectionDirection} ne "-");
		} else {
			$options->{connectionDirection} = "-"
		}
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }				
		eval {			
			@connections = @ {decode_json($self->{ctermInterface}->sendCommand("127.0.0.1", ${$self->{app}}->{port}, "connections.list", $options->{connectionDirection}))->{channels}};
		}; if ($@) { $err = $@; }
		if (defined($options->{disconnect})) {
			$self->$disconnect({disconnect => $options->{disconnect}});
		} else { $self->$disconnect; }
	}; if ($@ || defined($err)) {
		if (defined($err)) {
			die "$sub error: $err $@";
		} else { die "$sub error: $@"; }
	} else {
		return @connections;
	}
}

sub getConnectionListFromConfig {
	my ($self, $options) = @_; #required: - ; optional: connectionDirection
	my $sub = (caller(0))[3];
	
	my $err;
	my @connections;
	eval {		
		if (defined($options->{connectionDirection})) {
			die "$options->{connectionDirection} required" if ($options->{connectionDirection} ne "in" && $options->{connectionDirection} ne "out" && $options->{connectionDirection} ne "-");
		} else {
			$options->{connectionDirection} = "-"
		}
			
		eval {
			foreach my $section (@{${$self->{app}}->{config}}) {
				if ($section->{Section} eq "Input") {
					if ($options->{connectionDirection} eq "-" || $options->{connectionDirection} eq "in") {
						foreach my $parameter (@{$section->{Parameters}}) {
							if (!($parameter->{Parameter} =~ /^(RestoreChannels|SortingQueueDelay|SortingQueueLength|StoragePointerFilePath|SynchronizedIO)$/)) {
								push @connections, $parameter->{Parameter};
							}
						}
					}
				} elsif ($section->{Section} eq "Output") {
					if ($options->{connectionDirection} eq "-" || $options->{connectionDirection} eq "out") {
						foreach my $parameter (@{$section->{Parameters}}) {
							if (!($parameter->{Parameter} =~ /^(RestoreChannels|SortingQueueDelay|SortingQueueLength)$/)) {
								push @connections, $parameter->{Parameter};
							}
						}
					}
				}
			}			
		}; if ($@) { $err = $@; }
	}; if ($@ || defined($err)) {
		die "$sub error: $@";
	} else {
		return @connections;
	}
}

sub getConnectionUriFromConfig {
	my ($self, $options) = @_; #required: connectionID ; optional: -
	my $sub = (caller(0))[3];
	
	my $err;
	my $connectionUri;
	eval {		
		my @required;
		push @required, 'connectionID' if (!defined($options->{connectionID}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
			
		eval {
			foreach my $section (@{${$self->{app}}->{config}}) {
				if ($section->{Section} eq "Input") {
					foreach my $parameter (@{$section->{Parameters}}) {
						if (!($parameter->{Parameter} =~ /^(RestoreChannels|SortingQueueDelay|SortingQueueLength|StoragePointerFilePath|SynchronizedIO)$/)) {
							if ($parameter->{Parameter} eq $options->{connectionID}) {
								$connectionUri = $parameter->{Value};
							}
						}
					}
				} elsif ($section->{Section} eq "Output") {
					foreach my $parameter (@{$section->{Parameters}}) {
						if (!($parameter->{Parameter} =~ /^(RestoreChannels|SortingQueueDelay|SortingQueueLength)$/)) {
							if ($parameter->{Parameter} eq $options->{connectionID}) {
								$connectionUri = $parameter->{Value};
							}
						}
					}
				}
			}
			die "$options->{connectionID} required" if (!defined($connectionUri));
		}; if ($@) { $err = $@; }
	}; if ($@ || defined($err)) {
		die "$sub error: $@";
	} else {
		return $connectionUri;
	}
}

sub reconnectConnections {
	my ($self, $options) = @_; #required: - ; optional: connect (flag), disconnect (flag)
	my $sub = (caller(0))[3];
	
	my $err;
	eval {	
		my @required;
		push @required, "app:port" if (!defined(${$self->{app}}->{port}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		if (defined($options->{connect})) {
			$self->$connect({connect => $options->{connect}});
		} else { $self->$connect; }		
		eval {			
			my @outConnections = $self->getConnectionListFromConfig({connectionDirection => "out"});
			my @outLiveConnections = $self->getConnectionListFromApp({connectionDirection => "out", connect => 0, disconnect => 0});
			
			die "connections are different" if (scalar(@outConnections) != scalar(@outLiveConnections));
			my %outConnectionsHash = map { $_ => 1 } @outConnections;
			for my $out (@outLiveConnections) {
				die "connections are different" if(!exists($outConnectionsHash{$out}));
			}
			
			my @inConnections = $self->getConnectionListFromConfig({connectionDirection => "in"});
			my @inLiveConnections = $self->getConnectionListFromApp({connectionDirection => "in", connect => 0, disconnect => 0});
			die "connections are different" if (scalar(@inConnections) != scalar(@inLiveConnections));
			
			foreach my $inConnection (@outConnections) {
				$self->reconnectConnection({connectionDirection => "out", connectionUri => $self->getConnectionUriFromConfig({connectionID => $inConnection}), connectionID => $inConnection, connect => 0, disconnect => 0});
			}
			foreach my $inConnection (@inConnections) {
				$self->reconnectConnection({connectionDirection => "in", connectionUri => $self->getConnectionUriFromConfig({connectionID => $inConnection}), connectionID => $inConnection, connect => 0, disconnect => 0});
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
		return "ok";
	}
}


sub DESTROY {
	local($., $@, $!, $^E, $?);
	my ($self) = @_;
	my $sub = (caller(0))[3];
	
	$self->{ctermInterface}->DESTROY;
}

1;
