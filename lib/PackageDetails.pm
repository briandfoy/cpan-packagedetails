package CPAN::PackageDetails;
use strict;

use warnings;
no warnings;

use subs qw();
use vars qw($VERSION);

use Carp;

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
		path    =>  qr/foo/,
		)
	
	# create a new file #####################
	my $package_details = CPAN::PackageDetails->new( 
		file         => "02.packages.details.txt",
		url          => "http://example.com/MyCPAN/modules/02.packages.details.txt",
		description  => "Package names for my private CPAN",
		columns      => "package name, version, path",
		intended_for => "My private CPAN",
		written_by   => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
		last_updated => $epoch_time,
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
	
	$self->init( %args );
	
	$self;
	}
	
=item init

=item default_headers

Returns the keys for the 
=cut

BEGIN {
my %defaults = (
	file            => "02packages.details.txt",
	url             => "http://example.com/MyCPAN/modules/02.packages.details.txt",
	description     => "Package names for my private CPAN",
	columns         => "package name, version, path",
	intended_for    => "My private CPAN",
	written_by      => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
	last_updated    => scalar localtime,
	header_class    => 'CPAN::PackageDetails::Header',
	entries_class   => 'CPAN::PackageDetails::Entries',
	entry_class     => 'CPAN::PackageDetails::Entry',
	);
	
sub default_headers
	{ 
	map { $_, $defaults{$_} } 
		grep ! /^_class/, keys %defaults 
	}

sub CPAN::PackageDetails::Header::can
	{
	my( $self, @methods ) = @_;
	
	my $class = ref $self || $self; # class or instance
	
	foreach my $method ( @methods )
		{
		next if 
			defined &{"${class}::$method"} || 
			$self->header_exists( $method );
		return 0;
		}
		
	return 1;
	}
	
sub CPAN::PackageDetails::Header::AUTOLOAD
	{
	my $self = shift;
	
	( my $method = $CPAN::PackageDetails::Header::AUTOLOAD ) =~ s/.*:://;
	
	carp "No such method as $method!" unless $self->can( $method );
	
	$self->get_header( $method );
	}

# These methods live in the top level and delegate interfaces
# so I need to intercept them at the top-level and redirect
# them to the right delegate
my %Dispatch = (
		header  => { map { $_, 1 } qw(set_header header_exists columns_as_list) },
		entries => { map { $_, 1 } qw(add_entry count) },
		entry   => { map { $_, 1 } qw() },
		);
		
my %Dispatchable = map { #inverts %Dispatch
	my $class = $_; 
	map { $_, $class } keys %{$Dispatch{$class}} 
	} keys %Dispatch;

sub CPAN::PackageDetails::can
	{
	my( $self, @methods ) = @_;

	my $class = ref $self || $self; # class or instance

	foreach my $method ( @methods )
		{
		next if 
			defined &{"${class}::$method"} || 
			exists $Dispatchable{$method}  ||
			$self->header_exists( $method );
		return 0;
		}

	return 1;
	}

sub CPAN::PackageDetails::AUTOLOAD
	{
	my $self = shift;
	
	our $AUTOLOAD;
	( my $method = $AUTOLOAD ) =~ s/.*:://;

	if( exists $Dispatchable{$method} )
		{
		my $delegate = $Dispatchable{$method};		
		return $self->$delegate()->$method(@_)
		}
	elsif( $self->header_exists( $method ) )
		{
		return $self->header->get_header( $method );
		}
	else
		{
		carp "No such method as $method!";
		return;
		}
	}
	
sub init
	{
	my( $self, %args ) = @_;

	my %config = ( %defaults, %args );

	# we'll delegate everything, but also try to hide the mess from the user
	foreach my $key ( map { "${_}_class" } qw(header entries entry) )
		{
		$self->{$key}  = $config{$key};
		delete $config{$key};
		}
	
	$self->{header}  = $self->header_class->new();
	$self->{entries} = $self->entries_class->new();
	
	foreach my $key ( keys %config )
		{
		$self->header->set_header( $key, $config{$key} );
		}
		
	}
	
}

=item read( FILE )

Read an existing 02.packages.details.txt.gz file.

While parsing, it modifies the field names to map them to Perly
identifiers. The field is lowercased, and then hyphens become
underscores. For instance:

	Written-By ---> written_by
	
=cut

sub read
	{
	my( $class, $file ) = @_;

	unless( defined $file )
		{
		carp "Missing argument!";
		return;
		}
		
	use PerlIO::gzip;
	
	open my($fh), "<:gzip", $file or do {
		carp "Could not open $file: $!";
		return;
		};
	
	my $self = $class->_parse( $fh );
	
	$self->{source_file} = $file;
	
	$self;	
	}
	
=item source_file

Returns the original file path for objects created through the
C<read> method.

=cut

sub source_file { $_[0]->{source_file} }

sub _parse
	{
	my( $class, $fh ) = @_;

	my $package_details = $class->new;
		
	while( <$fh> ) # header processing
		{
		chomp;
		my( $field, $value ) = split /\s*:\s*/, $_, 2;
		
		$field = lc $field;
		$field =~ tr/-/_/;
		
		carp "Unknown field value [$field] at line $.! Skipping..."
			unless 1; # XXX should there be field name restrictions?
		$package_details->set_header( $field, $value );
		last if /^\s*$/;
		}
	
	my @columns = $package_details->columns_as_list;
	while( <$fh> ) # entry processing
		{
		chomp;
		my @values = split; # this could be in any order based on columns field.
		$package_details->add_entry( 
			map { $columns[$_], $values[$_] } 0 .. $#columns
			)
		}
	
	$package_details;	
	}

