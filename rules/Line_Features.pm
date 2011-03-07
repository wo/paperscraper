package rules::Line_Features;
use warnings;
use strict;
use File::Basename;
use Cwd 'abs_path';
use String::Approx 'amatch';
use Memoize;
use Text::Names;
use List::Util qw/min max/;
use util::Functools qw/someof allof/;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%features/;


our %features;

$features{TITLE} = [
    ['among first few lines', [0.4, -0.3]],
    ['within first few pages', [0.1, -1]],
    [$and->('large font', 'largest text on rest of page'), [0.5, -0.6]],
    ['bold', [0.2, -0.05]],
    ['centered', [0.4, -0.2]],
    ['gap above', [0.3, -0.3]],
    ['gap below', [0.2, -0.2]],
    ['matches title pattern', [0.1, -0.5]],
    ['several words', [0.1, -0.3]],
    ['high uppercase frequency', [0.1, -0.2]],
    # recursive tests that make use of label probabilities:
    [$or->('best title', 'may continue title'), [0.1, -0.3], 3],
    ['probable HEADING', [-0.2, 0.1]],
    ];

if (defined $_[0]->{doc}->{anchortexts}) { # TODO
    push @{$features{'TITLE'}},
         ['resembles anchor text', [0.6, 0]];
}

$features{AUTHOR} = [
    ['among first few lines', [0.3, -0.2]],
    [$or->('within first few pages', 'on last page'), [0.05, -0.8]],
    ['narrowish', [0.3, -0.3]],
    ['centered', [0.3, -0.2]],
    ['small font', [-0.5, 0.2]],
    ['largest text on page', [-0.4, 0]],
    ['contains digit', [-0.2, 0.05]],
    ['gap above', [0.3, -0.3]],
    ['gap below', [0.2, -0.2]],
    ['begins with possible name', [0.5, -0.5]],
    # recursive tests that make use of label probabilities:
    [$and->('best title', 'other good authors'), [-0.2, 0.05], 2],
    ['probable HEADING', [-0.5, 0], 3],
    ['contains actual name', [0.2, -0.3], 4],
    ['resembles best author', [0.1, -0.4], 5],
    ];

