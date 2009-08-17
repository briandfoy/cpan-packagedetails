use ExtUtils::MakeMaker;

require 5.008;

eval "use Test::Manifest 1.23";

WriteMakefile(
	'NAME'	       => 'CPAN::PackageDetails',
	'ABSTRACT'     => 'Create or read 02packages.details.txt.gz',
	'VERSION_FROM' => 'lib/PackageDetails.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'PREREQ_PM'    => { 
		'CPAN::DistnameInfo'     => '0',
		'Test::More'             => '0',
		'Test::Output'           => '0.10',
		'IO::Compress::Gzip'     => '0',
		'IO::Uncompress::Gunzip' => '0',
		},

	'PM'           => {
		'lib/PackageDetails.pm' => '$(INST_LIBDIR)/PackageDetails.pm',
		'lib/Header.pm'         => '$(INST_LIBDIR)/PackageDetails/Header.pm',
		'lib/Entries.pm'        => '$(INST_LIBDIR)/PackageDetails/Entries.pm',
		'lib/Entry.pm'          => '$(INST_LIBDIR)/PackageDetails/Entry.pm',
		},

	clean  => { FILES    => q|CPAN-PackageDetails-* t/test_output| },
	);
