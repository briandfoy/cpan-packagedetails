#!perl
use strict;
use warnings;

use App::Module::Lister;
use Data::Dumper;
use File::Find;

my $Max_modules = $ARGV[0] || 3000;

logger_init();
logger( 'Loading package' );

require CPAN::PackageDetails;

logger( 'Loaded package' );

logger( 'Making object' );

my $package_details = CPAN::PackageDetails->new(
   file         => "02packages.details.txt",
   url          => "http://example.com/MyCPAN/modules/02packages.details.txt",
   description  => "Package names for my private CPAN",
   columns      => "package name, version, path",
   intended_for => "My private CPAN",
   written_by   => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
   last_updated => CPAN::PackageDetails->format_date,
   );
die "Could not create object!\n" unless ref $package_details;

logger( 'Object created' );

logger( "Adding $Max_modules" );

my $count = 0;
foreach my $tuple ( make_module_list() )
	{
	my( $module, $version, $path ) = @$tuple;
	
	$package_details->add_entry(
	   package_name => $module,
	   version      => $version,
	   path         => $path,
	   );

	foreach my $fake_version ( qw(9.87 5.43 9.99) )
		{
		$package_details->add_entry(
		   package_name => $module,
		   version      => $fake_version,
		   path         => $path . "/$fake_version",
		   );
		}
		
	last if $count++ >= $Max_modules;
	}

logger( 'Added modules. Entry count is ' . $package_details->count );

logger( 'Creating package file as string' );

open my( $string_fh ), '>', \ my $string;
$package_details->write_fh( $string_fh );

logger( 'Created package file as string' );

logger( 'Writing package file to devnull' );

$package_details->write_file( File::Spec->devnull );

logger( 'Wrote package file to devnull' );

logger( 'Writing package file to real file' );

$package_details->write_file( '02package.details.txt.gz' );

logger( 'Wrote package file to real file' );

logger( 'Ending run' );

sub make_module_list 
	{
	my $fh = shift || \*STDOUT;
	
	my( $wanted, $reporter, $clear ) = App::Module::Lister::generator();
	
	my @modules;
	
	foreach my $inc ( @INC )
		{		
		find( { wanted => $wanted }, $inc );
		push @modules, App::Module::Lister::as_tuples( $reporter, $inc );
		$clear->();
		}
		
	@modules;
	}
	
	
sub logger_init
	{
	printf "%6s  %6s  %s\n", qw(Total Split Message);
	print "-" x 60, "\n";
	}

BEGIN {
my $last = $^T;

sub logger
	{
	printf "%6d  %6d  %s\n", time - $^T, time - $last, $_[0];
	$last = time;
	}
}
