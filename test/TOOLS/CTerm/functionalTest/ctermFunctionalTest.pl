#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;

use lib dirname (__FILE__) . '/../../../../lib/cterm';
use CTerm;
use lib dirname (__FILE__) . '/../../../../lib/accessories';
use Accessories::LogHandler;

use Time::Piece;
use File::Path;

use Getopt::Long;
use Pod::Usage;

use IPC::Open3;

$| = 1;


#########################
#Script environment
#########################

# status = 0 SUCCESS
# status = 1 ERROR
# status = 2 FAILURE
# status = 3 UNSTABLE
my $status = 1;

my $dispatchTable = {
	#még nincs implementálva/hibás a cterm-ben
	#'dcopy.base.local'  => sub { return dcopy({subFunction => 'base', subType => 'local'}) }, 
	#'dcopy.base.remote'  => sub { return dcopy({subFunction => 'base', subType => 'remote'}) }, 

	'dcreate.base.local'  => sub { return dcreate({subFunction => 'base', subType => 'local'}) }, #ok
	'dcreate.base.remote'  => sub { return dcreate({subFunction => 'base', subType => 'remote'}) }, #ok
	'dcreate.basePath.local'  => sub { return dcreate({subFunction => 'basePath', subType => 'local'}) }, #ok
	'dcreate.basePath.remote'  => sub { return dcreate({subFunction => 'basePath', subType => 'remote'}) }, #ok
	'dcreate.existingDir.local'  => sub { return dcreate({subFunction => 'existingDir', subType => 'local'}) }, #ok
	'dcreate.existingDir.remote'  => sub { return dcreate({subFunction => 'existingDir', subType => 'remote'}) }, #ok
	'dcreate.invalidParameter.local'  => sub { return dcreate({subFunction => 'invalidParameter', subType => 'local'}) },
	'dcreate.invalidParameter.remote'  => sub { return dcreate({subFunction => 'invalidParameter', subType => 'remote'}) },

	'ddelete.base.local'  => sub { return ddelete({subFunction => 'base', subType => 'local'}) }, #ok
	'ddelete.base.remote'  => sub { return ddelete({subFunction => 'base', subType => 'remote'}) }, #ok
	'ddelete.basePath.local'  => sub { return ddelete({subFunction => 'basePath', subType => 'local'}) }, #ok
	'ddelete.basePath.remote'  => sub { return ddelete({subFunction => 'basePath', subType => 'remote'}) }, #ok
	'ddelete.accessDeniedDir.local'  => sub { return ddelete({subFunction => 'accessDeniedDir', subType => 'local'}) }, #ok
	'ddelete.accessDeniedDir.remote'  => sub { return ddelete({subFunction => 'accessDeniedDir', subType => 'remote'}) }, #ok
	'ddelete.notExistingDir.local'  => sub { return ddelete({subFunction => 'notExistingDir', subType => 'local'}) },  #ok
	'ddelete.notExistingDir.remote'  => sub { return ddelete({subFunction => 'notExistingDir', subType => 'remote'}) }, #ok
	
	'dmove.base.local'  => sub { return dmove({subFunction => 'base', subType => 'local'}) }, #ok
	'dmove.base.remote'  => sub { return dmove({subFunction => 'base', subType => 'remote'}) }, #ok
	'dmove.basePath.local'  => sub { return dmove({subFunction => 'basePath', subType => 'local'}) }, #ok
	'dmove.basePath.remote'  => sub { return dmove({subFunction => 'basePath', subType => 'remote'}) }, #ok
	'dmove.accessDeniedDir.local'  => sub { return dmove({subFunction => 'accessDeniedDir', subType => 'local'}) }, #ok
	'dmove.accessDeniedDir.remote'  => sub { return dmove({subFunction => 'accessDeniedDir', subType => 'remote'}) }, #ok
	'dmove.notExistingDir.local'  => sub { return dmove({subFunction => 'notExistingDir', subType => 'local'}) }, #ok
	'dmove.notExistingDir.remote'  => sub { return dmove({subFunction => 'notExistingDir', subType => 'remote'}) }, #ok
	
	'echo.base.local'  => sub { return echo({subFunction => 'base', subType => 'local'}) }, #ok
	'echo.base.remote'  => sub { return echo({subFunction => 'base', subType => 'remote'}) }, #ok
	
	'fcopy.base.local'  => sub { return fcopy({subFunction => 'base', subType => 'local'}) },
	'fcopy.base.remote'  => sub { return fcopy({subFunction => 'base', subType => 'remote'}) },
	'fcopy.accessDeniedFile.local'  => sub { return fcopy({subFunction => 'accessDeniedFile', subType => 'local'}) },
	'fcopy.accessDeniedFile.remote'  => sub { return fcopy({subFunction => 'accessDeniedFile', subType => 'remote'}) },
	'fcopy.notExistingFile.local'  => sub { return fcopy({subFunction => 'notExistingFile', subType => 'local'}) },
	'fcopy.notExistingFile.remote'  => sub { return fcopy({subFunction => 'notExistingFile', subType => 'remote'}) },
	
	#### ide még kell??
	'fcreate.base.local'  => sub { return fcreate({subFunction => 'base', subType => 'local'}) },
	'fcreate.base.remote'  => sub { return fcreate({subFunction => 'base', subType => 'remote'}) },
	'fcreate.existingFile.local'  => sub { return fcreate({subFunction => 'existingFile', subType => 'local'}) },
	
	'fdelete.base.local'  => sub { return fdelete({subFunction => 'base', subType => 'local'}) }, #ok
	'fdelete.base.remote'  => sub { return fdelete({subFunction => 'base', subType => 'remote'}) }, #ok
	'fdelete.accessDeniedFile.local'  => sub { return fdelete({subFunction => 'accessDeniedFile', subType => 'local'}) }, #ok
	'fdelete.accessDeniedFile.remote'  => sub { return fdelete({subFunction => 'accessDeniedFile', subType => 'remote'}) }, #ok
	'fdelete.notExistingFile.local'  => sub { return fdelete({subFunction => 'notExistingFile', subType => 'local'}) }, #ok
	'fdelete.notExistingFile.remote'  => sub { return fdelete({subFunction => 'notExistingFile', subType => 'remote'}) }, #ok
	
	# még nem működik
	#'ffind.base.local'  => sub { return ffind({subFunction => 'base', subType => 'local'}) },
	#'ffind.base.remote'  => sub { return ffind({subFunction => 'base', subType => 'remote'}) },
	
	'fget.base.remote'  => sub { return fget({subFunction => 'base', subType => 'remote'}) },
	'fget.accessDeniedFile.remote'  => sub { return fget({subFunction => 'accessDeniedFile', subType => 'remote'}) }, # átmásolja, a teszt hibát dob
	'fget.notExistingFile.remote'  => sub { return fget({subFunction => 'notExistingFile', subType => 'remote'}) },
	
	# még nem működik
	#'fgrep.base.local'  => sub { return  fgrep({subFunction => 'base', subType => 'local'}) },
	#'fgrep.base.remote'  => sub { return  fgrep({subFunction => 'base', subType => 'remote'}) },
	
	'fhash.base.local'  => sub { return fhash({subFunction => 'base', subType => 'local'}) }, #ok
	'fhash.base.remote'  => sub { return fhash({subFunction => 'base', subType => 'remote'}) }, #ok
	'fhash.notExistingFile.local'  => sub { return fhash({subFunction => 'notExistingFile', subType => 'local'}) },
	'fhash.notExistingFile.remote'  => sub { return fhash({subFunction => 'notExistingFile', subType => 'remote'}) },
	
	'fmove.base.local'  => sub { return fmove({subFunction => 'base', subType => 'local'}) }, #ok
	'fmove.base.remote'  => sub { return fmove({subFunction => 'base', subType => 'remote'}) }, #ok
	'fmove.accessDeniedFile.local'  => sub { return fmove({subFunction => 'accessDeniedFile', subType => 'local'}) }, #ok 
	'fmove.accessDeniedFile.remote'  => sub { return fmove({subFunction => 'accessDeniedFile', subType => 'remote'}) }, #ok
	'fmove.notExistingFile.local'  => sub { return fmove({subFunction => 'notExistingFile', subType => 'local'}) }, #ok
	'fmove.notExistingFile.remote'  => sub { return fmove({subFunction => 'notExistingFile', subType => 'remote'}) }, #ok
	
	'fput.base.remote'  => sub { return fput({subFunction => 'base', subType => 'remote'}) },
	'fput.accessDeniedFile.remote'  => sub { return fput({subFunction => 'accessDeniedFile', subType => 'remote'}) }, # átmásolja, a teszt hibát dob
	'fput.notExistingFile.remote'  => sub { return fput({subFunction => 'notExistingFile', subType => 'remote'}) },
	
	'fsize.base.local'  => sub { return fsize({subFunction => 'base', subType => 'local'}) }, #ok
	'fsize.base.remote'  => sub { return fsize({subFunction => 'base', subType => 'remote'}) }, #ok
	
	'list.base.local'  => sub { return list({subFunction => 'base', subType => 'local'}) }, #ok
	'list.base.remote'  => sub { return list({subFunction => 'base', subType => 'remote'}) }, #ok
	
	# 2 új
	'load.base.local'  => sub { return load({subFunction => 'base', subType => 'local'}) },
	'load.base.remote'  => sub { return load({subFunction => 'base', subType => 'remote'}) },
	
	'version.base.local'  => sub { return version({subFunction => 'base', subType => 'local'}) }, #ok
	'version.base.remote'  => sub { return version({subFunction => 'base', subType => 'remote'}) } #ok
};