=item write_file( OUTPUT_FILE )

=cut

sub write_file
	{
	my( $self, $output_file ) = @_;

	my( $class, $output_file ) = @_;

	unless( defined $output_file )
		{
		carp "Missing argument!";
		return;
		}

	use PerlIO::gzip;
		
	open my($fh), ">:gzip", $output_file
		or croak "Could not open $output_file for writing: $!";
	
	$self->write_fh( $fh );
	}

=item write_fh( FILEHANDLE )

=cut

sub write_fh
	{
	my( $self, $fh ) = @_;
	
	print $fh $self->header->as_string( $self->entries->count );
	print $fh $self->entries->as_string( $self->header->columns_as_list );
	
	return 1;
	}
	
sub DESTROY {}

=back

=head2 Headers

The 02.packages.details.txt.gz header is a short preamble that give information
about the creation of the file, its intended use, and the number of entries in
the file. It looks something like:

	File:         02packages.details.txt
	URL:          http://www.perl.com/CPAN/modules/02packages.details.txt
	Description:  Package names found in directory $CPAN/authors/id/
	Columns:      package name, version, path
	Intended-For: Automated fetch routines, namespace documentation.
	Written-By:   Id: mldistwatch.pm 1063 2008-09-23 05:23:57Z k 
	Line-Count:   59754
	Last-Updated: Thu, 23 Oct 2008 02:27:36 GMT

Note that there is a Columns field. This module tries to respect the ordering
of columns in there. The usual CPAN tools expect only three columns and in the
order in this example, but C<CPAN::PackageDetails> tries to handle any number
of columns in any order.

=cut

sub CPAN::PackageDetails::Header::DESTROY { }

sub CPAN::PackageDetails::Header::new { bless {}, $_[0] }
	
=over 4

=item header_class

=cut

sub header_class { $_[0]->{header_class} }

=item header

Returns the header object.

=cut
	
sub header { $_[0]->{header} }

=item set_header

Add an entry to the collection. Call this on the C<CPAN::PackageDetails>
object and it will take care of finding the right handler.

=cut

sub CPAN::PackageDetails::Header::set_header
	{
	my( $self, $field, $value ) = @_;

	$self->{$field} = $value;
	}

=item header_exists

=cut

sub CPAN::PackageDetails::Header::header_exists 
	{
	my( $self, $field ) = @_;
	exists $self->{$field}
	}
	
=item header_exists( FIELD )

Returns true if the header has a field named FIELD, regardless of
its value.

=cut

sub CPAN::PackageDetails::Header::get_header 
	{
	my( $self, $field ) = @_;
	
	if( $self->header_exists( $field ) ) { $self->{$field} }
	else { carp "No such header as $field!"; return }
	}

=item columns_as_list

=cut

sub CPAN::PackageDetails::Header::columns_as_list
	{
	my( $self ) = @_;
	
	split /,\s+/, $self->{columns};	
	}

=item as_string

=cut

sub CPAN::PackageDetails::Header::as_string
	{
	my( $self, $line_count ) = @_;
	
	# XXX: need entry count
	my @lines;
	foreach my $field ( keys %$self )
		{
		my $value = $self->get_header( $field );
		(my $out_field = $field ) =~ s/_/-/g;
		$out_field =~ s/^(.)/ uc $1 /eg;
		$out_field =~ s/-(.)/ "-" . uc $1 /eg;
		
		$out_field = 'URL' if $field =~ /URL/i;
		
		push @lines, "$out_field: $value";
		}
		
	push @lines, "Line-Count: $line_count";
	
	join "\n", sort( @lines ), "\n";
	}
	
=back
	
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

=cut

sub CPAN::PackageDetails::Entries::DESTROY { }

sub CPAN::PackageDetails::Entries::new { bless [], $_[0] }

sub CPAN::PackageDetails::Entries::count { scalar @{$_[0]} }

=over

=item new


=cut

sub CPAN::PackageDetails::Entry::new
	{
	my( $class, %args ) = @_;
	
	bless { %args }, $class
	}

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

=item entries

Returns the entries object.

=cut

sub entries { $_[0]->{entries} }

=item as_string

=cut

sub CPAN::PackageDetails::Entries::as_string
	{
	my( $self, @columns ) = @_;
	
	my $entries;
	
	foreach my $entry ( @{ $self } )
		{
		$entries .= $entry->as_string( @columns );
		}
	
	$entries;
	}
	
sub CPAN::PackageDetails::Entry::as_string
	{
	my( $self, @columns ) = @_;
	
	print STDERR "Columns are @columns\n";
	return join( "\t", map { $self->{$_} } @columns ) . "\n";
	}	
	
=item add_entry

Add an entry to the collection. Call this on the C<CPAN::PackageDetails>
object and it will take care of finding the right handler.

=cut

sub add_entry
	{
	my( $self, %args ) = @_;

	my $entry = $self->entry_class->new( %args );

	push @{ $self->entries }, $entry;
	}
	
=back

=head1 TO DO


=head1 SEE ALSO


=head1 SOURCE AVAILABILITY

This source is in Github:

	http://github.com/briandfoy/cpan-packagedetails
	
=head1 AUTHOR

brian d foy, C<< <bdfoy@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