$features{HEADING} = [
    ['large font', [0.5, -0.3]],
    ['bold', [0.3, -0.2]],
    ['centered', [0.1, -0.05]],
    ['justified', [-0.4, 0]],
    ['gap above', [0.3, -0.5]],
    ['gap below', [0.2, -0.3]],
    ['contains letters', [0, -0.5]],
    ['several words', [0.05, -0.2]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['begins with section number', [0.4, -0.1]],
    ['probable CONTENT', [-0.5, 0.05]],
    ['preceeds CONTENT', [0.3, -0.3]],
    ['follows CONTENT', [0.4, -0.2]],
    ];

$features{ABSTRACTSTART} = [
    ['"abstract" heading', [1, -0.3]],
    [$and->('begins with "abstract:"', 'gap above'), [0.8, -0.3]],
    # recursive:
    ['preceeds CONTENT', [0.1, -0,3], 4],
    ];

$features{CONTENT} = [
    ['normal font', [0.3, -0.6]],
    ['bold', [-0.3, 0.05]],
    ['centered', [-0.5, 0.1]],
    ['justified', [0.3, -0.1]],
    [$or->('gap above', 'gap below'), [-0.2, 0.1]],
    [$and->('gap above', 'gap below'), [-0.6, 0.1]],
    ['high punctuation frequency', [-0.2, 0.1]],
    ['long', [0.1, -0.2]],
    ['matches content pattern', [0.2, -0.3]],
    ];

$features{ABSTRACTCONTENT} = [
    # This is basically CONTENT, but at the beginning of the
    # document. Spares us from going through multiple stages of
    # labeling almost the entire document when looking for an
    # abstract.
    ['probable CONTENT', [0.8, -0.8], 2],
    ['among first CONTENT lines', [0.2, -0.8], 2],
    ['near other ABSTRACTCONTENT', [0.3, -0.3], 2],
    ];

$features{FOOTNOTE} = [
    ['small font', [0.7, -0.7]],
    ['contains letters', [0, -0.3]],
    ['begins with footnote label', [0.4, -0.1]],
    ['largest text on rest of page', [0.2, -0.5]],
    ['near bottom of page', [0.2, -0.2]],
    ];

$features{BIB} = [
    ['in second half of paper', [0.1, -0.4]],
    ['in bibliography section', [0.5, -0.2]],
    ['begins with possible bib name', [0.15, -0.15]],
    ['contains year', [0.15, -0.15]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['high numeral frequency', [0.1, -0.2]],
    ['high punctuation frequency', [0.1, -0.2]],
    # recursive tests that make use of label probabilities:
    ['near other BIBs', [0.3, -0.3], 2],
    ['resembles best BIB', [0.3, -0.6], 3],
    ];

$features{BIBSTART} = [
    ['probable BIB', [0.1, -0.6], 2],
    ['greater gap above than below', [0.3, -0.05], 2],
    ['next line indented', [0.3, -0.1], 2],
    ['indented relative to previous line', [-0.3, 0.05], 2],
    ['long', [0.2, -0.2], 2],
    ['begins with citation label', [0.3, -0.05], 2],
    ['begins with possible bib name', [0.5, -0.05], 2],
    ['begins with dash', [0.4, 0], 2],
    ['previous line short', [0.6, -0.1], 2],
    ['previous line ends with terminator', [0.4, -0.1], 2],
    # recursive:
    ['previous line BIBSTART', [-0.2, 0.1], 3],
    ['near other BIBs', [0.3, -0.3], 2],
    ['resembles best BIBSTART', [0.3, -0.3], 3],
    ];

1;

my @labels = qw/TITLE AUTHOR CONTENT HEADING ABSTRACTSTART
                ABSTRACTCONTENT BIB BIBSTART/;

my %f;

sub matches {
    my $re = shift;
    return sub {
        $_[0]->{text} =~ /$re/;
    };
}

$f{'contains digit'} = matches('\d');

sub p {
    my $label = shift;
    return sub {
        return $_[0]->{p}->($label);
    };
}

foreach (@labels) {
    $f{"probable $_"} = p($_);
}

$f{'narrowish'} = sub {
    my $frac = $_[0]->{width} / $_[0]->{page}->{width};
    return max(0, 1 - 2*abs(0.25 - $frac));
};

$f{'several words'} = memoize(sub { 
     $_[0]->{plaintext} =~ /\p{IsAlpha}+\s+\p{IsAlpha}/o;
});

$f{'long'} = memoize(sub {
    return min(length($_[0]->{plaintext})/70, 1);
});

$f{'bold'} = memoize(sub {
    $_[0]->{text} =~ /^\s*
        (?:<.+>)?    # optional second tag: <i><b>title<.b><.i>
        <(b>)        # start tag 
        .+           # content
        <\/.>        # end tag
        \W*          # optional junk appended
        $/iox;
    # yes, this catches '<b>foo</b> bar <i>foo</i>'
});

$f{'all caps'} = memoize(sub {
    $_[0]->{plaintext} =~ /(?!\p{IsLower})\p{IsUpper}/;
});

$f{'large font'} = memoize(sub {
    .5 + max(min($_[0]->{fsize}-2, 5), -5) / 10;
});

$f{'normal font'} = memoize(sub {
    1 - min(abs($_[0]->{fsize}), 3) / 3;
});

$f{'small font'} = memoize(sub {
    .5 + max(min(-1*$_[0]->{fsize}-4, 5), -5) / 10;
});

$f{'among first few lines'} = memoize(sub { 
    3 / max($_[0]->{id}, 3);
});

$f{'in second half of paper'} = memoize(sub {
    my $num = @{$_[0]->{doc}->{chunks}};
    return $_[0]->{id} > $num/2 ? 1 : 0;
});

$f{'near top of page'} = memoize(sub {
    my $dist_top = int(($_[0]->{top} - $_[0]->{page}->{top}) / 10);
    return 3 / max($dist_top, 3);
});

$f{'near bottom of page'} = memoize(sub {
    my $dist_bot = int(($_[0]->{page}->{bottom} - $_[0]->{bottom}) / 10);
    return 5 / max($dist_bot, 5);
});

$f{'within first few pages'} = memoize(sub { 
    2 / max($_[0]->{page}->{number}+1, 2);
});

$f{'on last page'} = memoize(sub {
    return $_[0]->{page}->{number} == $_[0]->{doc}->{pages};
});

my $alignment = sub {
    # this doesn't work well for text in columns
    my $dist_left = $_[0]->{left} - $_[0]->{page}->{left};
    my $dist_right = $_[0]->{page}->{right} - $_[0]->{right};
    $dist_left += 50 if ($_[0]->{plaintext} =~ /^   /);
    if (abs($dist_left - $dist_right) < 30) {
        return 'justify' if $dist_left < 30;
        return 'center';
    }
    return 'left' if $dist_left < $dist_right;
    return 'right';
};

$f{'centered'} = memoize(sub {
    my $align = $alignment->($_[0]);
    return 1 if $align eq 'center';
    return .5 if $align eq 'justify';
    return 0;
});

$f{'justified'} = memoize(sub {
    return $alignment->($_[0]) eq 'justify';
});

sub gap {
    # gap($chunk, 'prev') == 2 means vertical distance to previous
    # chunk is twice the default linespacing
    my ($chunk, $dir) = @_;
    my $default = $chunk->{doc}->{linespacing};
    my $sibling = $chunk->{$dir};
    while ($sibling && $sibling->{page} == $chunk->{page}) {
        my $sp = $dir eq 'prev' ? $chunk->{top} - $sibling->{top} :
            $sibling->{top} - $chunk->{top};
        if ($sp > 0) {
            return ($sp/min($chunk->{height}, $sibling->{height}))
                / $default;
        }
        $sibling = $sibling->{$dir};
    }
    # no sibling:
    return undef;
};

$f{'gap above'} = memoize(sub {
    my $gap = gap($_[0], 'prev');
    return 0.7 unless $gap; # no element above
    return max(min($gap-1, 1), 0);
});

$f{'gap below'} = memoize(sub {
    my $gap = gap($_[0], 'next');
    return 0.7 unless $gap; # no element below
    return max(min($gap-1, 1), 0);
});

$f{'greater gap above than below'} = memoize(sub {
    my $gap_above = gap($_[0], 'prev') || 0.7;
    my $gap_below = gap($_[0], 'next') || 0.7;
    return $gap_above > $gap_below;
});

$f{'matches title pattern'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_title;
});

$f{'matches content pattern'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_content;
});

