# Mild override to hack in fenced code support
package Plerd::Markdown;
use Modern::Perl '2018';

use base ( 'Text::MultiMarkdown' );

sub _Markdown {
    my ( $self, $text ) = @_;

    # This takes priority. Unclear if MMD metadata ever effects code blocks like this.
    $text       = $self->_DoFencedCodeBlocks( $text );
    return $self->SUPER::_Markdown( $text );
}

sub _DoFencedCodeBlocks {
    my ( $self, $text ) = @_;
    return unless $text;

    my @out;
    my $in_fence = 0;
    my $in_fence_token;
    my $in_fence_lang;
    my @fenced_lines;

    my @lines = split( /\r?\n/, $text );
    for my $line ( @lines ) {
        if ( $in_fence ) {
            if ( $line eq $in_fence_token ) {

                # Process like Text::Markdown::_DoCodeBlocks;
                my $codeblock = join( "\n", @fenced_lines );
                $codeblock = $self->_Detab( $self->_Outdent( $codeblock ) );
                $codeblock =~ s/\A\n+//;
                $codeblock =~ s/\n+\z//;
                push @out,
                    sprintf(
                    qq[<pre><code class="%s">%s</code></pre>\n],
                    ( defined $in_fence_lang ? $in_fence_lang : "plaintext" ),
                    $codeblock );
                $in_fence     = 0;
                @fenced_lines = ();
                undef( $in_fence_token );
                undef( $in_fence_lang );
            } else {
                push @fenced_lines, $line;
            }
        } elsif ( $line =~ /^([`]{3,5})(\w*)$/ ) {
            $in_fence       = 1;
            $in_fence_token = $1;
            if ( $2 ) {
                $in_fence_lang = $2;
            }
            next;
        } else {
            push @out, $line;
        }
    }

    return join( "\n", @out );
}


1;