my ($scriptName, $scriptDir, $scritpExt) = fileparse( $0, qr{\.[^.]*$} );
$scriptDir =~ tr#\\#/# and chop $scriptDir;
my $scriptTime = localtime->strftime('%Y%m%d_%H%M%S');
my $reportDir = "$scriptDir/report/$scriptTime";
(mkpath($reportDir) or die "can not create: $reportDir") unless (-e $reportDir);


#########################
#Arguments
#########################

GetOptions ("usage|u!"								=> \(my $usage = 0),
			"help|h!"								=> \(my $help = 0),
			"manual|m!"								=> \(my $manual = 0),
			
			"cterm|c=s"								=> \(my $cterm = "$scriptDir/../../../../bin/cterm.exe"),
			"logFile|lf=s"							=> \(my $logFile = "$reportDir/$scriptName"),
			"keepReportEvenEverythingPassed|kreep!"	=> \(my $keepReportEvenEverythingPassed = 0),
			"timeStamp|ts!"							=> \(my $timeStamp = 1),
			
			"numberOfRuns|nor=i"					=> \(my $numberOfRuns = 1),
			"listOfTests|lot=s{,}"					=> \my @listOfTests,
			"remoteIp|ri=s"							=> \(my $remoteIp = '127.0.0.1'),
			"remotePort|rp=i"						=> \(my $remotePort = 4242)), or pod2usage("-verbose" => 0, "-exit" => 1);
