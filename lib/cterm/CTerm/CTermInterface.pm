#!/usr/bin/perl

package CTermInterface;

use strict;
use warnings;

use IPC::Open3;
use Time::HiRes;

$| = 1;

#PRIVAT#

local(*STD_IN, *STD_OUT, *STD_ERR);

my $readLine = sub {
	my ($self, $options) = @_;
	my $answer = <STD_OUT>;
	if (!defined($answer)) {
		die "$options->{err}: answer is empty" if (defined($options->{err}));
		die "answer is empty";
	}
	$answer =~ s/%09/\t/g;
	$answer =~ s/%0D/\r/g;
	$answer =~ s/%0A/\n/g;
	$answer =~ s/%20/ /g;
	$answer =~ s/%25/%/g;
	while (substr($answer, -2) eq "\r\n" || substr($answer, -1) eq "\n") { #remove new line characters (unix, windows)
		chop $answer if (substr($answer, -2) eq "\r\n");
		chop $answer;
	}
	return $answer;
};

my $writeLine = sub {
	my ($self, $command, $param) = @_;
	print STD_IN $command;
	if (defined($param) && length($param) != 0) {
		print STD_IN " " . $param;
	}
	print STD_IN "\n";
};


#PUBLIC#

sub new {
	my $class = shift;
	my $self = {
		options => shift, # required: cterm
		childpid => undef
	};
	bless $self, $class;
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'cterm' if (!defined($self->{options}->{cterm}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));

		$self->{options}->{cterm} =~ tr#\\#/#; $self->{childpid} = open3(\*STD_IN, \*STD_OUT, \*STD_ERR, $self->{options}->{cterm},"-i","-e");
		my $answer = $self->$readLine({err => "open3  $self->{options}->{cterm} -i -e"});
		die "answer is incorrect: $answer" if $answer ne "hello";
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $self;
	}
}


