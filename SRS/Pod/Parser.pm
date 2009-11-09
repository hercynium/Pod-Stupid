package SRS::Pod::Parser;

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp qw( croak );
use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw();
our @EXPORT_OK = qw( parse_pod_from_string );


=for comment

match the end of any pod paragraph (pp). I'm being generous by allowing
a pp to end by detecting another command pp with the lookahead thus not
enforcing the "must end with blank line" part of the spec.
=cut
my $pod_paragraph_end_qr = qr{ (?: [\n]{2,} | [\n]+(?= ^=\w+) | \z ) }msx;

=for comment

match a command paragraph. Note: the 'cut' directive is handled
specially because it signifies the end of a block of pod and the
spec states that it need not be followed by a blank line. If any
other directives should be parsed the same way, put them in the
qw() list below. Still, only 'cut' will end a block of pod.
=cut
my $cut_like_cmds_qr = join '|', qw( cut );
my $pod_command_qr = qr{
    (                        # capture everything as $1
      (?:
        ^[=]                   # start of pod command
        (?!$cut_like_cmds_qr)  # exclude cut, to be handled below
        (\w+?)                 # command type (directive) as $2
        (\d*)                  # optional command 'level' as $3
        (?:                      # optionally followed by...
          (?:
            [ \t]+ | \n            # blank space OR single newline
          )
          (.*?)                  # and 'command text' as $4
        )?
        $pod_paragraph_end_qr  # followed by paragraph end pattern
      )
      |                     # OR... special case for cut
      (?:                    # (and cut-like) commands...
        ^[=]                 # start of pod command
        ($cut_like_cmds_qr)  # capture command as $5
        (?:                  # if followed by...
          [ \t]+               # horizontal white space
          (.*?)                # and grab anything else as $6
          [\n]                 # up to the end of line
          |                   # OR
          [\n]                 # just the end of the line
        )
        [\n]?                 # and possibly one more newline
      )
    )
}msx;

=for comment

match a non-command paragraph. this only applies when
already within a pod block.
=cut
my $pod_paragraph_qr = qr{
    (               # grab everything as $1...
      (               # but just the paragraph contents as $2
        (?:
          ^[^=].*?$   # any lines that do not begin with =
        )+?           # until...
      )
      $pod_paragraph_end_qr  # two newlines or end of string
    )
}msx;

=head2 parse_pod_from_string

Given a string, parses for pod and, in scalar context, returns an AoH
describing each pod paragraph found, as well as any non-pod. In list context,
a copy of the original string with all pod stripped out is also returned.

 # typical usage
 my $pieces = parse_pod_from_string( $text );

 # to separate pod and non-pod
 my @pod_pieces     = grep { ! exists $_->{non_pod} } @$pieces;
 my @non_pod_pieces = grep {   exists $_->{non_pod} } @$pieces;

 # if you want a copy of the text sans pod...
 my ( $pieces, $txt_nopod ) = parse_pod_from_string( $text );

=cut
# NOTE: the 'c' modifiers on the regexes in this sub are *critical!* NO TOUCH!
sub parse_pod_from_string {
    my ( $text ) = @_;

    croak "missing \$text parameter" if ! defined $text;

    # collect the parsed pieces here:
    my @pod_pieces;

    # find the beginning of the next pod block in the text
    # (which, by definition, is any pod command)
    while ( $text =~ m{ \G (.*?) $pod_command_qr }msxgc ) {
        my $non_pod   = $1;
        my $cmd_type  = $3 || $6;
        my $cmd_level = $4 || '';
        my $cmd_text  = $5 || $7 || '';

        #print "COMMAND: [=$cmd_type$cmd_level $cmd_text]\n\n"; ### DEBUG

        # record the text that wasn't pod, if any
        push @pod_pieces, { 
            non_pod   => $non_pod,
            start_pos => $LAST_MATCH_START[1],
            end_pos   => $LAST_MATCH_END[1],
        } if $non_pod;

        # record the pod found
        push @pod_pieces, {
            cmd_type  => $cmd_type,
            cmd_level => $cmd_level,
            cmd_text  => $cmd_text,
            start_pos => $LAST_MATCH_START[2],
            end_pos   => $LAST_MATCH_END[2],
        };

        # cut *always* signifies the end of a block of pod
        next if $cmd_type eq 'cut';

        # look for paragraphs within the current pod block
        while ( $text =~ m{ \G $pod_paragraph_qr }msxgc ) {
            my $paragraph = $2;

            #print "PARAGRAPH: [$paragraph]\n\n"; ### DEBUG

            push @pod_pieces, {
                paragraph => $paragraph,
                start_pos => $LAST_MATCH_START[1],
                end_pos   => $LAST_MATCH_END[1],
            };
        }
    }

    # Take care of any remaining text in the string
    my $last_pos  = pos( $text );
    my $end_pos   = length( $text ) - 1;
    my $remainder = substr( $text, $last_pos );
    push @pod_pieces, { 
        non_pod   => $remainder,
        start_pos => $last_pos,
        end_pos   => $end_pos,
    } if $remainder;


    if ( wantarray ) {
        strip_pod_from_string( \$text, \@pod_pieces );
        return ( \@pod_pieces, $text );
    }
    return \@pod_pieces;
}


=head2 strip_pod_from_string

given a string or string ref, and (optionally) an array of pod pieces,
return a copy of the string with all pod stripped out and an AoH
containing the pod pieces. If passed a string ref, that string is
modified in-place. In any case you can still always get the stripped
string and the array of pod parts as return values.

  # most typical usage
  my $txt_nopod = strip_pod_from_string( $text );
  
  # pass in a ref to change string in-place...
  strip_pod_from_string( \$text );   # $text no longer contains any pod
  
  # if you need the pieces...
  my ( $txt_nopod, $pieces ) = strip_pod_from_string( $text );
  
  # if you already have the pod pieces...
  my $txt_nopod = strip_pod_from_string( $text, $pod_pieces );

=cut
sub strip_pod_from_string {
    my ( $text_ref, $pod_pieces ) = @_;

    croak "missing \$text_ref parameter" unless defined $text_ref;
    $text_ref = \$text_ref unless ref $text_ref;

    $pod_pieces = parse_pod_from_string( $$text_ref ) unless ref $pod_pieces;

    my $shrinkage = 0;
    for my $pp ( @$pod_pieces ) {
        
        next if defined $pp->{non_pod};

        my $length      = $pp->{end_pos}   - $pp->{start_pos};
        my $new_start   = $pp->{start_pos} - $shrinkage;
        $pp->{orig_pod} = substr( $$text_ref, $new_start, $length, '' );
        $shrinkage     += $length;
    }
    return $$text_ref, $pod_pieces;
}

1;


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

=head2 piece

This is a term I'm introducting myself. A piece is just a hash containing info
on a parsed piece of the original string. Each piece is either pod or not pod. 
If it's pod it describes the kind of pod. If it's not, it contains a 'non_pod' 
entry. All pieces also include the start and end offsets into the original 
string (starting at 0) as 'start_pos' and 'end_pos', respectively.


