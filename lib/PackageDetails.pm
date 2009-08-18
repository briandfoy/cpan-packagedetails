package CPAN::PackageDetails;
use strict;
use warnings;

use subs qw();
use vars qw($VERSION);

use Carp qw(carp croak cluck confess);
use File::Basename;
use File::Spec::Functions;

BEGIN {
	$VERSION = '0.21_06';
	}

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
		allow_packages_only_once => 1,
		);

	$package_details->add_entry(
		package_name => $package,
		version      => $package->VERSION;
		path         => $path,
		);
		
	print "About to write ", $package_details->count, " entries\n";
	
	$package_details->write_file( $file );
	
	 # OR ...
	 
	$package_details->write_fh( \*STDOUT )
	
=head1 DESCRIPTION

CPAN uses an index file, F<02packages.details.txt.gz>, to map package names to
distribution files. Using this module, you can get a data structure of that
file, or create your own.

There are two parts to the F<02packages.details.txt.g>z: a header and the index.
This module uses a top-level C<CPAN::PackageDetails> object to control
everything and comprise an C<CPAN::PackageDetails::Header> and
C<CPAN::PackageDetails::Entries> object. The C<CPAN::PackageDetails::Entries>
object is a collection of C<CPAN::PackageDetails::Entry> objects.

For the most common uses, you don't need to worry about the insides
of what class is doing what. You'll call most of the methods on
the top-level  C<CPAN::PackageDetails> object and it will make sure
that it gets to the right place.

=head2 Methods

These methods are in the top-level object, and there are more methods
for this class in the sections that cover the Header, Entries, and
Entry objects.

=over 4

=item new

Create a new F<02packages.details.txt.gz> file. The C<default_headers>
method shows you which values you can pass to C<new>. For instance:

	my $package_details = CPAN::PackageDetails->new(
		url     => $url,
		columns => 'author, package name, version, path',
		)

If you specify the C<allow_packages_only_once> option with a true value
and you try to add that package twice, the object will die. See C<add_entry>.

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

=cut

