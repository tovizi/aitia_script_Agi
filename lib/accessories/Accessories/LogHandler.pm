#!/usr/bin/perl

package LogHandler;

use strict;
use warnings;

use Time::Piece;
use Win32::Console::ANSI;
use Term::ANSIColor;

$| = 1;

sub new {
	my $class = shift;
	my $self = {
		options => shift #required: - ; optional: logFile, timeStamp (flag), textColour, newLinesBeforeText, newLinesAfterText
		#logFile:
		# - log file name without extension and with path
		#
		#timeStamp (flag):
		# - 0: write log without timestamp
		# - 1 (default): write log with timestamp
		#
		#textColour:
		# - foreground (normal) colours: black  red  green  yellow  blue  magenta  cyan  white
		# - foreground (bright) colours: bright_black  bright_red  bright_green  bright_yellow  bright_blue  bright_magenta  bright_cyan  bright_white
		# - background (normal) colours: on_black  on_red  on_green  on yellow  on_blue  on_magenta  on_cyan  on_white
		# - background (bright) colours: on_bright_black  on_bright_red  on_bright_green  on_bright_yellow  on_bright_blue  on_bright_magenta  on_bright_cyan  on_bright_white
		#
		#newLinesBeforeText:
		# - count of the new line symbol before log text, the default is 0
		#
		#newLinesAfterText:
		# - count of the new line symbol after log text, the default is 1
	};
	bless $self, $class;
	my $sub = (caller(0))[3];
	
	eval {
		#set default values
		$self->{options}->{timeStamp} = 0 if (!defined($self->{options}->{timeStamp}));
		$self->{options}->{newLinesBeforeText} = 0 if (!defined($self->{options}->{newLinesBeforeText}));
		$self->{options}->{newLinesAfterText} = 1 if (!defined($self->{options}->{newLinesAfterText}));
		
		if (defined($self->{options}->{logFile})) {
			$self->{options}->{logFile} =~ tr#\\#/#;
			my $date = localtime->strftime('%Y%m%d');		
			open(my $F, '>>', "$self->{options}->{logFile}_$date.log") or die "can't open $self->{options}->{logFile}_$date.log";
			close $F;
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $self;
	}
}


sub setLogFile {
	my ($self, $options) = @_; #required: logFile
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'logFile' if (!defined($options->{logFile}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		$options->{logFile} =~ tr#\\#/#;
		my $date = localtime->strftime('%Y%m%d');		
		open(my $F, '>>', "$options->{logFile}_$date.log") or die "can't open $options->{logFile}_$date.log";
		close $F;
		
		$self->{options}->{logFile} = $options->{logFile};
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub setTimeStamp {
	my ($self, $options) = @_; #required: timeStamp
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'timeStamp' if (!defined($options->{timeStamp}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		$self->{options}->{timeStamp} = $options->{timeStamp};
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub setTextColour {
	my ($self, $options) = @_; #required: textColour
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'textColour' if (!defined($options->{textColour}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		$self->{options}->{textColour} = $options->{textColour};
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub setNewLinesBeforeText {
	my ($self, $options) = @_; #required: newLinesBeforeText
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'newLinesBeforeText' if (!defined($options->{newLinesBeforeText}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		$self->{options}->{newLinesBeforeText} = $options->{newLinesBeforeText};
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub setNewLinesAfterText {
	my ($self, $options) = @_; #required: newLinesAfterText
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'newLinesAfterText' if (!defined($options->{newLinesAfterText}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		$self->{options}->{newLinesAfterText} = $options->{newLinesAfterText};
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}


sub writeLog {
	my ($self, $options) = @_; #required: text ; optional: logFile, timeStamp (flag), textColour, newLinesBeforeText, newLinesAfterText
	my $sub = (caller(0))[3];
	
	eval {
		my @undefined;
		push @undefined, 'text' if (!defined($options->{text}));
		my $err = join(', ', @undefined);
		die "$err undefined" if (scalar(@undefined));
	
		my $logFile;
		$logFile = $self->{options}->{logFile} if (defined($self->{options}->{logFile}));
		$logFile = $options->{logFile} if (defined($options->{logFile}));
		my $timeStamp = $self->{options}->{timeStamp};
		$timeStamp = $options->{timeStamp} if (defined($options->{timeStamp}));
		my $time = "";
		$time = localtime->hms if ($timeStamp);
		my $textColour;
		$textColour = $self->{options}->{textColour} if (defined($self->{options}->{textColour}));
		$textColour = $options->{textColour} if (defined($options->{textColour}));
		my $newLinesBeforeText = $self->{options}->{newLinesBeforeText};
		$newLinesBeforeText = $options->{newLinesBeforeText} if (defined($options->{newLinesBeforeText}));
		my $newLinesAfterText = $self->{options}->{newLinesAfterText};
		$newLinesAfterText = $options->{newLinesAfterText} if (defined($options->{newLinesAfterText}));
		
		# log into logFile
		if (defined($logFile)) {
			my $date = localtime->strftime('%Y%m%d');	
			open(my $F, '>>', "${logFile}_$date.log") or die "can't open ${logFile}_$date.log";
			for (my $i=0; $i < $newLinesBeforeText; $i++) {
				print $F "\n";
			}
			print $F "$time $options->{text}";
			for (my $i=0; $i < $newLinesAfterText; $i++) {
				print $F "\n";
			}
			close $F;
		}
		
		#log into console
		for (my $i=0; $i < $newLinesBeforeText; $i++) {
			print "\n";
		}
		if (defined($textColour)) {
			print colored ("$time $options->{text}", $textColour);
		}
		else {
			print "$time $options->{text}";
		}	
		for (my $i=0; $i < $newLinesAfterText; $i++) {
			print "\n";
		}
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub writeNewLine {
	my ($self, $options) = @_; #required: - ; optional: logFile
	my $sub = (caller(0))[3];
	
	eval {	
		my $logFile;
		$logFile = $self->{options}->{logFile} if (defined($self->{options}->{logFile}));
		$logFile = $options->{logFile} if (defined($options->{logFile}));
		
		# log into logFile
		if (defined($logFile)) {
			my $date = localtime->strftime('%Y%m%d');	
			open(my $F, '>>', "${logFile}_$date.log") or die "can't open ${logFile}_$date.log";
			print $F "\n";
			close $F;
		}
		
		#log into console
		print "\n";
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
}

1;
