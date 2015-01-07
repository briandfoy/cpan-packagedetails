require 5.008;
use strict;
use warnings;


my $github    = 'https://github.com/briandfoy/';
my $main_file = 'lib/';

my %WriteMakefile = (
	'NAME'	       => 'CPAN::PackageDetails',
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM' => 'lib/CPAN/PackageDetails.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker' => '6.64',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '0.94',
		},

	'PREREQ_PM'     => {
		},

	'META_MERGE' => {
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				type => 'git',
				url  => "$github.git",
				web  => $github,
				},
			bugtraker => {
				web    => "$github/issues",
				},
			homepage => $github,
			},
		},
	'PREREQ_PM'    => {
		'CPAN::DistnameInfo'     => '0',
#		'DBM::Deep'              => '0',
		'Test::More'             => '0',
		'Test::Output'           => '0.10',
		'IO::Compress::Gzip'     => '0',
		'IO::Uncompress::Gunzip' => '0',
		'version'                => '0.78',
		},

	'META_MERGE'   => {
		'meta-spec' => { version => '2' },
		'resources' => {
			'repository' => {
				type => 'git',
				web  => 'https://github.com/briandfoy/cpan-packagedetails',
				url  => 'git@github.com:briandfoy/cpan-packagedetails.git',
				},
			},
		},

	clean  => { FILES    => q|CPAN-PackageDetails-* t/test_output| },
	);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			//
		"$MM 6.64";
	eval "use $MM_version";
	eval "use Test::Manifest 1.21" 
		if -e File::Spec->catfile( qw(t test_manifest) );
	WriteMakefile( %WriteMakefile );
	}


no warnings;
__PACKAGE__;