$f{'resembles anchor text'} = memoize(sub {
    for my $a (@{$_[0]->{doc}->{anchortexts}}) {
        return 1 if (amatch($a, ['i 30%'], $_[0]->{plaintext}));
    }
    return 0;
});
 
$f{'may continue title'} = sub {
    # errs on the side of 'yes'
    my $prev = $_[0]->{prev};
    return 0 unless $prev;
    my $score = 0.5;
    $score += $prev->{p}->('TITLE') - 0.8;
    $score += 0.2 if ($prev->{plaintext} =~ /([\:\;\-\,])$/);
    $score += ($_[0]->{fsize} == $prev->{fsize}) ? 0.1 : -0.1;
    $score -= (gap($_[0], 'prev')-1.5) / 10;
    my $align1 = $alignment->($_[0]);
    my $align2 = $alignment->($prev);
    $score -= 0.2 if ($align1 ne 'justify' && $align2 ne 'justify'
                 && $align1 ne $align2);
    return max(0, min(1, $score));
};

$f{'best title'} = sub {
    my $best = $_[0]->{best}->{TITLE}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    my $dist = $best->{p}->('TITLE') - $_[0]->{p}->('TITLE');
    return max(1 - $dist*10, 0); 
};

$f{'other good authors'} = sub {
    my $ch = $_[0]->{best}->{AUTHOR}->[0];
    return 0 unless $ch;
    return 1 if $_[0] != $ch;
    $ch = $_[0]->{best}->{AUTHOR}->[1];
    return 0 unless $ch;
    my $dist = $_[0]->{p}->('AUTHOR') - $ch->{p}->('AUTHOR');
    return max(1 - $dist*4, 0); 
};

