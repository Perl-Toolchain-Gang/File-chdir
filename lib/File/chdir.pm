package File::chdir;
use 5.004;
use strict;
use vars qw($VERSION @ISA @EXPORT $CWD @CWD);
$VERSION = '0.1002';
$VERSION = eval $VERSION; ## no critic

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($CWD @CWD);

use Carp;
use Cwd;
use File::Spec::Functions qw/canonpath splitpath catpath splitdir catdir/;

tie $CWD, 'File::chdir::SCALAR' or die "Can't tie \$CWD";
tie @CWD, 'File::chdir::ARRAY'  or die "Can't tie \@CWD";

sub _abs_path { 
    # Otherwise we'll never work under taint mode.
    my($cwd) = Cwd::abs_path =~ /(.*)/;
    # Run through File::Spec, since everything else uses it 
    return canonpath($cwd);
}

# splitpath but also split directory
sub _split_cwd {
    my ($vol, $dir) = splitpath(_abs_path, 1);
    my @dirs = splitdir( $dir );
    shift @dirs; # get rid of leading empty "root" directory
    return ($vol, @dirs);
}

# catpath, but take list of directories
# restore the empty root dir and provide an empty file to avoid warnings
sub _catpath {
    my ($vol, @dirs) = @_;
    return catpath($vol, catdir(q{}, @dirs), q{});
}

sub _chdir { 
    my($new_dir) = @_;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    if ( ! CORE::chdir($new_dir) ) {
        croak "Failed to change directory to '$new_dir': $!";
    };
    return 1;
}

{
    package File::chdir::SCALAR;
    use Carp;

    BEGIN { 
        *_abs_path = \&File::chdir::_abs_path;
        *_chdir = \&File::chdir::_chdir;
        *_split_cwd = \&File::chdir::_split_cwd;
        *_catpath = \&File::chdir::_catpath;
    }

    sub TIESCALAR { 
        bless [], $_[0];
    }

    # To be safe, in case someone chdir'd out from under us, we always
    # check the Cwd explicitly.
    sub FETCH {
        return _abs_path;
    }

    sub STORE {
        return unless defined $_[1];
        _chdir($_[1]);
    }
}


{
    package File::chdir::ARRAY;
    use Carp;

    BEGIN { 
        *_abs_path = \&File::chdir::_abs_path; 
        *_chdir = \&File::chdir::_chdir;
        *_split_cwd = \&File::chdir::_split_cwd;
        *_catpath = \&File::chdir::_catpath;
    }

    sub TIEARRAY {
        bless {}, $_[0];
    }

    sub FETCH { 
        my($self, $idx) = @_;
        my ($vol, @cwd) = _split_cwd;
        return $cwd[$idx];
    }

    sub STORE {
        my($self, $idx, $val) = @_;

        my ($vol, @cwd) = _split_cwd;
        if( $self->{Cleared} ) {
            @cwd = ();
            $self->{Cleared} = 0;
        }

        $cwd[$idx] = $val;
        my $dir = _catpath($vol,@cwd);

        _chdir($dir);
        return $cwd[$idx];
    }

    sub FETCHSIZE { 
        my ($vol, @cwd) = _split_cwd;
        return scalar @cwd; 
    }
    sub STORESIZE {}

    sub PUSH {
        my($self) = shift;

        my $dir = _catpath(_split_cwd, @_);
        _chdir($dir);
        return $self->FETCHSIZE;
    }

    sub POP {
        my($self) = shift;

        my ($vol, @cwd) = _split_cwd;
        my $popped = pop @cwd;
        my $dir = _catpath($vol,@cwd);
        _chdir($dir);
        return $popped;
    }

    sub SHIFT {
        my($self) = shift;

        my ($vol, @cwd) = _split_cwd;
        my $shifted = shift @cwd;
        my $dir = _catpath($vol,@cwd);
        _chdir($dir);
        return $shifted;
    }

    sub UNSHIFT {
        my($self) = shift;

        my ($vol, @cwd) = _split_cwd;
        my $dir = _catpath($vol, @_, @cwd);
        _chdir($dir);
        return $self->FETCHSIZE;
    }

    sub CLEAR  {
        my($self) = shift;
        $self->{Cleared} = 1;
    }

    sub SPLICE {
        my $self = shift;
        my $offset = shift || 0;
        my $len = shift || $self->FETCHSIZE - $offset;
        my @new_dirs = @_;
        
        my ($vol, @cwd) = _split_cwd;
        my @orig_dirs = splice @cwd, $offset, $len, @new_dirs;
        my $dir = _catpath($vol, @cwd);
        _chdir($dir);
        return @orig_dirs;
    }

    sub EXTEND { }
    sub EXISTS { 
        my($self, $idx) = @_;
        return $self->FETCHSIZE >= $idx ? 1 : 0;
    }

    sub DELETE {
        my($self, $idx) = @_;
        croak "Can't delete except at the end of \@CWD"
            if $idx < $self->FETCHSIZE - 1;
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->POP;
    }
}

1;
__END__

=begin wikidoc

= NAME

File::chdir - a more sensible way to change directories

= VERSION

This documentation describes version %%VERSION%%.

= SYNOPSIS

  use File::chdir;

  $CWD = "/foo/bar";     # now in /foo/bar
  {
      local $CWD = "/moo/baz";  # now in /moo/baz
      ...
  }

  # still in /foo/bar!

= DESCRIPTION

Perl's {chdir()} has the unfortunate problem of being very, very, very
global.  If any part of your program calls {chdir()} or if any library
you use calls {chdir()}, it changes the current working directory for
the *whole* program.

This sucks.

File::chdir gives you an alternative, {$CWD} and {@CWD}.  These two
variables combine all the power of {chdir()}, [File::Spec] and [Cwd].

