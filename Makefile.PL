use ExtUtils::MakeMaker;

require 5.008;

eval "use Test::Manifest 1.23";

WriteMakefile(
	'NAME'	       => 'CPAN::PackageDetails',
	'ABSTRACT'     => "Create or read PAUSE's 02packages.details.txt.gz",
	'VERSION_FROM' => 'lib/CPAN/PackageDetails.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'PREREQ_PM'    => { 
		'CPAN::DistnameInfo'     => '0',
#		'DBM::Deep'              => '0',
		'Test::More'             => '0',
		'Test::Output'           => '0.10',
		'IO::Compress::Gzip'     => '0',
		'IO::Uncompress::Gunzip' => '0',
		'version'                => '0.78',
		},

	clean  => { FILES    => q|CPAN-PackageDetails-* t/test_output| },
	);
