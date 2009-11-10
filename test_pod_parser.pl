#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp qw( read_file );
use Data::Dumper qw( Dumper );
use Pod::Simplest qw( parse_string );

# for each file, parse out the pod, then insert it back into the 
# stripped version and assert they're the same.
for my $file ( @ARGV ) {
    my $text = read_file( $file );
    my ( $pieces, $stripped_text ) = parse_string( $text );

    print Dumper $pieces;
#    print $stripped_text;

    # put the pod back in the stripped text, just to test...
    substr( $stripped_text, $_->{start_pos}, 0, $_->{orig_txt} ) 
        for grep { ! exists $_->{non_pod} } @$pieces;

    print $stripped_text eq $text ? "ok - $file\n" : "not ok - $file\n";
}


