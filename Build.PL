use 5.004;
use strict;
use lib 'inc';
eval "require Pod::WikiDoc";
my $class = $@ ? "Module::Build" : "Module::Build::WikiDoc";
eval "require $class";

# Do Schwern's API warnings and make sure it appends to generated Makefile.PL
my $api_warning = do { local $/; <DATA> };
eval $api_warning;
if ( $@ ) {
  die $@ if $@ =~ /OS unsupported/;
  warn $@;
}

$api_warning = quotemeta($api_warning);

my $mb = $class->subclass( code => << "END_CODE" );

    sub do_create_makefile_pl {
        my \$self = shift;
        warn "Custom Makefile.PL\n";
        \$self->SUPER::do_create_makefile_pl;
        local *FH;
        open FH, ">> Makefile.PL" or die \$!;
        print {FH} "\nBEGIN {\n$api_warning\n}\n";
        close FH;
    }

END_CODE

$mb->new(
    module_name         => 'File::chdir',
    dist_author         => 'David A. Golden <dagolden@cpan.org>',
    license             => 'perl',
    create_readme       => 1,
    create_makefile_pl  => 'traditional',
    requires        => {
        # module requirements here
        'Cwd'           => 3.16,
        'File::Spec'    => 3.27,
    },
    meta_add            => {
        no_index => {
            directory => [ qw{
                examples
                inc
            }],
        }
    },
)->create_build_script;

__DATA__
die "OS unsupported: Perl 5.13.1 accidentally broke File::chdir. Aborting!\n"
  if $] eq "5.013001";

use vars qw/$PACKAGE $LAST_API_CHANGE/;
$PACKAGE = 'File::chdir';
$LAST_API_CHANGE = 0.08;

eval "require $PACKAGE";

no strict 'refs';
if(!$@ && ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE) {
    print <<"CHANGE_WARN";

WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING

-----*****>>>>>     THE INTERFACE HAS CHANGED     <<<<<*****----------

As of 0.08, changing \$CWD or \@CWD will die with an error if the directory
change fails.  Earlier versions of File::chdir failed silently.

WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING

We'll pause for 20 seconds...

CHANGE_WARN

    sleep 20;
}


