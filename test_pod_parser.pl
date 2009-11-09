#!/usr/bin/perl

use strict;
use warnings;

=for command

just some random pod in the middle of the file...

=cut

use File::Slurp qw( read_file );
use Data::Dumper qw( Dumper );
use SRS::Pod::Parser qw( parse_pod_from_string );

# for each file, parse out the pod, then insert it back into the 
# stripped version and assert they're the same.
for my $file ( @ARGV ) {
    my $text = read_file( $file );
    my ( $pod_paragraphs, $stripped_text ) = parse_pod_from_string( $text );

    #print Dumper $pod_paragraphs;
    print $stripped_text;

    substr( $stripped_text, $_->{start_pos}, 0, $_->{orig_pod} ) 
        for @$pod_paragraphs;

    print $stripped_text eq $text ? "ok\n" : "not ok\n";
}


__END__

=head1 POD TERMINOLOGY

=head2 paragraph

In Pod, everything is a paragraph. A paragraph is simply one or more
consecutive lines of text. Multiple paragraphs are separated from each other
by one or more blank lines.

Some paragraphs have special meanings, as explained below.

=head2 command

A command (aka directive) is a paragraph whose first line begins with a
character sequence matching the regex m/\A=([a-zA-Z]\S*)/

In the above regex, the type of command would be in $1. Different types of
commands have different semantics and validation rules yadda yadda.

Currently, the following command types (directives) are described in the
Pod Spec L<http://perldoc.perl.org/perlpodspec.html> and technically,
a proper Pod parser should consider anything else an error. (I won't though)

=over

=item * head[\d] (\d is a number from 1-4)

=item * pod

=item * cut

=item * over

=item * item

=item * back

=item * begin

=item * end

=item * for

=item * encoding

=back

=head2 directive

Ostensibly a synonym for a command paragraph, I consider it a subset of that,
specifically the "command type" as described above.

=head2 verbatim paragraph

This is a paragraph where each line begins with whitespace.

=head2 ordinary paragraph

This is a prargraph where each line does B<not> begin with whitespace

=head2 data paragraph

This is a paragraph that is between a pair of "=begin identifier" ...
"=end identifier" directives where "identifier" does not begin with a
literal colon (":")

I do not plan on handling this type of paragraph in any special way.

=head2 block

A Pod block is a series of paragraphs beginning with any directive except
"=cut" and ending with the first occurence of a "=cut" directive or the
end of the input, whichever comes first.

=head2 section

This is a term I'm introducting myself. A Pod section is a piece of a
Pod block beginning at a directive and continuing until just before the next
directive or the end of the input.

=head1 NOTES

need to map out what the corresponding "end" command is for any "beginning"
command. for example, =cut is *always* an end command - for parsing, but
not necessarily for the current level of command nesting.

Best strategy may be to extract all POD from the file *then* figure
out the structure of the POD as a separate document