pod2usage("-verbose" => 0, "-exit" => 0) if $usage;
pod2usage("-verbose" => 1, "-exit" => 0) if $help;
pod2usage("-verbose" => 2, "-exit" => 0) if $manual;


#########################
#Verification of arguments
#########################

if (scalar(@ARGV) != 0) {
	foreach my $arg (@ARGV) { print "Unknown argument: $arg";	}
	pod2usage("-verbose" => 0, "-exit" => 1);
}

my @selectedTests;
if (scalar(@listOfTests) > 0) {
	foreach my $argument (@listOfTests) {
		foreach my $test (grep {/$argument/} keys %{$dispatchTable}) {
			push (@selectedTests, $test) unless grep{$_ eq $test} @selectedTests;
		}
	}
} else {
	foreach my $test (sort keys %{$dispatchTable}) {
		push @selectedTests, $test;
	}
}


#########################
#Main program
#########################

#log
my $loghandler = new LogHandler({timeStamp => $timeStamp});
$loghandler->setLogFile({logFile => $logFile});

#options
$loghandler->writeLog({text => 'options:', textColour => "white on_blue", newLinesBeforeText => 2, newLinesAfterText => 2});
$loghandler->writeLog({text => "  cterm = $cterm"});
$loghandler->writeLog({text => "  logFile = $logFile"});
$loghandler->writeLog({text => "  keepReportEvenEverythingPassed = $keepReportEvenEverythingPassed"});
$loghandler->writeLog({text => "  timeStamp = $timeStamp"});
$loghandler->writeLog({text => "  numberOfRuns = $numberOfRuns"});
$loghandler->writeLog({text => "  listOfTests = @listOfTests"});
$loghandler->writeLog({text => "  remoteIp = $remoteIp"});
$loghandler->writeLog({text => "  remotePort = $remotePort"});

