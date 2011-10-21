package rules::Line_Features;
use warnings;
use strict;
use File::Basename;
use Cwd 'abs_path';
use String::Approx 'amatch';
use Memoize;
use List::Util qw/min max/;
use util::Functools qw/someof allof/;
use util::String;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%features/;


our %features;

$features{HEADER} = [
    ['gap below', [0.2, -0.3]],
    ['small font', [0.2, -0.2]],
    ['line begins or ends with digit', [0.2, -0.1]],
    ['outside normal page dimensions', [0.2, -0]],
    ['resembles other HEADERs', [0.2, -0.3], 2]
    ];

$features{FOOTER} = [
    ['gap above', [0.2, -0.3]],
    ['small font', [0.2, -0.1]],
    ['normal font', [-0.1, 0.1]],
    ['is digit', [0.3, -0.1]],
    ['outside normal page dimensions', [0.2, -0]],
    ['previous line FOOTER', [0.4, 0], 2],
    ['resembles other FOOTERs', [0.25, -0.35], 3]
    ];

$features{FOOTNOTESTART} = [
    ['gap above', [0.1, -0.1]],
    ['small font', [0.3, -0.4]],
    ['long', [0.1, -0.2]],
    ['previous line has larger font', [0.2, -0.3]],
    ['previous line is bibliography heading', [-0.3, 0]],
    ['indented relative to previous line', [0.1, -0.15], 2],
    ['begins with footnote label', [0.3, -0.5], 2],
    ['rest of page has same font size', [0.15, -0.5], 2],
    ['near bottom of page', [0.1, -0.1], 2],
    ['resembles best FOOTNOTESTART', [0.2, -0.3], 3],
    ];

$features{TITLE} = [
    ['among first few lines', [0.4, -0.3]],
    ['within first few pages', [0.1, -1]],
    ['long', [-0.1, 0.1]],
    [$and->('large font', 'largest text on rest of page'), [0.5, -0.6], 2],
    ['largest text on rest of page', [0.2, 0], 2],
    ['bold', [0.3, -0.05], 2],
    ['all caps', [0.2, 0], 2],
    ['centered', [0.3, -0.2], 2],
    ['gap above', [0.3, -0.3], 2],
    ['gap below', [0.2, -0.2], 2],
    ['style appears on several pages', [-0.3, 0], 2],
    ['matches title pattern', [0.1, -0.6], 2],
    [$or->('several words', 'may continue title'), [0.1, -0.4], 2],
    ['high uppercase frequency', [0.1, -0.2], 2],
    ['resembles anchor text', [0.5, -0.1], 2],
    ['occurs in marginals', [0.25, 0], 2],
    ['probable CONTENT', [-0.4, 0.2], 3],
    ['probable HEADING', [-0.4, 0.2], 3],
    [$or->('best title', 'may continue title'), [0.3, -0.8], 3],
    ['probable AUTHOR', [-0.3, 0.1], 3],
    ['resembles best title', [0.1, -0.5], 4],
    ];

$features{AUTHOR} = [
    ['among first few lines', [0.3, -0.2]],
    #[$or->('within first few pages', 'on last page'), [0.05, -0.8]],
    # need to make sure bib entries aren't taken as authors at end of
    # a paper; so right now I'm only considering authors at the start.
    ['within first few pages', [0.05, -0.8]],
    ['narrowish', [0.3, -0.3]],
    ['centered', [0.3, -0.2]],
    ['small font', [-0.2, 0.2]],
    ['begins with possible name', [0.3, -0.4]],
    ['typical list of names', [0.2, -0.2]],
    ['largest text on page', [-0.4, 0], 2],
    ['contains digit', [-0.1, 0.05], 2],
    ['gap above', [0.25, -0.3], 2],
    ['gap below', [0.15, -0.15], 2],
    ['occurs in marginals', [0.2, 0], 2],
    [$and->('best title', 'other good authors'), [-0.4, 0.05], 3],
    ['probable HEADING', [-0.8, 0.2], 3],
    ['contains publication keywords', [-0.4, 0], 3],
    #['contains year', [-0.1, 0], 3],
    ['contains page-range', [-0.3, 0], 3],
    ['contains actual name', [0.3, -0.5], 3],
    ['contains several English words', [-0.2, 0.1], 3],
    ['resembles source author', [0.1, -0.1], 3],
    ['resembles best author', [0.1, -0.5], 4],
    ];

