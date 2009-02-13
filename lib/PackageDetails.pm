package CPAN::PackageDetails;
use strict;

use warnings;
no warnings;

use subs qw();
use vars qw($VERSION);

use Carp;

BEGIN { 
	$VERSION = '0.17_02' 
	}; # needed right away to set defaults at compile-time

=head1 NAME

CPAN::PackageDetails - Create or read 02packages.details.txt.gz

=head1 SYNOPSIS

	use CPAN::PackageDetails;

	# read an existing file #####################
	my $package_details = CPAN::PackageDetails->read( $filename );
	
	my $count      = $package_details->count;
	
	my $records    = $package_details->entries;
	
	foreach my $record ( @$records )
		{
		# See CPAN::PackageDetails::Entry too
		print join "\t", map { $record->$_() } ('package name', 'version', 'path')
		print join "\t", map { $record->$_() } $package_details->columns_as_list;
		}
		
	# not yet implemented, but would be really, really cool eh?
	my $records    = $package_details->entries(
		logic   => 'OR',  # but that could be AND, which is the default
		package => qr/^Test::/, # or a string
		author  => 'OVID',      # case insenstive
		path    =>  qr/foo/,
		);
	
	# create a new file #####################
	my $package_details = CPAN::PackageDetails->new( 
		file         => "02packages.details.txt",
		url          => "http://example.com/MyCPAN/modules/02packages.details.txt",
		description  => "Package names for my private CPAN",
		columns      => "package name, version, path",
		intended_for => "My private CPAN",
		written_by   => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
		last_updated => CPAN::PackageDetails->format_date,
		);

	$package_details->add_entry(
		package_name => $package,
		version      => $package->VERSION;
		path         => $path,
		);
		
	print "About to write ", $package_details->count, " entries\n";
	my $big_string = $package_details->as_string;
	
	$package_details->write_file( $file );
	
	$package_details->write_fh( \*STDOUT )
	
=head1 DESCRIPTION

CPAN uses an index file, 02packages.details.txt.gz, to map package names to
distribution files. Using this module, you can get a data structure of that
file, or create your own.

There are two parts to the 02packages.details.txt.gz: a header and the index.
This module uses a top-level C<CPAN::PackageDetails> object to control
everything and comprise an C<CPAN::PackageDetails::Header> and
C<CPAN::PackageDetails::Entries> object. The C<CPAN::PackageDetails::Entries>
object is a collection of C<CPAN::PackageDetails::Entry> objects.

For the most common uses, you don't need to worry about the insides
of what class is doing what. You'll call most of the methods on
the top-level  C<CPAN::PackageDetails> object and it will make sure
that it gets to the right place.

=head2 Methods in CPAN::PackageDetails.

These methods are in the top-level object, and there are more methods
for this class in the sections that cover the Header, Entries, and
Entry objects.

=over 4

=item new

Create a new 02packages.details.txt.gz file. The C<default_headers>
method shows you which values you can pass to C<new>. For instance:

	my $package_details = CPAN::PackageDetails->new(
		url     => $url,
		columns => 'author, package name, version, path',
		)

=cut

sub new
	{
	my( $class, %args ) = @_;

	my $self = bless {}, $class;
	
	$self->init( %args );
	
	$self;
	}
	
=item init

Sets up the object. C<new> calls this automatically for you.

=item default_headers

Returns the hash of header fields and their default values:

	file            "02packages.details.txt"
	url             "http://example.com/MyCPAN/modules/02packages.details.txt"
	description     "Package names for my private CPAN"
	columns         "package name, version, path"
	intended_for    "My private CPAN"
	written_by      "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION"
	last_updated    format_date()

In the header, these fields show up with the underscores turned into hyphens,
and the letters at the beginning or after a hyphen are uppercase.

=item format_date

Write the date in PAUSE format. For example:

	Thu, 23 Oct 2008 02:27:36 GMT
	
=cut

