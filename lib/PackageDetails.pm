# $Id$
package CPAN::PackageDetails;
use strict;

use warnings;
no warnings;

use subs qw();
use vars qw($VERSION);

$VERSION = '0.10_01';

=head1 NAME

CPAN::PackageDetails - Create or read 02.packages.details.txt.gz

=head1 SYNOPSIS

	use CPAN::PackageDetails;

	# read an existing file #####################
	my $package_details = CPAN::PackageDetails->read( $filename );
	
	my $creator    = $package_details->creator;  # See CPAN::PackageDetails::Header too
	my $count      = $package_details->lines;
	
	my $records    = $package_details->entries;
	
	foreach my $record ( @$records )
		{
		# See CPAN::PackageDetails::Entry too
		print join "\t", map { $record->$_() } qw(package_name version path)
		}
		
	# not yet implemented, but would be really, really cool eh?
	my $records    = $package_details->entries(
		logic   => 'OR',  # but that could be AND, which is the default
		package => qr/^Test::/, # or a string
		author  => 'OVID',      # case insenstive
		path    => 
		)
	
	# create a new file #####################
	my $package_details = CPAN::PackageDetails->new( 
		file         => "02.packages.details.txt",
		url          => "http://example.com/MyCPAN/modules/02.packages.details.txt",
		description  => "Package names for my private CPAN",
		columns      => "package name, version, path",
		intended_for => "My private CPAN",
		written_by   => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
		last-updated => $epoch_time,
		);

	$package_details->add_entry(
		package_name => $package,
		version      => $package->VERSION;
		path         => $path,
		);
		
	print "About to write ", $package_details->lines;
	my $big_string = $package_details->as_string;
	
	$package_details->write_file;
	
=head1 DESCRIPTION

CPAN uses an index file, 02.packages.details.txt.gz, to map package names to 
distribution files. Using this module, you can get a data structure of that
file, or create your own.

There are two parts to the 02.packages.details.txt.gz: a header and the index

=over 4

=cut

=item new

Create a new 02.packages.details.txt.gz file. 

=cut

sub new
	{
	my( $class, %args ) = @_;

	my $self = bless {}, $class;
	
	$self->init( %args )
	}
	
=item init

=cut

BEGIN {
my %defaults = (
	file         => "02.packages.details.txt",
	url          => "http://example.com/MyCPAN/modules/02.packages.details.txt",
	description  => "Package names for my private CPAN",
	columns      => "package name, version, path",
	intended_for => "My private CPAN",
	written_by   => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
	last_updated => $epoch_time,
	);
	
sub default_header_fields { keys %defaults }

sub init
	{
	my( $self, %args ) = @_;

	# we'll delegate everything, but also try to hide the mess from the user
	$self->{header_class}  = $args->{header_class}  || 'CPAN::PackageDetails::Header';
	$self->{entries_class} = $args->{entries_class} || 'CPAN::PackageDetails::Entries';
	$self->{entry_class}   = $args->{entry_class}   || 'CPAN::PackageDetails::Entry';
	
	$self->{header}  = bless {}, $self->header_class;
	$self=>{entries} = bless [], $self->entries_class;
	
	my %config = ( %defaults, %args );
	
	foreach my $key ( keys %config )
		{
		$self->header->add_header_field( $key, $config{$key} );
		}
		
	
	}
	
}

=item read( FILE )

Read an existing 02.packages.details.txt.gz file.

=cut

sub read
	{
	my( $class, $file ) = @_;
	
	open my($fh), "<", $file or do {
		carp "Could not open $file: $!"
		return;
		}
	
	my $self = $class->_parse( $fh );
	
	$self;	
	}
	
sub _parse
	{
	my( $class, $fh ) = @_;

	my $package_details = $class->new;
		
	while( <$fh> ) # header processing
		{
		my( $field, $value ) = split /\s*:\s*/, $_, 2;
		carp "Unknown field value [$field] at line $.! Skipping..."
			unless ...;
		$package_details->add_header( $field, $value );
		last if /^\s*$/;
		}
		
	my @columns = $package_details->columns;
	while( <$fh> ) # entry processing
		{
		my @values = split; # this could be in any order based on columns field.
		$package_details->add_entry( 
			map { $column[$_], $values[$_] } 0 .. $#columns
			)
		}
	
	$package_details;	
	}
	
sub header { $_[0]->{header} }

sub add_header
	{
	my( $self, $field, $value ) = @_;
		
	$self->header->add_header( $field, $value );
	}

sub CPAN::PackageDetails::Header::add_header
	{
	my( $self, $field, $value ) = @_;

	$self->{$field} = $value;
	}
	
=head2 Entries

An entry is a single line from 02.packages.details.txt that maps a
package name to a source. It's a whitespace-separated list that
has the values for the column identified in the "columns" field
in the header.

By default, there are three columns: package name, version, and path.

Inside a CPAN::PackageDetails object, the actual work and 
manipulation of the entries are handled by delegate classes specified
in C<entries_class> and C<entry_class>). At the moment these are
immutable, so you'd have to subclass this module to change them.

=over

=item entries_class

Returns the class to use for the entries collection, which is 
C<CPAN::PackageDetails::Entries> by default. Anything that
wants to work with the entries as a whole should do it through
this class's interface. This is a hook for subclasses, and you
don't need to fool with it for the common cases since most of
this is implementation rather than interface.

=cut

sub entries_class { $_[0]->{entries_class} }

=item entry_class

Returns the class to use for a single entry, which is 
C<CPAN::PackageDetails::Entry> by default. Anything that
wants to work with an entry as a whole should do it through
this class's interface. This is a hook for subclasses, and you
don't need to fool with it for the common cases since most of
this is implementation rather than interface.

=cut

sub entry_class { $_[0]->{entry_class} }

sub entries { $_[0]->{entries} }

sub add_entry
	{
	my( $self, %args ) = @_;

	bless %args, $self->entry_class;

	$self->entries->add = $value;

	}
	
=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github

=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