$features{HEADING} = [
    ['large font', [0.5, -0.3]],
    ['bold', [0.3, -0.2]],
    ['all caps', [0.2, 0]],
    ['contains letters', [0, -0.5]],
    ['centered', [0.2, -0.05]],
    ['justified', [-0.4, 0]],
    ['gap above', [0.3, -0.5]],
    ['gap below', [0.2, -0.2]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['begins with section number', [0.3, -0.15]],
    ['style appears on several pages', [0.3, -0.4], 2],
    ['probable CONTENT', [-0.5, 0.05], 2],
    ['preceeds CONTENT', [0.3, -0.3], 2],
    ['follows CONTENT', [0.4, -0.2], 2],
    ];

$features{CONTENT} = [
    ['bold', [-0.3, 0.05]],
    ['centered', [-0.2, 0.1]],
    ['justified', [0.3, -0.1]],
    [$or->('gap above', 'gap below'), [-0.2, 0.1]],
    [$and->('gap above', 'gap below'), [-0.6, 0.1]],
    ['high punctuation frequency', [-0.2, 0.1]],
    ['long', [0.1, -0.2]],
    ['normal font', [0.3, -0.6]],
    ['matches content pattern', [0.2, -0.3]],
    ['begins in upper case', [-0.1, 0.3]], 
    ['preceeds CONTENT', [0.3, -0.3], 2],
    ['follows CONTENT', [0.3, -0.3], 2],
    ];

$features{ABSTRACT} = [
    ['within first few pages', [0.2, -0.8]],
    ['in abstract section', [0.8, -0.1]],
    [$or->('normal font', 'small font'), [0.1, -0.6]],
    [$or->('gap above', 'gap below'), [-0.2, 0.1]],
    [$and->('gap above', 'gap below'), [-0.6, 0.1]],
    ['begins with "abstract:"', [0.7, 0]],
    ['long', [0.2, -0.2]],
    ['matches content pattern', [0.1, -0.3]],
    ['preceeded by many ABSTRACTs', [-1, 0.1], 2],
    ['probable HEADING', [-0.6, 0.2], 3],
    ['near other ABSTRACT', [0.3, -0.3], 3],
    ['continues abstract', [0.4, -0.1], 3],
    ];

$features{ABSTRACTSTART} = [
    ['within first few pages', [0.2, -0.8]],
    ['probable ABSTRACT', [0.3, -0.5], 2],
    ['long', [0.1, -0.4], 2],
    ['previous line short', [0.2, -0.2], 2],
    ['previous line probable HEADING', [0.4, -0.1], 2],
    ['previous line probable ABSTRACT', [-0.4, 0.2], 2],
    ['previous line ends with terminator', [0.1, -0.1], 2],
    ['begins in upper case', [0.1, -0.4], 2], 
    ['begins with "abstract:"', [0.7, 0], 2],
    ['gap above', [0.2, -0.1]],
    ];

$features{ABSTRACTEND} = [
    ['within first few pages', [0.2, -0.8]],
    ['probable ABSTRACT', [0.3, -0.5], 2],
    ['next line indented', [0.2, -0.1], 2],
    ['long', [-0.1, 0.2], 2],
    ['previous line short', [-0.2, 0], 2],
    ['ends with terminator', [0.1, -0.3], 2],
    ['gap below', [0.2, -0.2]],
    ];

$features{BIB} = [
    ['in second half of paper', [0.1, -0.4]],
    ['in bibliography section', [0.5, -0.2]],
    ['begins with possible bib name', [0.15, -0.15]],
    ['contains year', [0.15, -0.15]],
    ['contains page-range', [0.15, -0.15]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['high numeral frequency', [0.1, -0.2]],
    ['high punctuation frequency', [0.1, -0.2]],
    ['near other BIBs', [0.3, -0.2], 2],
    ['resembles best BIB', [0.3, -0.6], 3],
    ['previous line BIBSTART', [0.2, 0], 3],
    ];

$features{BIBSTART} = [
    ['probable BIB', [0.2, -0.8], 2],
    ['greater gap above than below', [0.3, -0.05], 2],
    ['next line indented', [0.3, -0.1], 2],
    ['indented relative to previous line', [-0.5, 0.05], 2],
    ['long', [0.2, -0.2], 2],
    ['begins with citation label', [0.3, -0.05], 2],
    ['begins with possible bib name', [0.3, -0.05], 2],
    ['begins with dictionary word', [-0.2, 0.05], 2],
    ['begins in italic', [-0.2, 0.05], 2],
    ['begins inside quote', [-0.2, 0.05], 2],
    ['begins with dash', [0.5, 0], 2],
    ['previous line short', [0.5, -0.1], 2],
    ['previous line ends with terminator', [0.4, -0.25], 2],
    ['previous line BIBSTART', [-0.2, 0.1], 3],
    ['near other BIBs', [0.3, -0.3], 2],
    ['resembles best BIBSTART', [0.3, -0.7], 3],
    ['continues bib item', [-0.4, 0.4], 3],
    ];

1;

my @labels = qw/TITLE AUTHOR CONTENT HEADING
                ABSTRACT BIB BIBSTART/;

my %f;

sub matches {
    my $re = shift;
    return sub {
        $_[0]->{text} =~ /$re/;
    };
}

$f{'contains digit'} = matches('(?<!<sup>)\d');

$f{'line begins or ends with digit'} = sub {
    return 1 if $_[0]->{plaintext} =~ /^\d|\d$/;
    return 1 if ($_[0]->{prev} &&
                 abs($_[0]->{prev}->{top} - $_[0]->{top}) < 5 &&
                 $_[0]->{prev}->{plaintext} =~ /^\d/);
    return 1 if ($_[0]->{next} &&
                 abs($_[0]->{next}->{top} - $_[0]->{top}) < 5 &&
                 $_[0]->{next}->{plaintext} =~ /^\d/);
    return 0;
};

$f{'is digit'} = sub {
    return $_[0]->{plaintext} =~ /^\d+$/;
};

$f{'resembles other HEADERs'} = sub {
    return 0 unless $_[0]->{best}->{HEADER};
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{HEADER}}) {
        next if $_[0] == $h;
        next if abs($_[0]->{top} - $h->{top}) > 5;
        next if abs($_[0]->{fsize} - $h->{fsize}) > 1;
        next if length($_[0]->{plaintext}) != length($h->{plaintext});
        $count++;
    }
    return min(1, $count/4);
};