sub format_date 
	{ 
	my( $second, $minute, $hour, $date, $monnum, $year, $wday )  = gmtime;
	$year += 1900;

	my $day   = ( qw(Sun Mon Tue Wed Thu Fri Sat) )[$wday];
	my $month = ( qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) )[$monnum];

	sprintf "%s, %02d %s %4d %02d:%02d:%02d GMT",
		$day, $date, $month, $year, $hour, $minute, $second;
	}


BEGIN {
my %defaults = (
	file            => "02packages.details.txt",
	url             => "http://example.com/MyCPAN/modules/02packages.details.txt",
	description     => "Package names for my private CPAN",
	columns         => "package name, version, path",
	intended_for    => "My private CPAN",
	written_by      => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",
	last_updated    => __PACKAGE__->format_date,
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
		header  => { map { $_, 1 } qw(get_header set_header header_exists columns_as_list) },
		entries => { map { $_, 1 } qw(add_entry count) },
	#	entry   => { map { $_, 1 } qw() },
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
	
	$self->{entries} = $self->entries_class->new(
		entry_class => $self->entry_class,
		columns     => [ split /,\s+/, $config{columns} ],
		);

	$self->{header}  = $self->header_class->new(
		_entries => $self->entries,
		);
	
	foreach my $key ( keys %config )
		{
		$self->header->set_header( $key, $config{$key} );
		}
		
	}
	
}

=item read( FILE )