$f{'resembles best author'} = sub {
    my $best = $_[0]->{best}->{AUTHOR}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    return 0 if $_[0]->{page} != $best->{page};
    # is on other side of title?
    my $title = $_[0]->{best}->{TITLE}->[0]->{id};
    return 0 if ($_[0]->{id} < $title) != ($best->{id} < $title);
    # smaller flaws:
    my $ret = 1;
    $ret -= 0.3 if $alignment->($_[0]) ne $alignment->($best);
    $ret -= 0.3 if $_[0]->{fsize} != $best->{fsize};
#    $ret -= 0.3 if $bold->($_[0]) != $bold->($best);
    # far away:
    my $dist = abs($_[0]->{textpos} - $best->{textpos});
    $ret -= $dist/500;
    return max($ret, 0);
};

$f{'resembles best BIB'} = sub {
    my $best = $_[0]->{best}->{BIB}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    my $ret = 1;
    $ret -= 0.6 if $_[0]->{fsize} != $best->{fsize};
    $ret -= abs($_[0]->{page}->{number} - $best->{page}->{number})/10;
    my $inbib = $f{'in bibliography section'};
    $ret -= 0.8 if $inbib->($best) && !$inbib->($_[0]);
    return max($ret, 0);
};

$f{'resembles best BIBSTART'} = sub {
    my $best = $_[0]->{best}->{BIBSTART}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    my $ret = 1;
    $ret -= 0.6 if $_[0]->{fsize} != $best->{fsize};
    $ret -= 0.5 if abs($_[0]->{left} - $best->{left}) > 10;
    $ret -= abs($_[0]->{page}->{number} - $best->{page}->{number})/10;
    my $inbib = $f{'in bibliography section'};
    $ret -= 0.8 if $inbib->($best) && !$inbib->($_[0]);
    return max($ret, 0);
};

$f{'like pdf author'} = sub {
    # TODO
    return 0;
};

$f{'like source author'} = sub {
    # TODO
    return 0;
};

$f{'in bibliography section'} = sub {
    # xxx stub, should consider real headings, and should not take
    # everything after a bib heading to be the bib section.
    my $prev = $_[0];
    $_[0]->{_in_bib} = 0;
    while ($prev = $prev->{prev}) {
        if ($prev->{plaintext} =~ $re_bib_heading) {
            $_[0]->{_in_bib} = 1;
            last;
        }
        if (exists $prev->{_in_bib}) {
            $_[0]->{_in_bib} = $prev->{_in_bib};
            last;
        }
    }
    return $_[0]->{_in_bib};
};

$f{'"abstract" heading'} = sub {
    return 0 unless $_[0]->{plaintext} =~ /^$re_abstract$/;
    return 1 if $_[0]->{p}->('HEADING') > 0.5;
    return 0.5;
};

sub neighbours {
    my ($dir, $label) = @_;
    return sub {
        my $ch = $_[0];
        my $res = 0;
        while ($ch = $ch->{$dir}) {
            next unless length($ch->{plaintext}) > 5;
            return $res unless $ch->{p}->($label) > 0.5;
            $res += (1-$res)/2; 
            return 1 if $res > 0.9;
        }
        return $res;
    };
}

$f{'follows CONTENT'} = neighbours('prev', 'CONTENT');
$f{'preceeds CONTENT'} = neighbours('next', 'CONTENT');
$f{'near other BIBs'} = someof(neighbours('prev', 'BIB'), 
                                        neighbours('next', 'BIB'));
$f{'near other ABSTRACTCONTENT'} = 
    someof(neighbours('prev', 'ABSTRACTCONTENT'), 
           neighbours('next', 'ABSTRACTCONTENT'));

$f{'among first CONTENT lines'} = sub {
    my $ch = $_[0];
    my $n = 1;
    while ($ch = $ch->{prev}) {
        $n++ if $ch->{p}->('CONTENT') > 0.5;
        last if $n >= 100;
    }
    return 1 - $n/100;
};

sub begins {
    my ($re, $re_no) = @_;
    my $field = @_ ? 'plaintext' : 'text';
    return sub {
        my $ch = shift;
        if ($ch->{$field} =~ /^($re)/ && (!$re_no || $& !~ /$re_no/)) {
            return 1;
        }
        return 0;
    }
};