$f{'resembles other FOOTERs'} = sub {
    return 0 unless $_[0]->{best}->{FOOTER};
    my $num = scalar @{$_[0]->{best}->{FOOTER}} || 1;
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{FOOTER}}) {
        next if $_[0] == $h;
        next if abs($_[0]->{bottom} - $h->{bottom}) > 5;
        next if abs($_[0]->{fsize} - $h->{fsize}) > 
            $_[0]->{doc}->{fromOCR} ? 1 : 0;
        next if length($_[0]->{plaintext}) != length($h->{plaintext});
        $count++;
    }
    return min(1, $count / $num*3);
};

$f{'outside normal page dimensions'} = sub {
    return 1 if $_[0]->{bottom} < $_[0]->{doc}->{geometry}->{top};
    return 1 if $_[0]->{top} > $_[0]->{doc}->{geometry}->{bottom};
    return 0;
};

$f{'previous line FOOTER'} = sub {
    my $prev = $_[0]->{prev};
    return 0 unless $prev && $prev->{p};
    return $prev->{p}->('FOOTER');
};
 
$f{'resembles best FOOTNOTESTART'} = sub {
    return 0.5 if scalar @{$_[0]->{best}->{FOOTNOTESTART}} <= 1;
    my $best = $_[0]->{best}->{FOOTNOTESTART}->[0];
    my $ret = 1;
    $ret -= 0.6 if alignment($_[0]) ne alignment($best);
    $ret -= 0.8 if $_[0]->{fsize} != $best->{fsize};
    $ret -= 0.8 if $f{'begins with footnote label'}->($_[0])
        != $f{'begins with footnote label'}->($best);
    return max($ret, 0);
};

