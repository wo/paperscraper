use strict;
use warnings;

package Parser::PDF;
use Data::Dumper;
use Encode;

sub new {
   my ($class, %args) = @_;
   die "Parser::PDF::new() requires file parameter" unless defined($args{file});
   my $self  = {
      error          => '',
      file           => $args{file},
      verbosity      => $args{verbosity} || 0,
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

sub get_text {
   my $self = shift;
   print "\n\n=== converting PDF to HTML ===\n" if $self->verbosity;
   my $command = '/usr/local/bin/pdftohtml'
                  .' -i'        # ignore images
                  .' -enc \'UTF-8\''
                  .' -stdout'   # output to stdout
                  .' '.$self->{file} # source file
                  .' 2>&1';     # stderr to stdout
   print "$command\n" if $self->verbosity >= 2;
   my $text = `$command`;
   $text = Encode::decode_utf8($text) || $text; # sometimes $text isn't really UTF8, for whatever reson, then decode_utf() returns undef
   print "$text\n" if $self->verbosity == 1;
   return $self->error("pdftohtml failed: $text") unless ($text =~ /DOCTYPE/);
   $text =~ s/<br>\n?|<\/head/\n/gi;
   $text =~ s/<[^>]+>//g;
   return $text;
}

sub do_parse {
   my $self = shift;
   print "\n\n=== converting PDF to XML ===\n" if $self->verbosity;
   my $command = '/usr/local/bin/pdftohtml'
                  .' -i'        # ignore images
                  .' -xml'      # xml output
                  .' -enc \'UTF-8\''
                  .' -f 1'      # first page to convert
                  .' -l 2'      # last page to convert
                  .' -stdout'   # output to stdout
                  .' '.$self->{file} # source file
                  .' 2>&1';     # stderr to stdout
   print "$command\n" if $self->verbosity >= 2;
   $self->{content} = Encode::decode_utf8(`$command`);
   print $self->{content}."\n" if $self->verbosity >= 2;
   return $self->error("pdftohtml failed: ".$self->{content}) unless ($self->{content} =~ /DOCTYPE pdf2xml/);
   # sometimes conversion results in garbage HTML with all lines 0 height:
   return $self->error("pdftohtml produced garbage") if ($self->{content} =~ /height="0" font="0">/);

   # parse xml:
   $self->{content} =~ s/<a.[^>]*>(.+?)<\/a>/$1/i; # strip anchors (inserted by pdftohtml for footnotes)
   $self->{blocks} = [$self->get_body_blocks];
   return undef unless (defined($self->{blocks}[0]));
   my %titleblock = $self->title_block or return undef;
   my $title = strip_tags($titleblock{text});
   my %abstractblock = $self->abstract_block($titleblock{index}+1) or return undef;
   my $abstract = $abstractblock{text};
   if (length($abstract) > 2000) {
      $abstract = substr($abstract, 0, index($abstract, ' ', 2000)).'...';
   }
   my $authors = $self->authors($titleblock{index}+1, $abstractblock{index}-1);
   if (!@{$authors}) { $authors = $self->authors(0, $titleblock{index}-1); }

   return {
      title => $title,
      abstract => $abstract,
      authors => $authors
   };
}

sub get_body_blocks {
   my $self = shift;
   my @chunks = $self->get_body_chunks() or return $self->error('No text found in converted document');
   my @lines = $self->merge_into_lines(@chunks);
   my @blocks = $self->merge_into_blocks(@lines);
   return @blocks;
}

sub get_body_chunks {
   my $self = shift;
   my $content = $self->{content};
   print "\n\n=== EXTRACTING TEXT CHUNKS ===\n" if $self->verbosity;
   # parse fontsize declarations:
   my %fontsizes = $content =~ /<fontspec id=\"(\d+)\" size=\"(\d+)\"/og; # id => size
   # parse all content body chunks into @chunks array:
   my @chunks;
   my @pages = split /<page number=/, $content;
   foreach my $p (0 .. $#pages) {
      print "page $p+1\n" if $self->verbosity >= 2;
      foreach my $line (split /\n/, $pages[$p]) {
         next unless $line =~ /<text top=\"(\d+)\" left=\"(\d+)\" width=\"(\d+)\" height=\"(\d+)\" font=\"(\d+)\">(.+?)<\/text>/o;
         push @chunks, {
            'top'    => $1,
            'left'   => $2,
            'width'  => $3,
            'height' => $4,
            'bottom' => $1 + $4,
            'right'  => $2 + $3,
            'fsize'  => $fontsizes{$5},
            'text'   => $6,
            'page'   => $p+1
         };
         # print "chunk: $6\n" if $self->verbosity >= 2;
      }
   }
   return @chunks;
}

sub merge_into_lines {
   my $self = shift;
   print "\n\n=== MERGING CHUNKS INTO LINES ===\n" if $self->verbosity;
   my @chunks = @_;
   my @lines;
   #if ($this->verbosity >= 2) print "chunk 0: ".var_export($chunks[0], true) if $self->verbosity >= 2;
   for (my $i=0; $i<=$#chunks; $i++) {
      my %line = %{$chunks[$i]};
      my @line_chunks = ($chunks[$i]);
      my %longest_chunk = %{$chunks[$i]};
      my $min_top = $chunks[$i]->{top};
      my $max_bottom = $chunks[$i]->{bottom};
      while ($chunks[$i+1]) {
         my %chunk = %{$chunks[$i+1]};
         print "\nchunk $i+1: ",$chunk{text} if $self->verbosity >= 2;
         my $tolerance = ($max_bottom - $min_top) / 2;
         if ($min_top - $chunk{top} > $tolerance) {
            print "\nline ends: chunk is too high (",($min_top-$chunk{top})." from \$min_top): ",$chunk{text} if $self->verbosity >= 2;
            last;
         }
         if ($chunk{bottom} - $max_bottom > $tolerance) {
            print "\nline ends: chunk is too low (",($chunk{bottom}-$max_bottom)," from \$max_bottom): ",$chunk{text} if $self->verbosity >= 2;
            last;
         }
         if ($chunk{left} < $chunks[$i]->{right} - 5) {
            print "\nline ends: chunk is too far left" if $self->verbosity >= 2;
            last;
         }
         if ($chunk{left} > $chunks[$i]->{right} + 50) {
            print "\nline ends: chunk is too far right" if $self->verbosity >= 2;
            last;
         }
         push @line_chunks, {%chunk};
         $min_top = min($min_top, $chunk{top});
         $max_bottom = max($max_bottom, $chunk{bottom});
         %longest_chunk = %chunk if ($chunk{width} > $longest_chunk{width});
         $i++;
      }
      $line{fsize} = $longest_chunk{fsize};
      $line{top} = $longest_chunk{top};
      $line{bottom} = $longest_chunk{bottom};
      $line{height} = $longest_chunk{height};
      $line{abstop} = $min_top; # including sub/supscripts
      $line{absbottom} = $max_bottom;
      $line{absheight} = $max_bottom - $min_top;
      $line{text} = '';
      foreach my $chunk (@line_chunks) {
         # print "chunk ".$chunk->{text}." left: ".$chunk->{left}.", line right: ".$line{right} if $self->verbosity >= 2;
         $line{text} .= ' ' if ($chunk->{left} > $line{right}+1);
         if ($chunk->{bottom} < $line{bottom} && $chunk->{top} < $line{top}) {
            $line{text} .= '<sup>'.$chunk->{text}.'</sup>';
         }
         elsif ($chunk->{bottom} > $line{bottom} && $chunk->{top} > $line{top}) {
            $line{text} .= '<sub>'.$chunk->{text}.'</sub>';
         }
         else {
            $line{text} .= $chunk->{text};
         }
         $line{right} = $chunk->{right};
      }
      $line{width} = $line{right} - $line{left};
      push @lines, {%line} unless $line{height} == 0; # yes, some lines have height 0, causing trouble later
      #if ($this->verbosity >= 2) print "line: ".var_export($line, true) if $self->verbosity >= 2;
   }
   return @lines;
}

sub merge_into_blocks {
   my $self = shift;
   print "\n\n=== MERGING LINES INTO BLOCKS ===\n" if $self->verbosity;
   my @lines = @_;

   # first we calculate the most common line spacing, and the left and right border of the document:
   my %spacings;
   my @edges;
   my $prevline;
   foreach my $line (@lines) {
      if ($prevline && $line->{height}) {
         my $spacing = ($line->{top} - $prevline->{top}) / $line->{height};
         $spacings{$spacing}++;
      }
      push @edges, $line->{left};
      push @edges, $line->{right};
      $prevline = $line;
   }
   my $normal_spacing = 0;
   foreach my $key (keys %spacings) {
      if (!$normal_spacing || $spacings{$key} > $spacings{$normal_spacing}) {
         $normal_spacing = $key;
      }
   }
   print "most common line spacing: $normal_spacing\n" if $self->verbosity;
   @edges = sort @edges;
   my $doc_left = $edges[0];
   my $doc_right = $edges[-1];
   print "document left border: $doc_left; right border: $doc_right\n" if $self->verbosity;

   # assign 'align' and 'is_bold' property to lines:
   foreach my $line (@lines) {
      $line->{is_bold} = $line->{text} =~ /^\s*<.>.+<\/.>\s*(<sup>.+<\/sup>)?\s*$/i; # also count <i>
      $line->{align} = 'center';
      $line->{align} = 'left' if ($line->{left} < $doc_left+5);
      if ($line->{right} > $doc_right-5) {
         $line->{align} = ($line->{align} eq 'left') ? 'justify' : 'right';
      }
   }

   # now merge the lines into blocks
   my @blocks;
   for (my $i=0; $i<=$#lines; $i++) {
      print "line $i: ",$lines[$i]->{text},"\n" if $self->verbosity >= 2;
      if (strip_tags($lines[$i]->{text}) =~ /^\s*$/) {
         print "skipping empty line $i\n" if $self->verbosity;
         next;
      }
      # new text block:
      print "new block: ",$lines[$i]->{text},"\n" if $self->verbosity;
      my %block = %{$lines[$i]};
      $block{spacing} = 0;
      while ($lines[$i+1]) {
         my %line = %{$lines[$i+1]};
         print "line $i+1: ",$line{text},"\n" if $self->verbosity >= 2;
         if (strip_tags($lines[$i]->{text}) =~ /^\s*$/) {
            print "block ends: empty new line\n" if $self->verbosity;
            last;
         }
         if ($line{fsize} != $block{fsize}) {
            print "block ends: next line has different font size\n" if $self->verbosity;
            last;
         }
         if ($line{is_bold} != $lines[$i]->{is_bold}) {
            print "block ends: bold face changing\n" if $self->verbosity;
            last;
         }
         # check for large gaps:
         my $acceptable_spacing = $block{spacing} ? 1.1 * $block{spacing} : 1.35 * $normal_spacing;
         my $spacing = ($line{top} - $lines[$i]->{top}) / $lines[$i]->{height};
         if (abs($spacing) > $acceptable_spacing) {
            print "block ends: large spacing $spacing (acceptable: $acceptable_spacing, block: ".$block{spacing}.", normal: $normal_spacing)\n" if $self->verbosity;
            last;
         }
         # check for alignment/indentation changes:
         my $dist_left = $line{left} - $lines[$i]->{left};
         my $dist_right = $lines[$i]->{right} - $line{right};
         if (abs($dist_left) < 10) {
            $block{align} = (abs($dist_right) < 10) ? 'justify'
               : ($block{align} ne 'justify') ? 'left' # justified blocks may end left-aligned
               : $block{align};
         }
         elsif ($dist_left > 5 && ($block{align} eq 'left' || $block{align} eq 'justify')) {
            print "block ends: next line is too far right (indented paragraph)\n" if $self->verbosity;
            last;
         }
         elsif ($dist_right < -10 && $line{align} ne 'center') {
            print "block ends: next line extends too far on both sides\n" if $self->verbosity;
            last;
         }
         else {
            $block{align} = $line{align};
         }
         print "block continues: ".$line{text}. " (align ".$block{align}.")\n" if $self->verbosity;
         $line{text} = "\n".$line{text};
         $block{spacing} = $spacing;
         $block{text} .= $line{text};
         $block{left} = min($block{left}, $line{left});
         $block{width} = max($block{width}, $line{width});
         $i++;
         # if ($this->verbosity >= 2) print "block:\n".var_export($block, true)."\n\n" if $self->verbosity >= 2;
      }
      $block{index} = scalar @blocks;
      push @blocks, {%block};
      print Dumper(\%block) if ($self->verbosity == 3);
   }
   # check for blocks of the form: paragraph -> quote/example/formula -> paragraph:
   my @new_blocks;
   my $mergings = 0;
   for (my $i=0; $i<=$#blocks; $i++) {
      push @new_blocks, $blocks[$i];
      $blocks[$i]->{index} -= $mergings;
      next unless defined $blocks[$i+2];
      next if ($blocks[$i+1]->{left} <= $blocks[$i]->{left});
      # all kinds of factors are relevant here; we check them all and make a guess
      my $should_merge = 0;
      $blocks[$i+1]->{left} >= $blocks[$i]->{left} + 20         && ($should_merge += 5);
      $blocks[$i+1]->{text} =~ /^\s*\(?.{1,3}\)|\(.{1,3}\)\s*$/ && ($should_merge += 7); # labeled formula
      $blocks[$i]->{text} =~ /:\s*$/                            && ($should_merge += 5);
      $blocks[$i+1]->{fsize} > $blocks[$i]->{fsize}             && ($should_merge -= 10);
      $blocks[$i+2]->{left} != $blocks[$i]->{left}              && ($should_merge -= 8);
      $blocks[$i+1]->{right} > $doc_right - 50                  && ($should_merge -= 5);
      $blocks[$i]->{is_bold}                                    && ($should_merge -= 7); # heading before indented par?
      $blocks[$i]->{text} =~ /\.\s*$/                           && ($should_merge -= 5); # par ends before indented par?
      $blocks[$i+1]->{text} =~ /[a-z\-]\s*$/                    && ($should_merge -= 5); # indented par?
      print "\nmerging blocks? (\$should_merge $should_merge):"
         ."\n  +".substr($blocks[$i]->{text},0,20)
         ."\n  +".substr($blocks[$i+1]->{text},0,20)
         ."\n  +".substr($blocks[$i+2]->{text},0,20) if $self->verbosity >= 2;
      next if ($should_merge <= 0);
      $blocks[$i+1]->{text} =~ s/\n/\n   /g;
      $blocks[$i]->{text} .= "\n   ".$blocks[$i+1]->{text}."\n".$blocks[$i+2]->{text};
      $mergings += 2;
      $i += 2;
   }
   return @new_blocks;
}

sub title_block {
   my $self = shift;
   print "\n\n=== scanning for title ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $titleblock = $blocks[0];    # (first) largest block is title
   print "\ninitial title: ".substr($titleblock->{text}, 0, 30) if $self->verbosity;
   foreach my $i (1 .. $#blocks) {
      if (length($blocks[$i]->{text}) > 500) {
         print "\nblock $i is too long for title: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{fsize} < $titleblock->{fsize}) {
         print "\nblock $i has smaller font size: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{fsize} > $titleblock->{fsize}) {
         print "\nchanging title to block $i, larger: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         $titleblock = $blocks[$i];
         next;
      }
      # same font size:
      if ($titleblock->{is_bold}) {
         print "\nblock $i has same font size, cannot override bold title: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{page} > $titleblock->{page}) {
         print "\nblock $i on next page and same font size: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{align} eq 'center' && $titleblock->{align} ne 'center') {
         print "\nchanging title to block $i, centered: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         $titleblock = $blocks[$i];
         next;
      }
      if ($titleblock->{align} eq 'center' && $blocks[$i]->{align} ne 'center') {
         print "\nblock $i with same font is not centered: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{is_bold}) {
         print "\nchanging title to block $i, bold: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
         $titleblock = $blocks[$i];
         next;
      }
      print "\nblock $i doesn't match any criteria: ".substr($blocks[$i]->{text}, 0, 30) if $self->verbosity >= 2;
   }
   return %{$titleblock};
}

sub abstract_block {
   my $self = shift;
   print "\n\n=== scanning for abstract ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $start_index = shift;
   my $abstractblock;
   my $first_par;
   foreach my $i ($start_index .. $#blocks) {
      print "checking for abstract in '".substr($blocks[$i]->{text},0,30)."'\n" if $self->verbosity >= 2;
      # check for paragraph:
      if (length($blocks[$i]->{text}) < 300) {
         if ($blocks[$i]->{text} =~ /^.{0,3}abstract *[:<&]/i
             && length($blocks[$i+1]->{text}) > 200) {
            print "woo, block $i+1 follows abstract heading\n" if $self->verbosity;
            $abstractblock = $blocks[$i+1];
            last;
         }
         else {
            print "no, block is too short\n" if $self->verbosity >= 2;
            next;
         }
      }
      if (index($blocks[$i]->{text}, '<sup>') == 0) {
         print "no, block seems to be a footnote\n" if $self->verbosity >= 2;
         next;
      }
      if ($blocks[$i]->{text} =~ /^.{0,3}abstract *[:<&]/i) {
         print "woo, block $i begins with 'abstract'!\n" if $self->verbosity;
         $abstractblock = $blocks[$i];
         $blocks[$i]->{text} =~ s/^.{0,3}abstract *:? *(<..>)?//i;
         last;
      }
      if ($blocks[$i]->{align} ne 'left' && $blocks[$i]->{align} ne 'justify') {
         print "no, block is centered or right-aligned\n" if $self->verbosity >= 2;
         next;
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

sub authors {
   my $self = shift;
   print "\n\n=== scanning for authors ===\n" if $self->verbosity;
   my @blocks = @{$self->{blocks}};
   my $start_index = shift;
   my $end_index = shift;
   print "start $start_index, end $end_index, count $#blocks\n" if $self->verbosity >= 2;
   my @authors;
   my @bad_words = (
      'universit\w+', 'institute', 'department', 'college', 'center',
      'version', 'introduction', 'forthcoming',
      'new', ' city', ' france', 'santa'
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
               print "looks good\n" if $self->verbosity >= 2;
               push @authors, $part;
               $last_block_with_names = $i;
            }
            else {
               next LINE; # don't search on the same line after non-name
            }
         }
      }
      if ($last_block_with_names && $i - $last_block_with_names >= 2) {
         print "two blocks since last block with name: stop searching\n" if $self->verbosity >= 2;
         last;
      }
   }
   return \@authors; #xxx array_unique($authors);
}

sub max {
   my $max = shift;
   for (@_) { $max = $_ if $max < $_ }
   return $max;
}

sub min {
   my $min = shift;
   for (@_) { $min = $_ if $min > $_ }
   return $min;
}

sub strip_tags {
   my $str = shift;
   $str =~ s/\s*<(([^>]|\n)*)\s*>//g;
   return $str;
}

1;