Read an existing 02packages.details.txt.gz file.

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
		
	require IO::Uncompress::Gunzip;

	my $fh = IO::Uncompress::Gunzip->new( $file ) or do {	
		carp "Could not open $file: $IO::Compress::Gunzip::GunzipError";
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

Formats the object as a string and writes it to the file named
in OUTPUT_FILE. It gzips the output.

C<write_file> carps and returns nothing if you pass it no arguments 
or it cannot open OUTPUT_FILE for writing.

=cut

sub write_file
	{
	my( $self, $output_file ) = @_;

	unless( defined $output_file )
		{
		carp "Missing argument!";
		return;
		}
	
	require IO::Compress::Gzip;
	
	my $fh = IO::Compress::Gzip->new( $output_file ) or do {
		carp "Could not open $output_file for writing: $IO::Compress::Gzip::GzipError";
		return;
		};
	
	$self->write_fh( $fh );
	}

=item write_fh( FILEHANDLE )

Formats the object as a string and writes it to FILEHANDLE

=cut

sub write_fh
	{
	my( $self, $fh ) = @_;
	
	print $fh $self->header->as_string, $self->entries->as_string;
	}
	
sub DESTROY {}

=back

=head2 Headers

The 02packages.details.txt.gz header is a short preamble that give information
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

=head3 Methods in CPAN::PackageDetails

=over 4

=item header_class

Returns the class that C<CPAN::PackageDetails> uses to create
the header object.

=cut

sub header_class { $_[0]->{header_class} }

=item header

Returns the header object.

=cut
	
sub header { $_[0]->{header} }

=back

=head3 Methods in CPAN::PackageDetails::Header

=over 4

=cut

{
package CPAN::PackageDetails::Header;
use Carp;

sub DESTROY { }

=item new( HASH ) 

Create a new Header object. Unless you want a lot of work so you
get more control, just let C<CPAN::PackageDetails>'s C<new> or C<read>
handle this for you.

In most cases, you'll want to create the Entries object first then
pass a reference the the Entries object to C<new> since the header 
object needs to know how to get the count of the number of entries
so it can put it in the "Line-Count" header.

	CPAN::PackageDetails::Header->new(
		_entries => $entries_object,
		)

=cut

sub new { 
	my( $class, %args ) = @_;
	
	my %hash = ( 
		_entries => undef,
		%args
		);
			
	bless \%hash, $_[0] 
	}

=item set_header

Add an entry to the collection. Call this on the C<CPAN::PackageDetails>
object and it will take care of finding the right handler.

=cut

sub set_header
	{
	my( $self, $field, $value ) = @_;
	
	$self->{$field} = $value;
	}

=item header_exists( FIELD )

Returns true if the header has a field named FIELD, regardless of
its value.

=cut

sub header_exists 
	{
	my( $self, $field ) = @_;

	exists $self->{$field}
	}
	
=item get_header( FIELD )

Returns the value for the named header FIELD. Carps and returns nothing
if the named header is not in the object. This method is available from
the C<CPAN::PackageDetails> or C<CPAN::PackageDetails::Header> object:

	$package_details->get_header( 'url' );
	
	$package_details->header->get_header( 'url' );
	
The header names in the Perl code are in a different format than they
are in the file. See C<default_headers> for an explanation of the
difference.

For most headers, you can also use the header name as the method name:
	
	$package_details->header->url;

=cut

sub get_header 
	{
	my( $self, $field ) = @_;
	
	if( $self->header_exists( $field ) ) { $self->{$field} }
	else { carp "No such header as $field!"; return }
	}

=item columns_as_list

Returns the columns name as a list (rather than a comma-joined string). The
list is in the order of the columns in the output.

=cut

sub columns_as_list { split /,\s+/, $_[0]->{columns} }

sub _entries { $_[0]->{_entries} }

=item as_string

Return the header formatted as a string.

=cut

BEGIN {
my %internal_field_name_mapping = (
	url => 'URL',
	);
	
my %external_field_name_mapping = reverse %internal_field_name_mapping;

sub _internal_name_to_external_name
	{
	my( $self, $internal ) = @_;
	
	return $internal_field_name_mapping{$internal} 
		if exists $internal_field_name_mapping{$internal};
		
	(my $external = $internal) =~ s/_/-/g;
	$external =~ s/^(.)/ uc $1 /eg;
	$external =~ s/-(.)/ "-" . uc $1 /eg;
		
	return $external;
	}
	
sub _external_name_to_internal_name
	{
	my( $self, $external ) = @_;

	return $external_field_name_mapping{$external} 
		if exists $external_field_name_mapping{$external};
	
	(my $internal = $external) =~ s/-/_/g;

	lc $internal;
	}
	
sub as_string
	{
	my( $self, $line_count ) = @_;
	
	# XXX: need entry count
	my @lines;
	foreach my $field ( keys %$self )
		{
		next if substr( $field, 0, 1 ) eq '_';
		my $value = $self->get_header( $field );
		
		my $out_field = $self->_internal_name_to_external_name( $field );
		
		push @lines, "$out_field: $value";
		}
		
	push @lines, "Line-Count: " . $self->_entries->count;
	
	join "\n", sort( @lines ), "\n";
	}
}

}

=back
	
=head2 Entries

Entries are the collection of the items describing the package details.
It comprises all of the Entry object. 

=head3 Methods is CPAN::PackageDetails

=over 4

=item entries_class

Returns the class to use for the Entries object.

To use a different Entries class, tell C<new> which class you want to use
by passing the C<entries_class> option:

	CPAN::PackageDetails->new(
		...,
		entries_class => $class,
		)

Note that you are responsible for loading the right class yourself.

=item count

Returns the number of entries.

This dispatches to the C<count> in CPAN::PackageDetails::Entries. These
are the same:

	$package_details->count;
	
	$package_details->entries->count;

=cut

sub entries_class { $_[0]->{entries_class} }

=item entries

Returns the entries object.

=cut

sub entries { $_[0]->{entries} }

=back

=head3 Methods is CPAN::PackageDetails::Entries

=over 4

=cut

{
package CPAN::PackageDetails::Entries;
use Carp;

sub DESTROY { }

=item new

Creates a new Entries object. This doesn't do anything fancy. To add
to it, use C<add_entry>.

	entry_class => the class to use for each entry object
	columns     => the column names, in order that you want them in the output
	
=cut

sub new { 
	my( $class, %args ) = @_;
	
	my %hash = ( 
		entry_class => 'CPAN::PackageDetails::Entry',
		columns     => [],
		entries     => [],
		%args
		);
		
	$hash{max_widths} = [ (0) x @{ $hash{columns} } ];
	
	bless \%hash, $_[0] 
	}

=item entry_class

Returns the class that Entries uses to make a new Entry object.

=cut

sub entry_class { $_[0]->{entry_class} }

=item columns

=cut

sub columns { @{ $_[0]->{columns} } };

=item count

Returns the number of entries.

=cut

sub count { scalar @{$_[0]->{entries}} }

=item entries

Returns an array reference of Entry objects.

=cut

sub entries { $_[0]->{entries} }

=item add_entry

Add an entry to the collection. Call this on the C<CPAN::PackageDetails>
object and it will take care of finding the right handler.

=cut

sub add_entry
	{
	my( $self, %args ) = @_;

	# The column name has a space in it, but that looks weird in a 
	# hash constructor and I keep doing it wrong. If I type "package_name"
	# I'll just make it work.
	if( exists $args{package_name} )
		{
		$args{'package name'} = $args{package_name};
		delete $args{package_name};
		}
		
	unless( defined $args{'package name'} )
		{
		carp "No 'package name' parameter!";
		return;
		}
		
	# should check for allowed columns here
	push @{ $self->{entries} }, $self->entry_class->new( %args );
	}
	
=item as_string

Returns a text version of the Entries object. This calls C<as_string>
on each Entry object, and concatenates the results for all Entry objects.

=cut

sub as_string
	{
	my( $self ) = @_;
	
	my $entries;
	my( $k1, $k2 ) = ( $self->columns )[0,1];
	
	my %Seen;
	foreach my $entry ( 
		grep { ! $Seen{ $_->{$k1} }++ }
		sort { $a->{$k1} cmp $b->{$k1} || $b->{$k2} <=> $a->{$k2} } 
		@{ $self->entries } 
		)
		{
		$entries .= $entry->as_string( $self->columns );
		}
	
	$entries || '';
	}

}

=back

=head2 Entry

An entry is a single line from 02packages.details.txt that maps a
package name to a source. It's a whitespace-separated list that
has the values for the column identified in the "columns" field
in the header.

By default, there are three columns: package name, version, and path.

Inside a CPAN::PackageDetails object, the actual work and 
manipulation of the entries are handled by delegate classes specified
in C<entries_class> and C<entry_class>). At the moment these are
immutable, so you'd have to subclass this module to change them.

