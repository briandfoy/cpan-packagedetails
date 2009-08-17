#!perl
use strict;
use warnings;

use Module::Build;

my $class = do {
	if( eval "use Test::Manifest 2.00; 1" ) {
		Test::Manifest->get_module_build_subclass;
		}
	else {
		'Module::Build';
		}
	};
	
my $build = $class->new(
	module_name       => 'CPAN::PackageDetails',
	dist_abstract     => 'Create or read 02packages.details.txt.gz',
	dist_version_from => 'lib/PackageDetails.pm',
	license           => 'perl',
	dist_author       => 'brian d foy <bdfoy@cpan.org>',

	recommends => {
		'Test::Manifest'         => '1.23',
		},
		
	build_requires => {
		'Test::More'             => '0',
		'Test::Output'           => '0.10',
		},
		
	requires       => {
		'perl'                   => '5.008',
		'IO::Compress::Gzip'     => '0',
		'IO::Uncompress::Gunzip' => '0',
		},

	pm_files        => {
		'lib/PackageDetails.pm' => 'lib/CPAN/PackageDetails.pm',
		},

	add_to_cleanup  => [ qw|CPAN-PackageDetails-* t/test_output| ], 
	);

$build->create_build_script;
