#!/usr/bin/perl

package CommandHandler;

use strict;
use warnings;

use Cwd;
use File::Basename;
use File::Spec;
use lib File::Spec->catdir(File::Basename::dirname(Cwd::abs_path __FILE__), '.');

use CommandHandler::AppHandler;
use CommandHandler::GatewayHandler;

$| = 1;

1;