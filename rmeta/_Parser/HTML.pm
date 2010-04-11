use strict;
use warnings;

package Parser::HTML;
use HTML::Parser; # from CPAN
our @ISA = ("HTML::Parser");
use Data::Dumper;
use utf8;
use Encode;

sub new {
   my ($class, %args) = @_;
   die "Parser::HTML::new() requires content parameter" unless defined($args{content});
   $DB::single=2;
   my $self = $class->SUPER::new(api_version => 3);
   $self  = {
      %$self,
      error          => '',
      content        => $args{content},
      verbosity      => $args{verbosity} || 0,
      title          => '',
      abstract       => '',
      authors        => undef,
   };
   bless ($self, $class);
   return $self;
}

sub error {
   my $self = shift;
   if (@_) {
      $self->{error} = shift;
      return undef;
   }
   return $self->{error};
}

sub verbosity {
   my $self = shift;
   $self->{verbosity} = shift if (@_);
   return $self->{verbosity};
}

sub do_parse {
   my $self = shift;
   print "parsing HTML document\n" if $self->verbosity;
   $self->parse_body_blocks() or return undef;
   my %titleblock = $self->get_title_block() or return undef;
   my $title = strip_tags($titleblock{text});
   my %abstractblock = $self->get_abstract_block($titleblock{index}+1) or return undef;
   my $abstract = $abstractblock{text};
   if (length($abstract) > 2000) {
      $abstract = substr($abstract, 0, index($abstract, ' ', 2000)).'...';
   }
   my $authors = $self->get_authors($titleblock{index}+1, $abstractblock{index}-1);
   if (!@{$authors}) { $authors = $self->get_authors(0, $titleblock{index}-1); }

   return {
      title => $title,
      abstract => $abstract,
      authors => $authors
   };
}

sub parse_body_blocks {
   my $self = shift;
   print "\n\n=== parsing into blocks ===\n" if $self->verbosity;
   $self->{content} =~ s/\n\n/\n<p>\n/g; # text paragraphs normally don't contain blank lines in source
   my $index = 0;
   my %block;
   my $prevtag;
   $self->handler(start => sub {
      my $tagname = shift;
      if ($tagname =~ /br/) {
         $block{text} .= "\n";
         $tagname = 'p' if  ($prevtag =~ /br/); # treat <br><br> like <p>
      }
      if ($tagname =~ /^(h\d|p)$/) {
         endblock($self);
         %block = ( type => $tagname, text => '' );
      }
      $prevtag = $tagname;
   }, "tagname");
   $self->handler(end   => sub {
      my $tagname = shift;
      if ($tagname =~ /^(h\d|p)$/) {
         endblock($self);
      }
   }, "tagname");
   $self->handler(text  => sub {
      my $text = shift;
      if (!$block{type}) {
         %block = ( type => 'p', text => '' );
      }
      $block{text} .= $text;
   }, "dtext");
   local *endblock = sub {
      if ($block{text} && $block{text} =~ /\w/) {
         $self->{plaintext} .= $block{text};
         $block{text} =~ s/^\s+/ /;
         $block{text} =~ s/\s+$/ /;
         $block{index} = $index;
         push @{$self->{blocks}}, {%block};
         $index++;
         print "block $index\n   type: $block{type}\n   text: $block{text}\n\n" if $self->verbosity == 2;
      }
      %block = ();
   };
   $self->unbroken_text(1);
   $self->ignore_elements(qw(script style));
   $self->parse($self->{content});
   $self->eof();
   endblock($self);
   return $self->{blocks};
}

sub get_title_block {
   my $self = shift;
   print "\n\n=== scanning for title ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $titleblock = $blocks[0];
   print "\ninitial title: ".substr($titleblock->{text}, 0, 30) if $self->verbosity;
   foreach my $i (1 .. $#blocks) {
      if (length($blocks[$i]->{text}) > 500) {
         print "\nblock $i is too long for title: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity == 2;
         next;
      }
      if ($blocks[$i]->{type} gt $titleblock->{type}) { # hack: p > h6 > h5 > h4 > ...
         print "\nblock $i has lesser type: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity == 2;
         next;
      }
      if ($blocks[$i]->{type} lt $titleblock->{type}) {
         print "\nchanging title to block $i, larger: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity;
         $titleblock = $blocks[$i];
         next;
      }
      # same type size:
      # should make some comparisons of contained <b>, <font>, align values etc. here! xxx
   }
   return %{$titleblock};
}