sub command {
	my ($self, $command, @params) = @_;
	my $sub = (caller(0))[3];
	
	my $answerStatus;
	my $answerValue;
	eval {
		my @undefined;
		push @undefined, 'command' if (!defined($command));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
		
		my $param = '"'.join('" "', @params).'"';
		$err = join(' ', $command, @params);
		$self->$writeLine($command, $param);
		my $answer = $self->$readLine({err => $err});
		if (substr($answer, 0, 2) eq "ok") {
			($answerStatus, $answerValue) = split(/\n/, $answer, 2);			
		} elsif (substr($answer, 0, 5) eq "error") {
			($answerStatus, $answerValue) = split(/ /, $answer, 2);
			if (defined($answerValue)) {
				die ($err = join(': ', $err, $answerValue));
			} else {
				die ($err = join(': ', $err, $answer));
			}
		} else {
			die "$err: answer is incorrect: $answer";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		if (defined($answerValue)) {
			return $answerValue
		} else {
			return $answerStatus;
		}
	}
}

sub sendCommand {
	my ($self, $ip, $port, $sendCommand, @params) = @_;
	my $sub = (caller(0))[3];
	
	my $answerStatus;
	my $answerValue;
	my $answerSend;
	my $answerForwardValue;
	eval {
		my @undefined;
		push @undefined, 'ip' if (!defined($ip));
		push @undefined, 'port' if (!defined($port));
		push @undefined, 'sendCommand' if (!defined($sendCommand));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
		
		my $command = "send $ip:$port $sendCommand";
		my $param = '"'.join('" "', @params).'"';
		$err = join(' ', $command, @params);
		$self->$writeLine($command, $param);
		my $answer  = $self->$readLine({err => $err});
		if (substr($answer, 0, 2) eq "ok") {
			($answerStatus, $answerValue) = split(/\n/, $answer, 2);
			die "$err: answer is incorrect: $answer" if (!defined($answerValue));
			($answerSend, $answerForwardValue) = split(/ /, $answerValue, 2);
			die "$err: answer is incorrect: $answer" if (!defined($answerForwardValue));
		} elsif (substr($answer, 0, 5) eq "error") {
			($answerStatus, $answerValue) = split(/ /, $answer, 2);
			if ($sendCommand ne "app.abort") {
				if (defined($answerValue)) {
					die ($err = join(': ', $err, $answerValue));
				} else {
					die ($err = join(': ', $err, $answer));
				}
			} else {
				return "ok" if (index($answer, "error 10054") != -1);
			}
		} else {
			die "$err: answer is incorrect: $answer";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		if (defined($answerForwardValue)) {
			return $answerForwardValue
		} else {
			return $answerStatus;
		}
	}
}

sub postCommand {
	my ($self, $ip, $port, $postCommand, @params) = @_;
	my $sub = (caller(0))[3];
	
	my $answerStatus;
	my $answerValue;
	my $answerSend;
	my $answerForwardValue;
	eval {
		my @undefined;
		push @undefined, 'ip' if (!defined($ip));
		push @undefined, 'port' if (!defined($port));
		push @undefined, 'postCommand' if (!defined($postCommand));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
		
		my $command = "post $ip:$port $postCommand";
		my $param = '"'.join('" "', @params).'"';
		$err = join(' ', $command, @params);
		$self->$writeLine($command, $param);
		my $answer  = $self->$readLine({err => $err});
		if (substr($answer, 0, 2) eq "ok") {
			($answerStatus, $answerValue) = split(/\n/, $answer, 2);
			die "$err: answer is incorrect: $answer" if (!defined($answerValue));
			($answerSend, $answerForwardValue) = split(/ /, $answerValue, 2);
			die "$err: answer is incorrect: $answer" if (!defined($answerForwardValue));
		} elsif (substr($answer, 0, 5) eq "error") {
			($answerStatus, $answerValue) = split(/ /, $answer, 2);
			if ($postCommand ne "app.abort") {
				if (defined($answerValue)) {
					die ($err = join(': ', $err, $answerValue));
				} else {
					die ($err = join(': ', $err, $answer));
				}
			} else {
				return "ok" if (index($answer, "error 10054") != -1);
			}
		} else {
			die "$err: answer is incorrect: $answer";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		if (defined($answerForwardValue)) {
			return $answerForwardValue
		} else {
			return $answerStatus;
		}
	}
}

sub ptestpid {
	my ($self, $pid, $timeout) = @_;
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'pid' if (!defined($pid));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
		
		if (!defined($timeout)) { $timeout = 10;	}
		$err=0;
		my $time = time;
		my $answer = $self->command("ptestpid", $pid);
		while ($answer ne "0") {
			if ((time-$time) > $timeout) {
				$self->command("pdelpid", $pid);
				$err=1;
				last;
			}	
			$answer = $self->command("ptestpid", $pid);	
		}
		$time = time;
		while ($answer ne "0") {	
			if ((time-$time) > $timeout) {
				die "timeout and pdelpid failed";
			}
			$answer = $self->command("ptestpid", $pid);
		}
		if($err ne "0") {
			die "timeout";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub ptestname {
	my ($self, $pname, $timeout) = @_;
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'pname' if (!defined($pname));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));

		if (!defined($timeout)) { $timeout = 10; }
		
		$err=0;
		my $time = time;
		my $answer = $self->command("ptestname", $pname);
		while ($answer ne "0") {
			if ((time-$time) > $timeout) {
				$self->command("pdelname", $pname);
				$err=1;
				last;
			}	
			$answer = $self->command("ptestname", $pname);	
		}
		$time = time;
		while ($answer ne "0") {	
			if ((time-$time) > $timeout) {
				die "timeout and pdelname failed";
			}
			$answer = $self->command("ptestname", $pname);
		}
		if($err ne "0") {
			die "timeout";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}


sub DESTROY {
	local($., $@, $!, $^E, $?);
	my ($self) = @_;
	my $sub = (caller(0))[3];
	
	eval {
		if (defined($self->{childpid})){
			$self->$writeLine("quit");
			my $answer;
			eval {
				$answer  = $self->$readLine({err => "quit"});
			};
			waitpid($self->{childpid}, 0);
			close(STD_IN);
			close(STD_OUT);
			close(STD_ERR);
			undef $self->{childpid};
			die "answer is empty" if (!defined($answer));
			die "answer is incorrect: $answer" if $answer ne "bye";
		}
	}; if ($@) {
		die "$sub error: $@";
	}
}

1;