= $CWD

Use the {$CWD} variable instead of {chdir()} and Cwd.

    use File::chdir;
    $CWD = $dir;  # just like chdir($dir)!
    print $CWD;   # prints the current working directory

It can be localized, and it does the right thing.

    $CWD = "/foo";      # it's /foo out here.
    {
        local $CWD = "/bar";  # /bar in here
    }
    # still /foo out here!

{$CWD} always returns the absolute path in the native form for the 
operating system.

{$CWD} and normal {chdir()} work together just fine.

= @CWD

{@CWD} represents the current working directory as an array, each
directory in the path is an element of the array.  This can often make
the directory easier to manipulate, and you don't have to fumble with
{File::Spec->splitpath} and {File::Spec->catdir} to make portable code.

  # Similar to chdir("/usr/local/src/perl")
  @CWD = qw(usr local src perl);

pop, push, shift, unshift and splice all work.  pop and push are
probably the most useful.

  pop @CWD;                 # same as chdir(File::Spec->updir)
  push @CWD, 'some_dir'     # same as chdir('some_dir')

{@CWD} and {$CWD} both work fine together.

*NOTE* Due to a perl bug you can't localize {@CWD}.  See [/BUGS and
CAVEATS] for a work around.

= EXAMPLES

(We omit the {use File::chdir} from these examples for terseness)

Here's {$CWD} instead of {chdir()}:

    $CWD = 'foo';           # chdir('foo')

and now instead of Cwd.

    print $CWD;             # use Cwd;  print Cwd::abs_path

you can even do zsh style {cd foo bar}

    $CWD = '/usr/local/foo';
    $CWD =~ s/usr/var/;

if you want to localize that, make sure you get the parens right

    {
        (local $CWD) =~ s/usr/var/;
        ...
    }

It's most useful for writing polite subroutines which don't leave the
program in some strange directory:

    sub foo {
        local $CWD = 'some/other/dir';
        ...do your work...
    }

which is much simpler than the equivalent:

    sub foo {
        use Cwd;
        my $orig_dir = Cwd::abs_path;
        chdir('some/other/dir');

        ...do your work...

        chdir($orig_dir);
    }

{@CWD} comes in handy when you want to start moving up and down the
directory hierarchy in a cross-platform manner without having to use
File::Spec.

    pop @CWD;                   # chdir(File::Spec->updir);
    push @CWD, 'some', 'dir'    # chdir(File::Spec->catdir(qw(some dir)));

You can easily change your parent directory:

    # chdir from /some/dir/bar/moo to /some/dir/foo/moo
    $CWD[-2] = 'foo';

= CAVEATS

=== Assigning to {@CWD} calls {chdir()} for each element

    @CWD = qw/a b c d/;

Internally, Perl clears {@CWD} and assigns each element in turn.  Thus, this
code above will do this:

    chdir 'a';
    chdir 'a/b';
    chdir 'a/b/c';
    chdir 'a/b/c/d';

Generally, avoid assigning to {@CWD} and just use push and pop instead.

=== {local @CWD} does not work.

{local @CWD>} will not localize {@CWD}.  This is a bug in Perl, you
can't localize tied arrays.  As a work around localizing $CWD will
effectively localize @CWD.

    {
        local $CWD;
        pop @CWD;
        ...
    }

=== Volumes not handled

There is currently no way to change the current volume via File::chdir.

= NOTES

{$CWD} returns the current directory using native path separators, i.e. \ 
on Win32.  This ensures that {$CWD} will compare correctly with directories
created using File::Spec.  For example:

    my $working_dir = File::Spec->catdir( $CWD, "foo" );
    $CWD = $working_dir;
    doing_stuff_might_chdir();
    is( $CWD, $working_dir, "back to original working_dir?" );

Deleting the last item of {@CWD} will act like a pop.  Deleting from the
middle will throw an exception.

    delete @CWD[-1]; # OK
    delete @CWD[-2]; # Dies

What should %CWD do?  Something with volumes?

    # chdir to C:\Program Files\Sierra\Half Life ?
    $CWD{C} = '\\Program Files\\Sierra\\Half Life';

= DIAGNOSTICS

If an error is encountered when changing {$CWD} or {@CWD}, one of
the following exceptions will be thrown:

* ~Can't delete except at the end of @CWD~
* ~Failed to change directory to '$dir'~

= BUGS

Please report any bugs or feature using the CPAN Request Tracker.  
Bugs can be submitted through the web interface at 
[http://rt.cpan.org/Dist/Display.html?Queue=File-chdir]

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

= AUTHOR

* Michael G Schwern <schwern@pobox.com> (original author)
* David A Golden <dagolden@cpan.org> (current maintainer)

= LICENSE

Copyright 2001-2003 by Michael G Schwern <schwern@pobox.com>.
Portions copyright 2006-2007 by David A Golden <dagolden@cpan.org>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See [http://dev.perl.org/licenses/]

= HISTORY

Michael wanted {local chdir} to work.  p5p didn't.  But it wasn't over!
Was it over when the Germans bombed Pearl Harbor?  Hell, no!

Abigail and/or Bryan Warnock suggested the {$CWD} thing (Michael forgets
which).  They were right.

The {chdir()} override was eliminated in 0.04.

David became co-maintainer with 0.06_01 to fix some chronic
Win32 path bugs.

As of 0.08, if changing {$CWD} or {@CWD} fails to change the directory, an
error will be thrown.

= SEE ALSO

[File::pushd], [File::Spec], [Cwd], [perlfunc/chdir], 
"Animal House" [http://www.imdb.com/title/tt0077975/quotes]

=end wikidoc

=cut