#tests
$loghandler->writeLog({text => 'tests:', textColour => "white on_blue", newLinesBeforeText => 2});
my $results;
$results->{PASSED} = 0;
$results->{FAILED} = 0;
$results->{SUM} = 0;
foreach my $test (@selectedTests) {
	$loghandler->writeNewLine;
	$results->{tests}->{$test}->{PASSED} = 0 unless (defined($results->{tests}->{$test}->{PASSED}));
	$results->{tests}->{$test}->{FAILED} = 0 unless (defined($results->{tests}->{$test}->{FAILED}));
	$results->{tests}->{$test}->{SUM} = 0 unless (defined($results->{tests}->{$test}->{SUM}));
	for my $run (1..$numberOfRuns) {
		unless (&{$dispatchTable->{$test}}) {
			$results->{tests}->{$test}->{PASSED} += 1 and $results->{tests}->{$test}->{SUM} += 1;
			$results->{PASSED} += 1 and $results->{SUM} += 1;
		} else {
			$results->{tests}->{$test}->{FAILED} += 1 and $results->{tests}->{$test}->{SUM} += 1;
			$results->{FAILED} += 1 and	$results->{SUM} += 1;
		}
	}
}

#results
$loghandler->writeLog({text => 'results:', textColour => "white on_blue", newLinesBeforeText => 2, newLinesAfterText => 2});
foreach my $test (sort keys %{$results->{tests}}) {
	if ($results->{tests}->{$test}->{FAILED} == 0) {
		$loghandler->writeLog({text => "$test: PASSED: $results->{tests}->{$test}->{PASSED}/$results->{tests}->{$test}->{SUM}", textColour => "white on_green"});
	} elsif ($results->{tests}->{$test}->{PASSED} == 0) {
		$loghandler->writeLog({text => "$test: FAILED: $results->{tests}->{$test}->{FAILED}/$results->{tests}->{$test}->{SUM}", textColour => "white on_red"});
	} else {
		$loghandler->writeLog({text => "$test: PASSED: $results->{tests}->{$test}->{PASSED}/$results->{tests}->{$test}->{SUM}, FAILED: $results->{tests}->{$test}->{FAILED}/$results->{tests}->{$test}->{SUM}", textColour => "white on_red"});
	}
}
$loghandler->writeNewLine;
if ($results->{SUM} == 0) {
	$loghandler->writeLog({text => "$scriptName: UNSTABLE: not found executable test", textColour => "white on_yellow"});
} elsif ($results->{FAILED} == 0) {
	$loghandler->writeLog({text => "$scriptName: PASSED: $results->{PASSED}/$results->{SUM}", textColour => "white on_green"});
} elsif ($results->{PASSED} == 0) {
	$loghandler->writeLog({text => "$scriptName: FAILED: $results->{FAILED}/$results->{SUM}", textColour => "white on_red"});
} else {
	$loghandler->writeLog({text => "$scriptName: PASSED: $results->{PASSED}/$results->{SUM}, FAILED: $results->{FAILED}/$results->{SUM}", textColour => "white on_red"});
}

#clean
if (!$keepReportEvenEverythingPassed && $results->{FAILED} == 0) {
	rmtree($reportDir) or die "can not delete: $reportDir";
	my $dirContent;
	opendir(my $dir, "$scriptDir/report") or die "can not open: $scriptDir/report";
        $dirContent = readdir $dir for 1..3;
	closedir $dir;
	(rmtree("$scriptDir/report") or die "can not delete: $scriptDir/report") if (!defined($dirContent));
}

