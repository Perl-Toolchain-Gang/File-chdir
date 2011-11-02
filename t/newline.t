#!/usr/bin/env perl -w

use strict;
use warnings;

use Test::More;

use File::chdir;
use Cwd qw(abs_path);

my $Orig_Cwd = $CWD;

my $Test_Dir = "t/testdir$$\ntest";
my $Can_mkdir_With_Newline = mkdir $Test_Dir;

plan skip_all => "Can't make a directory with a newline in it" unless $Can_mkdir_With_Newline;

{
    local $CWD = $Test_Dir;
    is $CWD, abs_path;
}

is $CWD, $Orig_Cwd;
is abs_path, $Orig_Cwd;

END {
    chdir $Orig_Cwd;  # just in case
    rmdir $Test_Dir;
}

done_testing;