BEGIN {
# These methods live in the top level and delegate interfaces
# so I need to intercept them at the top-level and redirect
# them to the right delegate
my %Dispatch = (
		header  => { map { $_, 1 } qw(default_headers get_header set_header header_exists columns_as_list) },
		entries => { map { $_, 1 } qw(add_entry count as_unique_sorted_list already_added allow_packages_only_once) },
	#	entry   => { map { $_, 1 } qw() },
		);
		
my %Dispatchable = map { #inverts %Dispatch
	my $class = $_; 
	map { $_, $class } keys %{$Dispatch{$class}} 
	} keys %Dispatch;

sub can
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

sub AUTOLOAD
	{
	my $self = shift;
	
	
	our $AUTOLOAD;
	carp "There are no AUTOLOADable class methods: $AUTOLOAD" unless ref $self;
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
}

BEGIN {
my %defaults = (
	file            => "02packages.details.txt",
	url             => "http://example.com/MyCPAN/modules/02packages.details.txt",
	description     => "Package names for my private CPAN",
	columns         => "package name, version, path",
	intended_for    => "My private CPAN",
	written_by      => "$0 using CPAN::PackageDetails $CPAN::PackageDetails::VERSION",

	header_class    => 'CPAN::PackageDetails::Header',
	entries_class   => 'CPAN::PackageDetails::Entries',
	entry_class     => 'CPAN::PackageDetails::Entry',

	allow_packages_only_once => 1,
	);
	
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
	
	foreach my $class ( map { $self->$_ } qw(header_class entries_class entry_class) )
		{
		eval "require $class";
		}
	
	$self->{entries} = $self->entries_class->new(
		entry_class              => $self->entry_class,
		columns                  => [ split /,\s+/, $config{columns} ],
		allow_packages_only_once => $config{allow_packages_only_once},
		);
	
	$self->{header}  = $self->header_class->new(
		_entries => $self->entries,
		);
	
	
	foreach my $key ( keys %config )
		{
		$self->header->set_header( $key, $config{$key} );
		}

	$self->header->set_header( 
		'last_updated', 
		$self->header->format_date 
		);
		
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

Formats the object as a string and writes it to a temporary file and
gzips the output. When everything is complete, it renames the temporary
file to its final name.

C<write_file> carps and returns nothing if you pass it no arguments, if 
it cannot open OUTPUT_FILE for writing, or if it cannot rename the file.

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
	
	my $fh = IO::Compress::Gzip->new( "$output_file.$$" ) or do {
		carp "Could not open $output_file.$$ for writing: $IO::Compress::Gzip::GzipError";
		return;
		};
	
	$self->write_fh( $fh );
	$fh->close;
	
	unless( rename "$output_file.$$", $output_file )
		{
		carp "Could not rename temporary file to $output_file!\n";
		return;
		}
		
	return 1;
	}

=item write_fh( FILEHANDLE )

Formats the object as a string and writes it to FILEHANDLE

=cut

sub write_fh
	{
	my( $self, $fh ) = @_;
	
	print $fh $self->header->as_string, $self->entries->as_string;
	}
	
=item check_file


=cut

sub check_file
	{
	my( $either, $file, $cpan_path ) = @_;

	# works with a class or an instance. We have to create a new
	# instance, so we need the class. However, I'm concerned about
	# subclasses, so if the higher level application just has the
	# object, and maybe from a class I don't know about, they should
	# be able to call this method and have it end up here if they
	# didn't override it. That is, don't encourage them to hard code 
	# a class name
	my $class = ref $either || $either;
	
	# file exists
	croak( "File [$file] does not exist!\n" ) unless -e $file;

	# file is gzipped

	# check header # # # # # # # # # # # # # # # # # # #
	my $packages = $class->read( $file );
	
	# count of entries in non-zero # # # # # # # # # # # # # # # # # # #
	my $header_count = $packages->get_header( 'line_count' );
	croak( "The header says there are no entries!\n" ) 
		if $header_count == 0;
		
	# count of lines matches # # # # # # # # # # # # # # # # # # #
	my $entries_count = $packages->count;

	croak( "Entry count mismatch? " .
		"The header says $header_count but there are only $entries_count records\n" )
		unless $header_count == $entries_count;

	# all listed distributions are in repo # # # # # # # # # # # # # # # # # # #
	my @missing;
	if( defined $cpan_path )
		{
		croak( "CPAN path [$cpan_path] does not exist!\n" ) unless -e $cpan_path;
		
		# this entries syntax really sucks
		my( $entries ) = $packages->as_unique_sorted_list;
		foreach my $entry ( @$entries )
			{
			my $path = $entry->path;
			
			my $native_path = catfile( $cpan_path, split m|/|, $path );
			
			push @missing, $path unless -e $native_path;
			}
			
		croak( 
			"Some paths in $file do not show up under $cpan_path\n" .
			join( "\n\t", @missing ) . "\n" 
			)
			if @missing;
			
		}

	# all repo distributions are listed # # # # # # # # # # # # # # # # # # #
	# the trick here is to not care about older versions
	if( defined $cpan_path )
		{
		croak( "CPAN path [$cpan_path] does not exist!\n" ) unless -e $cpan_path;
			
		my $dists = $class->_get_repo_dists( $cpan_path );
		
		$class->_filter_older_dists( $dists );
		
		my %files = map { $_, 1 } @$dists;
		
		my( $entries ) = $packages->as_unique_sorted_list;

		foreach my $entry ( @$entries )
			{
			my $path = $entry->path;
			
			my $native_path = catfile( $cpan_path, split m|/|, $path );
			
			delete $files{$native_path};
			}

		croak( 
			"Some paths in $cpan_path do not show up in $file\n" .
			join( "\n\t", keys %files ) . "\n" 
			)
			if keys %files;
		
		}
		
	return 1;
	}

sub _filter_older_dists
	{
	my( $self, $array ) = @_;

	require CPAN::DistnameInfo;
	
	my %Seen;
	my @order;
	
	foreach my $path ( @$array )
		{
		my( $basename, $directory, $suffix ) = fileparse( $path, qw(.tar.gz .tgz .zip .tar.bz2) );
		my( $name, $version, $developer ) = CPAN::DistnameInfo::distname_info( $basename );
		my $tuple = [ $path, $name, $version ];
		push @order, $name;
		
		   # first branch, haven't seen the distro yet
		   if( ! exists $Seen{ $name } )       { $Seen{ $name } = $tuple }
		   # second branch, the version we see now is greater than before
		elsif( $Seen{ $name }[2] < $version )  { $Seen{ $name } = $tuple }
		   # third branch, nothing. Really? Are you sure there's not another case?
		else                                   { () }
		}
		
	@$array = map { 
		if( exists $Seen{$_} )
			{
			my $dist = $Seen{$_}[0];
			delete $Seen{$_};
			$dist;
			}
		else
			{
			()
			}
		} @order;
	
	return 1;
	}
	
sub _get_repo_dists
	{	
	my( $self, $cpan_home ) = @_;
				   
	my @files = ();
	
	use File::Find;
	
	my $wanted = sub { 
		push @files, 
			File::Spec::Functions::canonpath( $File::Find::name ) 
				if m/\.(?:tar\.gz|tgz|zip)\z/ 
			};
	
	find( $wanted, $cpan_home );
	
	return \@files;
	}
        
sub DESTROY {}

=back


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
		);

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

sub _entries { $_[0]->{_entries} }

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
