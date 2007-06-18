# A template for Makefile.PL.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.

use 5.004;

use ExtUtils::MakeMaker;

$PACKAGE = 'File::chdir';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
$LAST_API_CHANGE = 0.04;

eval "require $PACKAGE";

if(!$@ && ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE) {
    print <<"CHANGE_WARN";

WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING

-----*****>>>>>     THE INTERFACE HAS CHANGED     <<<<<*****----------

The chdir() override has been ELIMINATED.  It's too complicated and
not worth the trouble.

WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING

We'll pause for 20 seconds...

CHANGE_WARN

    sleep 20;
}

WriteMakefile(
    NAME            => $PACKAGE,
    AUTHOR          => 'Michael G Schwern <schwern@pobox.com>',
    ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm", 
    VERSION_FROM    => "lib/$PACKAGE_FILE.pm", # finds $VERSION
    LICENSE         => "perl",
    PREREQ_PM       => { Cwd        => 3.16,
                         File::Spec => 3.16,
                       },
    'dist'          => { COMPRESS   => 'gzip -9',
                         SUFFIX     => '.gz',
                         DIST_DEFAULT   => 'all tardist',
                       },
);


{
    package MY;

    sub test_via_harness {
        my($self, $orig_perl, $tests) = @_;

        my @perls = ($orig_perl);
        push @perls, qw(bleadperl 
                        perl5.6.1
                        perl5.6.0
                        perl5.005_03 
                        perl5.004_05 
                        perl5.004_04
                        perl5.004)
          if $ENV{PERL_TEST_ALL};

        my $out;
        foreach my $perl (@perls) {
            $out .= $self->SUPER::test_via_harness($perl, $tests);
        }

        return $out;
    }
}
