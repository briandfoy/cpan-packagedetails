package CPAN::PackageDetails::Entries;
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.21_03';

use Carp;

sub DESTROY { }

=head1 NAME

CPAN::PackageDetails::Entries - Handle the collections of records of 02packages.details.txt.gz

=head1 SYNOPSIS

Used internally by CPAN::PackageDetails
	
=head1 DESCRIPTION

=head2 Methods

=over 4

=item new

Creates a new Entries object. This doesn't do anything fancy. To add
to it, use C<add_entry>.

	entry_class => the class to use for each entry object
	columns     => the column names, in order that you want them in the output

If you specify the C<allow_packages_only_once> option with a true value
and you try to add that package twice, the object will die. See C<add_entry>.

=cut

sub new { 
	my( $class, %args ) = @_;
	
	my %hash = ( 
		entry_class              => 'CPAN::PackageDetails::Entry',
		allow_packages_only_once => 1,
		columns                  => [],
		entries                  => {},
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

Returns a list of the column names in the entry

=cut

sub columns { @{ $_[0]->{columns} } };

=item column_index_for( COLUMN )

Returns the list position of the named COLUMN.

=cut

sub column_index_for
	{
	my( $self, $column ) = @_;
	
	
	my $index = grep {  
		$self->{columns}[$_] eq $column
		} 0 .. @{ $self->columns };
		
	return unless defined $index;
	return $index;
	}
	
=item count

Returns the number of entries. This is not the same as the number of
lines that would show up in the F<02packages.details.txt> file since
this method counts duplicates as well. 

=cut

sub count 
	{ 
	my $self = shift;
	
	my $count = 0;
	foreach my $package ( keys %{ $self->{entries} } )
		{
		$count += keys %{ $self->{entries}{$package} };
		}
		
	return $count;
	}

=item entries

Returns the list of entries as an array reference.

=cut

sub entries { $_[0]->{entries} }

=item allow_packages_only_once( [ARG] )

=cut

sub allow_packages_only_once
	{	
	$_[0]->{allow_packages_only_once} = $_[1] if defined $_[1];
	
	$_[0]->{allow_packages_only_once};
	}
	
=item add_entry

Add an entry to the collection. Call this on the C<CPAN::PackageDetails>
object and it will take care of finding the right handler.

If you've set C<allow_packages_only_once> to a true value (which is the
default, too), C<add_entry> will die if you try to add another entry with
the same package name even if it has a different or greater version. You can
set this to a false value and add as many entries as you like then use
C<as_unqiue_sorted_list> to get just the entries with the highest 
versions for each package.

=cut

sub add_entry
	{
	my( $self, %args ) = @_;

	$self->_mark_as_dirty;
	
	# The column name has a space in it, but that looks weird in a 
	# hash constructor and I keep doing it wrong. If I type "package_name"
	# I'll just make it work.
	if( exists $args{package_name} )
		{
		$args{'package name'} = $args{package_name};
		delete $args{package_name};
		}
	
	$args{'version'} = 'undef' unless defined $args{'version'};
	
	unless( defined $args{'package name'} )
		{
		carp "No 'package name' parameter!";
		return;
		}
		
	if( $self->allow_packages_only_once and $self->already_added( $args{'package name'} ) )
		{
		croak "$args{'package name'} was already added to CPAN::PackageDetails!";
		return;
		}
	
	# should check for allowed columns here
	$self->{entries}{
		$args{'package name'}
		}{$args{'version'}
			} = $self->entry_class->new( %args );
	}

sub _mark_as_dirty
	{
	delete $_[0]->{sorted};
	}

=item already_added( PACKAGE )

Returns true if there is already an entry for PACKAGE.

=cut

sub already_added { exists $_[0]->{entries}{$_[1]} }

=item as_string

Returns a text version of the Entries object. This calls C<as_string>
on each Entry object, and concatenates the results for all Entry objects.

=cut

sub as_string
	{
	my( $self ) = @_;
	
	my $string;
	
	my( $return ) = $self->as_unique_sorted_list;
	
	foreach my $entry ( @$return )
		{
		$string .= $entry->as_string( $self->columns );
		}
	
	$string || '';
	}

=item as_unique_sorted_list

In list context, this returns a list of entries sorted by package name
and version. Each package exists exactly once in the list and with the
largest version number seen.

In scalar context this returns the count of the number of unique entries.

Once called, it caches its result until you add more entries.

=cut

sub as_unique_sorted_list
	{
	my( $self ) = @_;

	unless( ref $self->{sorted} eq ref [] )
		{
		$self->{sorted} = [];
		
		my %Seen;

		my( $k1, $k2 ) = ( $self->columns )[0,1];

		my $e = $self->entries;
		
	# We only want the latest versions of everything:
		foreach my $package ( sort keys %$e )
			{
			my $entries = $e->{$package};
			require version;
			my( $highest_version ) =
				sort { version->parse($b) <=> version->parse($a) }
				keys %$entries;

			push @{ $self->{sorted} }, $entries->{$highest_version};
			}
		}
	
	my $return = wantarray ? 
		$self->{sorted} 
			:
		scalar  @{ $self->{sorted} };
	
	return $return;
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

