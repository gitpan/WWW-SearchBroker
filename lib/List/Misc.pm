# List::Misc
# Miscellaneous functions for managing lists/arrays in a consistent way
# whether they are single-value scalars or real lists.
#
# $Id: Misc.pm,v 0.1 2003/07/02 07:40:05 nate Exp nate $

=head1 NAME

List::Misc - Miscellaneous functions for managing lists/arrays

=head1 SYNOPSIS

	use List::Misc;
	my @array = all_values(@foo);
	my $scalar = first_value(@foo);

=head1 DESCRIPTION

Miscellaneous functions for managing lists/arrays in a consistent
way whether they are single-value scalars or real lists.

=cut

package List::Misc;
use strict;
use warnings;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Exporter;
our $VERSION = sprintf("%d.%02d", q$Revision: 0.1 $ =~ /(\d+)\.(\d+)/);
@ISA = qw(Exporter);

@EXPORT_OK = qw (all_values first_value);

sub all_values {
    my ($scalar) = shift;
    if (!defined($scalar)) {
        return ();
    }
    if (ref($scalar) eq 'ARRAY') {
        return @{$scalar};
    }
    elsif (ref($scalar) eq 'HASH') {
        return %{$scalar};
    }
    else {
        return ($scalar);
    }
} # all_values()

sub first_value {
    my ($scalar) = shift;
    if (ref($scalar) eq 'ARRAY') {
        return $scalar->[0];
    }
    else {
        return $scalar;
    }
} # first_value()

###########################################################################

=head1 AUTHOR

Andrew Creer
Nathan Bailey, E<lt>nate@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2000-2003 Nathan Bailey.  All rights reserved.  This module
is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any later
version.

=cut

1;

__END__