#exit
if ($results->{SUM} == 0) {
	$status = 3;
} elsif ($results->{FAILED} == 0) {
	$status = 0;
} else {
	$status = 2;
}
END {
	exit $status;
}


#########################
#Subroutines
#########################


sub dcreate {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				my ($time, $timeout) = (time, 9);
				kill 'SIGKILL', $remoteCterm;
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}
					$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "directory was not created: $parameter" if (!-e "$parameter");
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'basePath';
	$parameter = "$scriptDir/$sub/test/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
					$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "path was not created: $parameter" if (!-e "$parameter");
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'existingDir';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir($parameter) or die "can not create: $parameter";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'invalidParameter';
	$parameter = "$scriptDir/$sub/te:st";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			if (!-e $parameter) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm created invalid directory", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}	

sub ddelete {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir($parameter) or die "can not create: $parameter";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "directory still exits: $parameter" if (-e $parameter);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}

	$subFunction = 'basePath';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$parameter") or die "can not create: $parameter";
			mkdir("$parameter/test") or die "can not create: $parameter/test";
			open(my $file, '>', "$parameter/test/test.txt") or die "can not create $parameter/test/test.txt";
			print $file $parameter;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "path was not deleted: $parameter" if (-e $parameter);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedDir';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			mkdir($parameter) or die "can not create: $parameter";
			open(my $file, '>', "$parameter/test.txt") or die "can not create $parameter/test.txt"; ##comment## az opendir nem fogta ténylegesen a mappát, tudta törölni, ezért teszteléshez nem volt jó
			print $file $parameter;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') 	{
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			close $file;
			if (-e $parameter) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm deleted access denied directory", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingDir';
	$parameter = "$scriptDir/$sub/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "cterm did not throw an error" if ($errorNotOccured); 
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}	
	