foreach my $label (@labels) {
    $f{"probable $label"} = sub {
        return max(0, $_[0]->{p}->($label)-0.2) * 1.25;
    };
}

$f{'narrowish'} = sub {
    my $frac = $_[0]->{width} / $_[0]->{page}->{width};
    return max(0, 1 - 2*abs(0.25 - $frac));
};

$f{'several words'} = memoize(sub { 
     $_[0]->{plaintext} =~ /\p{IsAlpha}.*\s.*\p{IsAlpha}/o;
});

$f{'long'} = memoize(sub {
    return min(length($_[0]->{plaintext})/70, 1);
});

sub in_tag {
    my $tag = shift;
    return sub {
        $_[0]->{text} =~ /^\s*
          (?:<.+>)?    # optional second tag: <i><b>title<.b><.i>
          <$tag>       # start tag 
          .+           # content
          <\/.>        # end tag
          \W*          # optional junk appended
          $/ix;
        # yes, this catches '<b>foo</b> bar <i>foo</i>'..
    };
}

$f{'bold'} = in_tag('b');

$f{'italic'} = in_tag('i');

$f{'all caps'} = sub {
    return 0 if $_[0]->{plaintext} =~ /\p{IsLower}/;
    return 1 if $_[0]->{plaintext} =~ /\p{IsUpper}/;
    return 0;
};

$f{'large font'} = memoize(sub {
    .5 + max(min($_[0]->{fsize}-2, 5), -5) / 10;
});

$f{'normal font'} = memoize(sub {
    1 - min(abs($_[0]->{fsize}), 3) / 3;
});

$f{'small font'} = memoize(sub {
    .5 + max(min(-1*$_[0]->{fsize}-1, 2), -2) / 4;
});

$f{'among first few lines'} = memoize(sub { 
    3 / max($_[0]->{id}+1, 3);
});

$f{'in second half of paper'} = memoize(sub {
    my $num = @{$_[0]->{doc}->{chunks}};
    return $_[0]->{id}+1 > $num/2 ? 1 : 0;
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
    return $_[0]->{page}->{number} == $_[0]->{doc}->{numpages};
});

$f{'preceeded by many ABSTRACTs'} = sub {
    my $ch = $_[0];
    my $n = 1;
    while ($ch = $ch->{prev}) {
        $n++ if $ch->{p}->('ABSTRACT') > 0.5;
        last if $n >= 80;
    }
    return $n/80;
};

sub alignment {
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
}

$f{'centered'} = memoize(sub {
    my $align = alignment($_[0]);
    return 1 if $align eq 'center';
    return .5 if $align eq 'justify';
    return 0;
});

$f{'justified'} = memoize(sub {
    return alignment($_[0]) eq 'justify';
});

sub gap {
    # gap($chunk, 'prev') == 2 means vertical distance to previous
    # chunk is twice the default linespacing
    my ($chunk, $dir) = @_;
    my $default = min(2, $chunk->{doc}->{linespacing});
    my $sibling = $chunk->{$dir};
    while ($sibling && $sibling->{page} == $chunk->{page}) {
        my $sp = $dir eq 'prev' ? $chunk->{top} - $sibling->{top} :
            $sibling->{top} - $chunk->{top};
        if ($sp > 5) {
            # large fonts often include large gaps:
            my $fsize = max($chunk->{fsize}, $sibling->{fsize});
            #print "** fsize: $fsize, sp: $sp => ";
            $sp *= 1 + min(0.5, $fsize/10);
            my $height = min($chunk->{height}, $sibling->{height});
            #print "$sp, height: $height, gap: ($sp/$height) / $default\n";
            return ($sp/$height) / $default;
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
    return $gap_above > $gap_below + 0.1;
});

$f{'matches title pattern'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_title;
});

$f{'matches content pattern'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_content;
});

$f{'resembles anchor text'} = memoize(sub {
    my $ret = 0;
    for my $str (@{$_[0]->{doc}->{anchortexts}}) {
        if (length($str) < 5 || $str =~ /version/i) {
            $ret = 0.5;
            next;
        }
        return 1 if (amatch($str, ['i 20%'], $_[0]->{plaintext}));
    }
    return $ret;
});
 
