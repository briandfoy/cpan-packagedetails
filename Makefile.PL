# $Id: Makefile.PL,v 1.4 2004/07/04 17:04:17 comdog Exp $
use ExtUtils::MakeMaker;

require 5.006;

eval "use Test::Manifest 1.14";

WriteMakefile(
	'NAME'	       => 'CPAN::PackageDetails',
	'ABSTRACT'     => 'This is what the module does',
	'VERSION_FROM' => 'lib/PackageDetails.pm',
	'LICENSE'      => 'perl',
	'AUTHOR'       => 'brian d foy <bdfoy@cpan.org>',
	
	'PREREQ_PM'    => { 
		'Test::More' => '0',
		},

	'PM'           => {
		'lib/PackageDetails.pm'         => '$(INST_LIBDIR)/PackageDetails.pm',
		},

	'MAN3PODS'     => {
		'lib/PackageDetails.pm' => '$(INST_MAN3DIR)/CPAN::PackageDetails.3',
		},

	clean  => { FILES    => q|CPAN-PackageDetails-*| },

	);