sub dmove {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/input/test";
	$parameter2 = "$scriptDir/$sub/output/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			mkdir($parameter1) or die "can not create: $parameter1"; ##comment## más nem kell, azt a dmove.basePath nézi
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "directory was not moved" if (!-e $parameter2 || -e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'basePath';
	$parameter1 = "$scriptDir/$sub/input/test";
	$parameter2 = "$scriptDir/$sub/output/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			mkdir($parameter1) or die "can not create: $parameter1";
			mkdir("$parameter1/test") or die "can not create: $parameter1/test";
			open(my $file, '>', "$parameter1/test/test.txt") or die "can not create $parameter1/test/test.txt";
			print $file $parameter1;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "directory was not moved" if (!-e $parameter2 || -e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedDir';
	$parameter1 = "$scriptDir/$sub/input/test";
	$parameter2 = "$scriptDir/$sub/output/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			mkdir($parameter1) or die "can not create: $parameter1";
			open(my $file, '>', "$parameter1/test.txt") or die "can not create $parameter1/test.txt"; ##comment## az opendir nem fogta ténylegesen a mappát, tudta törölni, ezért teszteléshez nem volt jó
			print $file $parameter1;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			close $file;		
			if (!-e $parameter2 || -e $parameter1) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm moved access denied directory", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingDir';
	$parameter1 = "$scriptDir/$sub/input/test";
	$parameter2 = "$scriptDir/$sub/output/test";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "cterm did not throw an error" if ($errorNotOccured); 
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}	

sub echo {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = 'test text';
	if ($options->{subFunction} eq $subFunction) {
		eval {
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $answer = $localCterm->command($command, $parameter);
			$loghandler->writeLog({ text => "$sub: answer:\n$answer"});
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "answer is incorrect" if ($answer ne $parameter);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fcopy {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "file was not copied" if (!-e $parameter2 || !-e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			close $file;		
			if (!-e $parameter2 || !-e $parameter1) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm copied access denied file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "cterm did not throw an error" if ($errorNotOccured); 
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fcreate {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "file was not created: $parameter" if (!-e "$parameter");
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'existingFile';
	$parameter = "$scriptDir/$sub/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			open(my $file, '>', $parameter) or die "can not create $parameter";
			print $file $parameter;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			if (-s $parameter != 0) {
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm overwrote existing file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'invalidParameter';
	$parameter = "$scriptDir/$sub/>.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			if (!-e $parameter) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm created invalid file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fdelete {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			open(my $file, '>', $parameter) or die "can not create $parameter";
			print $file $parameter;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			$localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "file still exits: $parameter" if (-e $parameter);
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedFile';
	$parameter = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			open(my $file, '>', $parameter) or die "can not create $parameter";
			print $file $parameter;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			close $file;
			if (-e $parameter) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm deleted access denied file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "cterm did not throw an error" if ($errorNotOccured);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fget {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
					$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "file was not copied" if (!-e $parameter2 || !-e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}

	
	$subFunction = 'accessDeniedFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			close $file;		
			if (!-e $parameter2 || !-e $parameter1) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm copied access denied file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "cterm did not throw an error" if ($errorNotOccured); 
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fhash {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $parameter3;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/text1.txt";
	$parameter2 = "$scriptDir/$sub/text2.txt"; ##comment## nem lehet mindnek ugyanaz a neve
	$parameter3 = "$scriptDir/$sub/text3.txt"; ##comment## nem lehet mindnek ugyanaz a neve
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			open(my $file1, '>', $parameter1) or die "can not create $parameter1";
			for (my $i = 0; $i < 100; $i++) {
				print $file1 $parameter1;
			}
            close $file1;
			
			open(my $file2, '>', $parameter2) or die "can not create $parameter2";
			for (my $i = 0; $i < 100; $i++) {
				print $file2 $parameter1; ##comment## tartalom ugyanaz kell legyen
			}
            close $file2;
			
			open(my $file3, '>', $parameter3) or die "can not create $parameter3";
			for (my $i = 0; $i < 99; $i++) { ##comment## eggyel kevesebbszer ugyanaz
				print $file3 $parameter1; ##comment## tartalom ugyanaz kell legyen
			}
			my $lastLine = $parameter1;
			chop $lastLine;
			$lastLine = $lastLine.'u'; ##comment## utolsó sor utolsó karaktere kell más legyen
			print $file3 $lastLine;
            close $file3;			
				
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1"});
			my $answer1 = $localCterm->command($command, $parameter1); ##comment## fhashnek egy paramétere van
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter2"});
			my $answer2 = $localCterm->command($command, $parameter2); ##comment## fhashnek egy paramétere van
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter3"});
			my $answer3 = $localCterm->command($command, $parameter3); ##comment## fhashnek egy paramétere van
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				my ($time, $timeout) = (time, 9);
				kill 'SIGKILL', $remoteCterm;
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}
					$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "hash values for matching files: $answer1 and $answer2, hash values for non-matching files: $answer1 and $answer3" if (($answer1 ne $answer2) || ($answer1 eq $answer3)); ##comment## a hash értékeket kell összehasonlítani
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter1 = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				my ($time, $timeout) = (time, 9);
				kill 'SIGKILL', $remoteCterm;
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}
					$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "cterm did not throw an error" if ($errorNotOccured);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fmove {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "file was not moved" if (!-e $parameter2 || -e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input"; ##comment## ez hiányzott
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output"; ##comment## ez hiányzott
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			close $file;
			if (!-e $parameter2 || -e $parameter1) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm moved access denied file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter1"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "cterm did not throw an error" if ($errorNotOccured);

		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub fput {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter1;
	my $parameter2;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			$localCterm->command($command, $parameter1, $parameter2);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "file was not copied" if (!-e $parameter2 || !-e $parameter1);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'accessDeniedFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			open(my $file, '>', $parameter1) or die "can not create $parameter1";
			print $file $parameter1;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			close $file;		
			if (!-e $parameter2 || !-e $parameter1) {  ##comment##
				die "cterm did not throw an error" if ($errorNotOccured);
			} else {
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: cterm copied access denied file", textColour => 'black on_yellow'});
			}
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
	
	$subFunction = 'notExistingFile';
	$parameter1 = "$scriptDir/$sub/input/test.txt";
	$parameter2 = "$scriptDir/$sub/output/test.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			mkdir("$scriptDir/$sub/input") or die "can not create: $scriptDir/$sub/input";
			mkdir("$scriptDir/$sub/output") or die "can not create: $scriptDir/$sub/output";
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter1 $parameter2"});
			my $errorNotOccured = 0;
			eval {
				$localCterm->command($command, $parameter1, $parameter2);
			}; if ($@) {
			} else {
				$errorNotOccured = 1;
			}
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();
			
			die "cterm did not throw an error" if ($errorNotOccured); 
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}
	
sub fsize {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			open(my $file, '>', $parameter) or die "can not create $parameter";
			for (my $i = 0; $i < 100; $i++) {
                print $file $parameter;
			}
            close $file;
            my $fileSize = -s $parameter;
				
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $answer = $localCterm->command($command, $parameter);
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "results of file size measurements are not the same: ${fileSize}b(script) and ${answer}b(cterm)" if ($fileSize ne $answer);
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}
	
sub list {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $command = $sub;
	
	$subFunction = 'base';
	if ($options->{subFunction} eq $subFunction) {
		eval {
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command"});
			my $answer = $localCterm->command($command);
			$loghandler->writeLog({ text => "$sub: answer:\n$answer"});
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "answer does not start with '#'" if (substr($answer,0,1) ne '#');
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}

sub load {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $parameter;
	my $command = $sub;
	
	$subFunction = 'base';
	$parameter = "$scriptDir/$sub/text.txt";
	if ($options->{subFunction} eq $subFunction) {
		eval {
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			mkdir("$scriptDir/$sub") or die "can not create: $scriptDir/$sub";
			
			open(my $file, '>', $parameter) or die "can not create $parameter";
			print $file "echo test\n";
			close $file;
			
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command $parameter"});
			my $answer = $localCterm->command($command, $parameter);
			$loghandler->writeLog({ text => "$sub: answer:\n$answer"});
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "file was not loaded: $parameter" if ($answer ne 'ok');
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}
	
sub version {
	my ($options) = @_;
	my $sub = substr((caller(0))[3], 6);
	my $subFunction;
	my $command = $sub;
	
	$subFunction = 'base';
	if ($options->{subFunction} eq $subFunction) {
		eval {
			my $localCterm = new CTermInterface({cterm => $cterm});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: local cterm: $localCterm->{childpid}"});
			my $remoteCterm;
			if ($options->{subType} eq 'remote') {
				$remoteCterm = open3(my $stdin, my $stdout, my $stderr, $cterm, "-s", "-a", $remoteIp, "-p", $remotePort);
				$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: remote cterm: $remoteCterm"});
				$localCterm->command("connect", $remoteIp, $remotePort);
			}
			
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: command: $command"});
			my $answer = $localCterm->command($command);
			$loghandler->writeLog({ text => "$sub: answer:\n$answer"});
			
			if ($options->{subType} eq 'remote') {
				$localCterm->command("disconnect");
				$localCterm->command('pdelpid', $remoteCterm);
				my ($time, $timeout) = (time, 6);
				my $status = kill 0, $remoteCterm;
				while ($status) {
					if ((time-$time) > $timeout) {
						die "remoteCterm still exists";
					}   
				$status = kill 0, $remoteCterm;
				}
			}
			$localCterm->DESTROY();	
			
			die "answer is incorrect" unless ($answer =~ /^(\d+\.)?(\d+\.)?(\d+)$/);
			
		}; if ($@) {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: error: $@", textColour => "white on_red"});
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: FAILED", textColour => "white on_red"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 1;
		} else {
			$loghandler->writeLog({ text => "$sub.$subFunction.$options->{subType}: PASSED", textColour => "white on_green"});
			(rmtree("$scriptDir/$sub") or die "can not delete: $scriptDir/$sub") if(-e "$scriptDir/$sub");
			return 0;
		}
	}
}



#########################
#Documentation
#########################