$f{'resembles source author'} = memoize(sub {
    for my $str (@{$_[0]->{doc}->{sourceauthors}}) {
       return 1 if (amatch($str, ['i 30%'], $_[0]->{plaintext}));
    }
    return 0;
});

$f{'occurs in marginals'} = memoize(sub {
    for my $ch (@{$_[0]->{doc}->{marginals}}) {
        next if $ch->{plaintext} =~ /^[\divx]+$/;
        return 1 if (amatch($_[0]->{plaintext}, ['i 20%'], $ch->{plaintext}));
    }
    return 0;
});

$f{'style appears on several pages'} = memoize(sub {
    my $bold = $f{'bold'}->($_[0]);
    my $caps = $f{'all caps'}->($_[0]);
    return 1 if !$bold && !$caps && ($_[0]->{fsize} == 0);
    my $chunk = $_[0]->{doc}->{chunks}->[-1];
    my $ret = 0;
    while (($chunk = $chunk->{prev})) {
        next if $chunk->{page} == $_[0]->{page};
        # skip intro bits of books:
        if ($chunk->{doc}->{numpages} - $chunk->{page}->{number} > 80
            || $chunk->{page}->{number} < 3) {
            last;
        }
        if ($chunk->{fsize} == $_[0]->{fsize}
            && length($chunk->{plaintext}) > 5
            && $f{'bold'}->($chunk) == $bold
            && $f{'all caps'}->($chunk) == $caps
            && alignment($chunk) eq alignment($_[0])) {
            #print "** $chunk->{text} has same style";
            $ret += 0.5;
            last if $ret >= 1;
        }
    }
    return $ret;
});

$f{'may continue title'} = sub {
    my @score = (0.5, 0.5);
    my $align1 = alignment($_[0]);
    foreach my $i (0, 1) {
        my $sib = $_[0]->{($i ? 'next' : 'prev')};
        unless ($sib && $sib->{page} == $_[0]->{page}) {
            $score[$i] -= 1;
            next;
        }
        $score[$i] += $sib->{p}->('TITLE') - 0.75;
        $score[$i] += 0.2 if ($sib->{plaintext} =~ /([\:\;\-\,])$/);
        $score[$i] += ($_[0]->{fsize} == $sib->{fsize}) ? 0.1 : -0.1;
        $score[$i] -= 0.3
            if $f{'all caps'}->($_[0]) != $f{'all caps'}->($sib);
        $score[$i] +=
            $f{'bold'}->($_[0]) == $f{'bold'}->($sib) ? 0.1 : -0.1;
        my $gap = gap($_[0], $i ? 'next' : 'prev');
        $score[$i] -= ($gap-1.5) / 10 if $gap;
        my $align2 = alignment($sib);
        $score[$i] -= 0.2
            if ($align1 ne 'justify' && $align2 ne 'justify'
                && $align1 ne $align2);
    }
    return min(1, max(0, $score[0], $score[1]));
};

$f{'continues abstract'} = sub {
    my $prev = $_[0]->{prev};
    unless ($prev && $prev->{page} == $_[0]->{page}
            && $prev->{top} < $_[0]->{top}
            && $prev->{fsize} == $_[0]->{fsize}
            && $f{'bold'}->($prev) == $f{'bold'}->($_[0])) {
        return 0;
    }
    my $score = 0.5;
    $score += $prev->{p}->('ABSTRACT') - 0.75;
    $score += 0.2 if ($prev->{plaintext} =~ /([\:\;\-\,\pL])$/);
    $score += 0.2 if ($_[0]->{plaintext} =~ /^\p{IsLower}/);
    $score -= (gap($_[0], 'prev')-1) / 10;
    return max(0, min(1, $score));
};

$f{'continues bib item'} = sub {
    my $prev = $_[0]->{prev};
    return 0 unless $prev && $prev->{p}->('BIB') > 0.5;
    my $score = 0.6;
    $score += 0.2 if ($prev->{plaintext} =~ /([\:\;\-\,\pL])$/);
    $score -= 0.2 if ($prev->{plaintext} =~ /\.$/);
    my $gap = gap($_[0], 'prev');
    $score -= ($gap-1) / 10 if $gap;
    return max(0, min(1, $score));
};
 
