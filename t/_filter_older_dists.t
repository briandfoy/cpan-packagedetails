#!perl
use strict;
use warnings;

use Test::More 'no_plan';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
my $class  = 'CPAN::PackageDetails';
my $method = '_filter_older_dists';

use_ok( $class );
can_ok( $class, $method );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
my @list = qw( 
	Foo-1.23.tgz 
	Foo-Bar-3.45.tgz 
	Bar-2.34.tgz 
	);

my @copy = @list;

$class->$method( \@copy );
is_deeply( \@copy, \@list, "Unique list has the same elements it started with" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
{
my @list = qw( 
	Foo-1.23.tgz
	Foo-1.22.tgz
	Foo-Bar-3.45.tgz 
	Bar-2.34.tgz 
	);

my @expected = qw( 
	Foo-1.23.tgz
	Foo-Bar-3.45.tgz 
	Bar-2.34.tgz 
	);

$class->$method( \@list );
is( scalar @list, scalar @expected, "Filtered list has the right length" );
is_deeply( \@list, \@expected );
}
