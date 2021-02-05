BEGIN {
	@classes = qw(
		CPAN::PackageDetails
		CPAN::PackageDetails::Header
		CPAN::PackageDetails::Entries
		CPAN::PackageDetails::Entry
		);
	}
use Test::More;


foreach my $class ( @classes ) {

done_testing();
	print "Bail out! $class did not compile\n" unless use_ok( $class );
	}