$f{'best title'} = sub {
    my $best = $_[0]->{best}->{TITLE}->[0];
    return 0 unless $best && $best->{p};
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
    return 0 if $f{'all caps'}->($_[0]) != $f{'all caps'}->($best);
    return 0 if ($_[0]->{text} =~ /,/) != ($best->{text} =~ /,/);
    # is on other side of title?
    my $title = $_[0]->{best}->{TITLE}->[0]->{id} || 0;
    return 0 if ($_[0]->{id} < $title) != ($best->{id} < $title);
    # smaller flaws:
    my $ret = 1;
    $ret -= 0.3 if alignment($_[0]) ne alignment($best);
    $ret -= abs($_[0]->{fsize} - $best->{fsize}) * 0.3;
    foreach my $feat ('bold', 'italic') {
        $ret -= 0.7 if $f{$feat}->($_[0]) != $f{$feat}->($best);
    }
    # far away:
    my $dist = abs($_[0]->{textpos} - $best->{textpos});
    $ret -= $dist/1000;
    return max($ret, 0);
};

$f{'resembles best title'} = sub {
    my $best = $_[0]->{best}->{TITLE}->[0];
    return 0 unless $best && $best->{page};
    return 1 if $_[0] == $best;
    return 0 if $_[0]->{page} != $best->{page};
    my $ret = 1;
    $ret -= 0.5 if $f{'all caps'}->($_[0]) != $f{'all caps'}->($best);
    $ret -= 0.3 if alignment($_[0]) ne alignment($best);
    $ret -= abs($_[0]->{fsize} - $best->{fsize}) * 0.2;
    foreach my $feat ('bold', 'italic') {
        $ret -= 0.3 if $f{$feat}->($_[0]) != $f{$feat}->($best);
    }
    return max($ret, 0);
};

$f{'resembles best BIB'} = sub {
    my $best = $_[0]->{best}->{BIB}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    my $ret = 1;
    $ret -= abs($_[0]->{fsize} - $best->{fsize})/5;
    $ret -= abs($_[0]->{page}->{number} - $best->{page}->{number})/10;
    my $inbib = $f{'in bibliography section'};
    $ret -= abs($inbib->($best) - $inbib->($_[0]));
    return max($ret, 0);
};

$f{'resembles best BIBSTART'} = sub {
    my $best = $_[0]->{best}->{BIBSTART}->[0];
    return 0 unless $best;
    return 1 if $_[0] == $best;
    my $ret = 1;
    $ret *= 0.3 if $_[0]->{fsize} != $best->{fsize};
    $ret *= 0.4 if abs($_[0]->{left} - $best->{left}) > 5;
    $ret *= 1 - abs($_[0]->{page}->{number} - $best->{page}->{number})/10;
    my $inbib = $f{'in bibliography section'};
    $ret *= 1 - abs($inbib->($best) - $inbib->($_[0]));
    my $citlab = $f{'begins with citation label'};
    $ret *= 0.3 if $citlab->($best) && !$citlab->($_[0]);
    return max($ret, 0);
};

$f{'like pdf author'} = sub {
    # TODO
    return 0;
};

$f{'typical list of names'} = sub {
    my $separator = qr/\s*(?:,?\s?\band\b|&amp;|,)\s*/;
    my @parts = split($separator, $_[0]->{plaintext});
    foreach my $part (@parts) {
        if ($part !~ /^
            \p{IsUpper}\pL*\.?\s(?:\p{IsUpper}\.\s)*\p{IsUpper}\S+
            $/x) {
            return 0;
        }
    }
    return 1;
};