=head3 Methods is CPAN::PackageDetails

=over 4

=item entry_class

Returns the class to use for each Entry object.

To use a different Entry class, tell C<new> which class you want to use
by passing the C<entry_class> option:

	CPAN::PackageDetails->new(
		...,
		entry_class => $class,
		)

Note that you are responsible for loading the right class yourself.

=cut

sub entry_class { $_[0]->{entry_class} }

=back

=head3 Methods in CPAN::PackageDetails::Entry

=over 4

=cut

{
package CPAN::PackageDetails::Entry;	
use Carp;

=item new( FIELD1 => VALUE1 [, FIELD2 => VALUE2] )

Create a new entry

=cut

sub new
	{
	my( $class, %args ) = @_;
	
	bless { %args }, $class
	}

=item as_string( @column_names )

Formats the Entry as text. It joins with whitespace the values for the 
column names you pass it. You get the newline automatically.

Any values that are not defined (or the empty string) turn into the
literal string 'undef' to preserve the columns in the output.

=cut

sub as_string
	{
	my( $self, @columns ) = @_;
	
	# can't check defined() because that let's the empty string through
	return join( "\t", 
		map { length $self->{$_} ? $self->{$_} : 'undef' } @columns 
		) . "\n";
	}	

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

Copyright (c) 2009, brian d foy, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
