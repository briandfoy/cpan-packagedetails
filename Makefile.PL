use ExtUtils::MakeMaker;

require 5.008;

eval "use Test::Manifest 1.21";

WriteMakefile(
	'NAME'	       => 'CPAN::PackageDetails',
	'ABSTRACT'     => 'Create or read 02packages.details.txt.gz',
	'VERSION_FROM' => 'lib/PackageDetails.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'PREREQ_PM'    => { 
		'Test::More'             => '0',
		'Test::Output'           => '0.10',
		'IO::Compress::Gzip'     => '0',
		'IO::Uncompress::Gunzip' => '0',
		},

	'PM'           => {
		'lib/PackageDetails.pm' => '$(INST_LIBDIR)/PackageDetails.pm',
		},

	clean  => { FILES    => q|CPAN-PackageDetails-* t/test_output| },

	);