sub in_section {
    my $re_title = shift;
    my $min_heading = 0.4;
    return sub {
        #print "** finding heading for $_[0]->{id}: $_[0]->{text}\n";
        my @chunks;
        if ($_[0]->{_headings}) {
            # only go through ancestors that have previously been
            # identified as possible section headings:
            #print "** has _headings\n";
            @chunks = @{$_[0]->{_headings}};
        }
        else {
            for (my $i = $_[0]->{id}-1; $i >= 0; $i--) {
                my $chunk = $_[0]->{doc}->{chunks}->[$i];
                #print "** adding chunk $i: $chunk->{text}\n";
                push @chunks, $chunk;
                if ($chunk->{_headings}) {
                    #print "** found _headings at $i: $chunk->{text}\n";
                    push @chunks, @{$chunk->{_headings}};
                    last;
                }
            }
        }
        $_[0]->{_headings} = [];
        my $res = 0;
        my $inbetween = 1;
        foreach my $chunk (@chunks) {
            my $p = $chunk->{p}->('HEADING');
            next unless $p > $min_heading + @{$_[0]->{_headings}}/20;
            #print "** heading $p: $chunk->{text}\n";
            push @{$_[0]->{_headings}}, $chunk;
            if ($chunk->{plaintext} =~ /$re_title/ && !$res) {
                #print "** matches regexp, * 1/$inbetween\n";
                $res = $p * 1/$inbetween;
            }
            last if @{$_[0]->{_headings}} == 5;
            $inbetween += ($p-0.2)*1.25;
        }
        #print "** result: $res\n";
        return $res;
    };
}

$f{'in bibliography section'} = in_section("^$re_bib_heading\$");

$f{'in abstract section'} = in_section("^$re_abstract\$");

$f{'previous line probable HEADING'} = sub {
    return 0.5 unless $_[0]->{prev};
    return $f{'probable HEADING'}->($_[0]->{prev});
};

$f{'previous line probable ABSTRACT'} = sub {
    return 0.5 unless $_[0]->{prev};
    return $f{'probable ABSTRACT'}->($_[0]->{prev});
};

