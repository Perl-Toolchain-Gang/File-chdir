#!/usr/bin/perl -Tw

use strict;
use lib qw(t/lib);
use Test::More tests => 31;

BEGIN { use_ok('File::chdir') }

use Cwd;

# assemble directories the same way as File::chdir
BEGIN { *_catdir = \&File::chdir::ARRAY::_catdir };

# _catdir has OS-specific path separators so do the same for getcwd
sub _getcwd { File::Spec->canonpath( getcwd ) }

my @cwd = grep length, File::Spec->splitdir(Cwd::abs_path);

ok( tied @CWD,      '@CWD is fit to be tied' );

# First, let's try unlocalized push @CWD.
{
    push @CWD, 't';
    is( _getcwd, _catdir(@cwd,'t'),       'unlocalized push @CWD works' );
    ok( eq_array(\@CWD, [@cwd, 't']),    '  @CWD set' );
    is( $CWD,   _catdir(@cwd,'t'),       '  $CWD set' );
}

is( _getcwd, _catdir(@cwd,'t'),      'unlocalized @CWD unneffected by blocks' );
ok( eq_array(\@CWD, [@cwd, 't']),   '  @CWD still set' );

# reset
@CWD = @cwd;

# How about pop?
{
    my $popped_dir = pop @CWD;
    my @new_cwd = @cwd[0..$#cwd-1];

    is( _getcwd, _catdir(@new_cwd),      'unlocalized pop @CWD works' );
    is( $popped_dir, $cwd[-1],          '  returns popped dir' ); 
    ok( eq_array(\@CWD, \@new_cwd),     '  @CWD set' );
    is( $CWD,   _catdir(@new_cwd),      '  $CWD set' );
}

is( _getcwd, _catdir(@cwd[0..$#cwd-1]), 
                                  'unlocalized @CWD unneffected by blocks' );
ok( eq_array(\@CWD, [@cwd[0..$#cwd-1]]),   '  @CWD still set' );

# reset
@CWD = @cwd;


# splice?
{
    my @spliced_dirs = splice @CWD, -2;
    my @new_cwd = @cwd[0..$#cwd-2];

    is( _getcwd, _catdir(@new_cwd),      'unlocalized splice @CWD works' );
    is( @spliced_dirs, 2,               '  returns right # of dirs' );
    ok( eq_array(\@spliced_dirs, [@cwd[-2,-1]]), "  and they're correct" );
    ok( eq_array(\@CWD, \@new_cwd),     '  @CWD set' );
    is( $CWD,   _catdir(@new_cwd),      '  $CWD set' );
}

is( _getcwd, _catdir(@cwd[0..$#cwd-2]),
                                    'unlocalized @CWD unneffected by blocks' );
ok( eq_array(\@CWD, [@cwd[0..$#cwd-2]]),   '  @CWD still set' );

# reset
@CWD = @cwd;

# Now an unlocalized assignment
{
    @CWD = (@cwd, 't');
    is( _getcwd, _catdir(@cwd,'t'),       'unlocalized @CWD works' );
    ok( eq_array(\@CWD, [@cwd, 't']),   '  @CWD set' );
    is( $CWD,   _catdir(@cwd,'t'),       '  $CWD set' );
}

is( _getcwd, _catdir(@cwd,'t'),      'unlocalized @CWD unneffected by blocks' );
ok( eq_array(\@CWD, [@cwd, 't']),   '  @CWD still set' );

# reset
@CWD = @cwd;

eval { $#CWD = 1; };
ok( !$@,    '$#CWD assignment is a no-op' );


# localized assignment
{
    # localizing tied arrays doesn't work, perl bug. :(
    # this is a work around.
    local $CWD;
    @CWD = (@cwd, 't');
    is( _getcwd, _catdir(@cwd,'t'),       'localized @CWD works' );
    ok( eq_array(\@CWD, [@cwd, 't']),   '  @CWD set' );
    is( $CWD,   _catdir(@cwd,'t'),       '  $CWD set' );
}

is( _getcwd, _catdir(@cwd),    'localized @CWD resets cwd' );
ok( eq_array(\@CWD, \@cwd),   '  @CWD reset' );