$f{'begins with section number'} = memoize(begins($re_sec_number));
 
$f{'begins with footnote label'} = memoize(begins($re_footnote_label, '', 1));

$f{'begins with citation label'} = memoize(begins($re_cit_label));

$f{'begins with "abstract:"'} = memoize(begins($re_abstract));

$f{'begins with dash'} = memoize(begins($re_dash));

$f{'begins with possible name'} = memoize(sub {
    my @parts = split($re_name_separator, $_[0]->{plaintext}, 2);
    print "part 0:", $parts[0], "\n";
    return 0 if ($parts[0] =~ /$re_noname/);
    return 1 if ($parts[0] =~ /(?:$re_name_before)?$re_name(?:$re_name_after)?/);
    return 0;
});

$f{'begins with possible bib name'} = 
    memoize(begins("(?:$re_name)|(?:$re_name_inverted)", $re_noname));

$f{'contains possible name'} = memoize(sub {
    $_[0]->{plaintext} =~ /$re_name/;    
});

$f{'contains actual name'} = memoize(sub {
    unless (exists $_[0]->{names}) {
        $_[0]->{names} = extract_names($_[0]->{plaintext});
    }
    return max(values %{$_[0]->{names}}) || 0; 
});


$f{'contains year'} = memoize(sub {
    $_[0]->{plaintext} =~ /\d{4}/;    
});

$f{'contains letters'} = memoize(sub {
    my $num_alpha = $_[0]->{plaintext} =~ tr/[a-zA-Z]//;
    return 1 if $num_alpha > 1;
    return 0 if $num_alpha == 0;
    return 0.5;
});

sub freq {
    my ($pattern, $frequency) = @_;
    return sub {
        my $strlen = min(length($_[0]->{plaintext}), 1);
        my $num_p = 0;
        $num_p++ while $_[0]->{plaintext} =~ /$pattern/g;
        return min($num_p*$frequency / $strlen, 1);
    }
}

$f{'high uppercase frequency'} = memoize(freq('\b\p{IsUpper}', 8));

$f{'high numeral frequency'} = memoize(freq('\d', 10));

$f{'high punctuation frequency'} = memoize(freq('[,\.:\(\)\[\]-]', 5));

sub largest_text {
    my $dir = shift;
    return sub {
        my $ch = $_[0];
        my $anything_smaller = 0;
        while (($ch = $ch->{$dir}) && $ch->{page} == $_[0]->{page}) {
            next if (length($ch->{plaintext}) < 5);
            return 0 if $ch->{fsize} > $_[0]->{fsize};
            $anything_smaller = 1 if $ch->{fsize} < $_[0]->{fsize};
        }
        return $anything_smaller ? 1 : 0.5;
    }
}

$f{'largest text on rest of page'} = memoize(largest_text('next'));
$f{'largest text on page'} = memoize(allof(largest_text('next'),
                                            largest_text('prev')));

$f{'previous line short'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return min(max(2 - length($prev)/10, 1), 0);
});   

$f{'previous line ends with terminator'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return $prev =~ /\.!\?\s*$/;
});

$f{'previous line BIBSTART'} = sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return $prev->{p}->('BIBSTART');
};
 
$f{'is BIB'} = sub {
    return $_[0]->{p}->('BIB');
};

$f{'next line indented'} = memoize(sub {
    my $next = $_[0]->{next};
    return 0.5 unless $next;
    return 1 if ($next->{left} - $_[0]->{left} > 5);
});
 
$f{'indented relative to previous line'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return 1 if ($_[0]->{left} - $prev->{left} > 5);
});

compile(\%features, \%f);

1;

=HEAD

   - title
   - subtitle
   - author (name)
   - address
     - affiliation 
     - email
   - pubinfo (publication info)
     - date
   - abstract
   - keywords
   - motto
   - tableofcontents
   - header1
   - header2
   - header3
   - paragraph
   - equation
   - quote
   - figure
   - caption
   - listitem
   - footnote
   - marginnote
   - endnote
   - bibitem
   - pagehead
   - pagefoot
   - pagenumber
   - junk (cover page, end of previous paper, website menu etc.)

=cut