$f{'previous line is bibliography heading'} = sub {
    if ($_[0]->{prev} &&
        $_[0]->{prev}->{plaintext} =~ /^$re_bib_heading$/) {
        return 1;
    }
    return 0;
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
$f{'near other ABSTRACT'} = someof(neighbours('prev', 'ABSTRACT'), 
                                   neighbours('next', 'ABSTRACT'));

sub mk_begins {
    my $field = shift;
    return sub {
        my ($re, $re_no) = @_;
        return sub {
            my $ch = shift;
            if ($ch->{$field} =~ /^($re)/
                && (!$re_no || $& !~ /$re_no/)) {
                return 1;
            }
            return 0;
        }
    }
};
*begins = mk_begins('text');
*begins_plain = mk_begins('plaintext');

$f{'begins with section number'} = begins_plain($re_sec_number);
 
$f{'begins in italic'} = begins('\s*<i>');

$f{'begins in upper case'} = begins_plain('\p{IsUpper}');

$f{'begins with footnote label'} = begins($re_footnote_label);

$f{'begins inside quote'} = sub {
    if ($_[0]->{plaintext} =~ /^(.+?)$re_rquote/
        && $1 !~ /$re_lquote/
        && $_[0]->{prev}
        && $_[0]->{prev}->{plaintext} =~ /$re_lquote(.+?)$/
        && $1 !~ /$re_rquote/) {
        return 1;
    }
    else {
        return 0;
    }
};

$f{'begins with citation label'} = begins_plain($re_cit_label);

$f{'begins with "abstract:"'} = begins_plain("$re_abstract.*\\w+");

$f{'begins with dash'} = begins_plain($re_dash);

$f{'begins with possible name'} = memoize(sub {
    my @parts = split($re_name_separator, $_[0]->{plaintext}, 2);
    if (@parts && $parts[0] =~
        /(?:$re_name_before)?($re_name)(?:$re_name_after)?/) {
        return 1 if $1 !~ /$re_noname/;
    }
    return 0;
});

$f{'begins with dictionary word'} = memoize(sub {
    my $w = $_[0]->{plaintext};
    $w =~ s/^(\p{Letter}+)/$1/;
    return ($w && is_word($w)) ? 1 : 0;
});

$f{'begins with possible bib name'} = 
    memoize(begins_plain("(?:$re_name)|(?:$re_name_inverted)", $re_noname));

$f{'contains possible name'} = memoize(sub {
    $_[0]->{plaintext} =~ /$re_name/;    
});

$f{'contains actual name'} = memoize(sub {
    unless (exists $_[0]->{names}) {
        $_[0]->{names} = extract_names($_[0]->{plaintext});
    }
    return max(values %{$_[0]->{names}}) || 0; 
});

$f{'contains several English words'} = memoize(sub {
    my $c = 0;
    foreach my $w (split ' ', $_[0]->{plaintext}) {
        $c++ if is_word($w);
        return 1 if $c > 3;
    }
    return $c/4;
});

$f{'contains year'} = sub {
    $_[0]->{plaintext} =~ /(?<!\d)\d{4}(?!\d)/;    
};

$f{'contains page-range'} = sub {
    $_[0]->{plaintext} =~ /\d(?:-|$re_dash)\d/;    
};

$f{'contains letters'} = sub {
    my $num_alpha = $_[0]->{plaintext} =~ tr/[a-zA-Z]//;
    return 1 if $num_alpha > 1;
    return 0 if $num_alpha == 0;
    return 0.5;
};

$f{'contains publication keywords'} = sub {
    $_[0]->{plaintext} =~ /$re_year_words|$re_publication_word|$re_journal/;    
};

sub freq {
    my ($pattern, $frequency) = @_;
    return sub {
        my $strlen = max(length($_[0]->{plaintext}), 1);
        my $num_p = 0;
        $num_p++ while $_[0]->{plaintext} =~ /$pattern/g;
        return min($num_p*$frequency / $strlen, 1);
    }
}

$f{'high uppercase frequency'} = memoize(freq('\b\p{IsUpper}', 10));

$f{'high numeral frequency'} = memoize(freq('\d', 10));

$f{'high punctuation frequency'} = memoize(freq('[,\.:\(\)\[\]-]', 5));

sub largest_text {
    my $dir = shift;
    my $count_allequal = shift;
    return sub {
        my $ch = $_[0];
        my $tolerance = $ch->{doc}->{fromOCR} ? 1 : 0;
        my $anything_smaller = 0;
        while (($ch = $ch->{$dir}) && $ch->{page} == $_[0]->{page}) {
            next if (length($ch->{plaintext}) < 5);
            return 0 if $ch->{fsize} > $_[0]->{fsize}+$tolerance;
            $anything_smaller = 1 if $ch->{fsize} < $_[0]->{fsize};
        }
        return $count_allequal ? $anything_smaller : 1;
    }
}

$f{'largest text on rest of page'} = largest_text('next');

$f{'largest text on page'} = memoize(allof(largest_text('next', 1),
                                            largest_text('prev', 1)));

$f{'rest of page has same font size'} = sub {
    my $ch = $_[0];
    my $tolerance = $ch->{doc}->{fromOCR} ? 1 : 0;
    while (($ch = $ch->{next}) && $ch->{page} == $_[0]->{page}) {
        next if (length($ch->{plaintext}) < 5);
        return 0 if $ch->{fsize} > $_[0]->{fsize}+$tolerance
            || $ch->{fsize} < $_[0]->{fsize}-$tolerance; 
    }
    return 1;
};

$f{'previous line has larger font'} = sub {
    my $tolerance = $_[0]->{doc}->{fromOCR} ? 1 : 0;
    if ($_[0]->{prev} && $_[0]->{page} == $_[0]->{prev}->{page}
        && $_[0]->{prev}->{fsize} > $_[0]->{fsize}+$tolerance) {
        return 1;
    }
    return 0;
};

$f{'previous line short'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return max(min(2 - length($prev->{plaintext})/40, 1), 0);
});

$f{'ends with terminator'} = memoize(sub {
    if ($_[0]->{plaintext} =~
        /(\S+)([\.!\?])\s*(?:$re_rquote)?(.?)\s*$/o) {
        # discount endings like "ed." or "Vol." or "J.A.":
        return 0.75 if $1 && length($1) < 4 && $2 eq '.';
        return 1;
    }
    return 0;
});

$f{'previous line ends with terminator'} = memoize(sub {
    return 0.5 unless $_[0]->{prev};
    return $f{'ends with terminator'}->($_[0]->{prev});
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
    my $gap = gap($_[0], 'next');
    return 0.5 unless ($gap && $gap < 2);
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

possible categories to add:

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
   - epigraph
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