sub get_abstract_block {
   my $self = shift;
   print "\n\n=== scanning for abstract ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $start_index = shift;
   my $abstractblock;
   my $first_par;
   foreach my $i ($start_index .. $#blocks) {
      next if ($blocks[$i]->{type} ne 'p');
      print "\nchecking for abstract in '".substr($blocks[$i]->{text},0,30)."'\n" if $self->verbosity == 2;
      if (length($blocks[$i]->{text}) < 300) {
         if ($blocks[$i]->{text} =~ /^.{0,3}abstract *[:<&]/i
             && length($blocks[$i+1]->{text}) > 200) {
            print "woo, block $i+1 follows abstract heading\n" if $self->verbosity;
            $abstractblock = $blocks[$i+1];
            last;
         }
         else {
            print "no, block is too short\n" if $self->verbosity == 2;
            next;
         }
      }
      if (index($blocks[$i]->{text}, '<sup>') == 0) {
         print "no, block seems to be a footnote\n" if $self->verbosity == 2;
         next;
      }
      if ($blocks[$i]->{text} =~ /^.{0,3}abstract *[:<&]/i) {
         print "woo, block $i begins with 'abstract'!\n" if $self->verbosity;
         $abstractblock = $blocks[$i];
         $blocks[$i]->{text} =~ s/^.{0,3}abstract *:? *(<..>)?//i;
         last;
      }
      if (!$first_par) { # store first paragraph:
         print "block $i is first paragraph\n" if $self->verbosity;
         $first_par = $blocks[$i];
      }
   }
   $abstractblock = $first_par if (!$abstractblock);
   if (!$abstractblock) {
      print "no abstract found! using last block\n" if $self->verbosity;
      $abstractblock = $blocks[-1];
   }
   return %{$abstractblock};
}

sub get_authors {
   my $self = shift;
   print "\n\n=== scanning for authors ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $start_index = shift;
   my $end_index = shift;
   print "\nsearching for authors between $start_index and $end_index of $#blocks\n" if $self->verbosity == 2;
   my @authors;
   my @bad_words = (
      'universit\w+', 'institute', 'department', 'college', 'center',
      'version', 'introduction',
      'new', ' city', ' france', 'santa cruz'
   );
   my $last_block_with_names = 0;
   foreach my $i ($start_index .. $end_index) {
      my @lines = split /\n/, $blocks[$i]->{text};
      LINE: foreach my $line (@lines) {
         my @parts = split /\s*(?:\bby\b|\band\b|&amp;|<sup>.{1,5}<\/sup>|,| \W )+\s*/i, $line;
         PART: foreach my $part (@parts) {
            print "checking for author in '$part'\n" if $self->verbosity;
            $part = strip_tags($part);
            my $re_name = qr/^\s*
               (\p{IsUpper}\p{IsAlpha}*[\. -]+){1,3}  # first name(s)
               (v[oa]n|d[ei])?\s*                     # surname prefix
               \p{IsUpper}[\p{IsAlpha}-]+             # surname
               \s*$/x;
            if ($part =~ /$re_name/) {
               for my $bad_word (@bad_words) {
                  if ($part =~ /\b$bad_word\b/i) {
                     print "bad word $bad_word\n" if $self->verbosity;
                     next LINE; # don't search on the same line after non-name
                  }
               }
               print "looks good\n" if $self->verbosity == 2;
               push @authors, $part;
               $last_block_with_names = $i;
            }
            else {
               next LINE; # don't search on the same line after non-name
            }
         }
      }
      if ($last_block_with_names && $i - $last_block_with_names >= 2) {
         print "two blocks since last block with name: stop searching\n" if $self->verbosity == 2;
         last;
      }
   }
   return \@authors; #xxx array_unique($authors);
}

sub get_text {
   my $self = shift;
   $self->do_parse() unless ($self->{plaintext});
   return $self->{plaintext};
}

sub authors {
   my $self = shift;
   my @arr = ();
   return [@arr];
}

sub html_body {
   
}

sub strip_tags {
   my $str = shift;
   $str =~ s/\s*<(([^>]|\n)*)\s*>//g;
   return $str;
}

1;
