package rules::Line_Features;
use warnings;
use strict;
use File::Basename;
use Cwd 'abs_path';
use String::Approx 'amatch';
use Memoize;
use List::Util qw/min max reduce/;
use Lingua::Stem::Snowball;
use util::Functools qw/someof allof/;
use util::String;
use rules::Helper;
use rules::NameExtractor;
use rules::Keywords;
use Exporter;
use Data::Dumper;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%features/;


our %features;

$features{HEADER} = [
    ['gap below', [0.2, -0.2]],
    ['small font', [0.2, -0.2]],
    ['line begins or ends with digit', [0.2, -0.1]],
    ['outside normal page dimensions', [0.2, -0.1]],
    ['text recurs on top of several other pages', [0.6, -0.2]],
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
    ['among first few lines', [0.2, -0.3]],
    ['within first few pages', [0.1, -1]],
    ['long', [-0.1, 0.1]],
    [$and->('large font', 'largest text on rest of page'), [0.5, -0.5], 2],
    ['largest text on page', [0.2, -0.2], 2],
    ['bold', [0.3, -0.05], 2],
    ['all caps', [0.2, 0], 2],
    ['centered', [0.3, -0.2], 2],
    ['gap above', [0.3, -0.3], 2],
    ['gap below', [0.2, -0.2], 2],
    ['style appears on several pages', [-0.3, 0], 2],
    ['contains letters', [0, -0.7], 2],
    ['contains publication keywords', [-0.5, 0.1], 2],
    ['contains address words', [-0.3, 0.1], 2],
    ['contains other bad title words', [-0.4, 0.1], 2],
    ['abstract heading', [-0.5, 0], 2],
    ['possible date', [-0.5, 0], 2],
    [$or->('several words', 'in continuation with good TITLE'), [0.1, -0.4], 2],
    ['high uppercase frequency', [0.1, -0.2], 2],
    ['resembles anchor text', [0.5, -0.1], 2],
    ['occurs in marginals', [0.4, 0], 2],
    ['occurs on source page', [0.2, -0.5], 2],
    ['probable CONTENT', [-0.4, 0.2], 3],
    ['probable HEADING', [-0.4, 0.2], 3],
    #['words common in content', [0.1, -0.3], 3],
    ['probable AUTHOR', [-0.3, 0.1], 4],
    [$and->('best AUTHOR', 'other good TITLEs'), [-0.7, 0.05], 4],
    [$or->('best TITLE', 'in continuation with good TITLE'), [0.5, -0.8], 5],
    ['separated from AUTHOR only by TITLE', [0.2, -0.6], 5],
    ['resembles best TITLE', [0.1, -0.6], 5],
    ];

$features{AUTHOR} = [
    ['among first few lines', [0.3, -0.2]],
    #[$or->('within first few pages', 'on last page'), [0.05, -0.8]],
    # need to make sure bib entries aren't taken as authors at end of
    # a paper; so right now I'm only considering authors at the start.
    ['within first few pages', [0.05, -0.8]],
    ['long', [-0.2, 0.2]],
    ['centered', [0.3, -0.2]],
    ['small font', [-0.2, 0.2]],
    ['several words', [0, -0.5]],
    ['begins with possible name', [0.3, -0.4]],
    ['typical list of names', [0.2, 0]],
    #['SEP author', [1, -1]],
    ['largest text on page', [-0.2, 0], 2],
    ['contains digit', [-0.1, 0.05], 2],
    ['gap above', [0.25, -0.3], 2],
    ['gap below', [0.15, -0.15], 2],
    ['occurs in marginals', [0.2, 0], 2],
    [$and->('best TITLE', 'other good AUTHORs'), [-0.4, 0.05], 3],
    ['probable HEADING', [-0.7, 0.2], 3],
    #['probable ABSTRACTSTART', [-0.6, 0.2], 3],
    ['contains publication keywords', [-0.4, 0], 3],
    #['contains year', [-0.1, 0], 3],
    ['contains page-range', [-0.3, 0], 3],
    ['contains probable name', [0.4, -0.8], 3],
    ['contains several English words', [-0.2, 0.1], 3],
    ['resembles source author', [0.1, -0.1], 3],
    [$or->('near good TITLE', 'near other good AUTHORs'), [0.2, -0.5], 4],
    ['resembles best AUTHOR', [0.1, -0.5], 5],
    ];

$features{HEADING} = [
    ['large font', [0.5, -0.3]],
    ['bold', [0.3, -0.2]],
    ['all caps', [0.2, 0]],
    ['contains letters', [0, -0.5]],
    ['centered', [0.2, -0.05]],
    ['justified', [-0.3, 0]],
    ['gap above', [0.3, -0.5]],
    ['gap below', [0.2, -0.2]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['begins with section number', [0.4, -0.15]],
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
    ['continues abstract', [0.5, -0.1], 3],
    ['a lot of earlier ABSTRACTs', [-1, 0.1], 3],
    ['near other ABSTRACT', [0.3, -0.3], 3],
    ['probable HEADING', [-0.6, 0.2], 3],
    ];

$features{ABSTRACTSTART} = [
    ['within first few pages', [0.2, -0.8]],
    ['probable ABSTRACT', [0.3, -0.5], 2],
    ['long', [0.1, -0.4], 2],
    ['previous line short', [0.2, -0.2], 2],
    ['same length as previous line', [-0.7, 0], 2],
    ['gap above', [0.2, -0.2]],
    ['previous line probable HEADING', [0.4, -0.1], 2],
    ['previous line probable ABSTRACT', [-0.4, 0.2], 2],
    ['begins in upper case', [0.1, -0.4], 2], 
    ['begins with "abstract:"', [0.7, 0], 2],
    ['previous line is abstract heading', [0.7, 0], 2],
    ];

$features{ABSTRACTEND} = [
    ['within first few pages', [0.2, -0.8]],
    ['probable ABSTRACT', [0.3, -0.1], 2], # min 0.5!
    ['next line indented', [0.2, 0], 2],
    ['long', [-0.1, 0.2], 2],
    ['previous line short', [-0.2, 0], 2],
    ['ends with terminator', [0.2, -0.3], 2],
    ['gap below', [0.3, -0.2]],
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
                ABSTRACT ABSTRACTSTART BIB BIBSTART/;

my %f;

sub matches {
    my $re = shift;
    return sub {
        $_[0]->{text} =~ /$re/;
    };
}

$f{'contains digit'} = matches('(?<!<sup>)\d');

$f{'possible date'} = matches('[12]\d{3}\s*$');

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

$f{'text recurs on top of several other pages'} = sub {
    return undef unless $_[0]->{doc}->{numpages} > 3;
    my $txt1 = $_[0]->{plaintext};
    $txt1 =~ s/\d|\s//g; # strip page numbers and whitespace
    return undef unless $txt1;
    my $count = 0;
    for my $page (@{$_[0]->{doc}->{pages}}) {
        for my $i (0..2) {
            next unless exists $page->{chunks}->[$i];
            my $txt2 = $page->{chunks}->[$i]->{plaintext};
            $txt2 =~ s/\d|\s//g;
            $count++ if $txt1 eq $txt2;
            return 1 if $count > 2;
        }
    }
    return 0;
};

$f{'resembles other HEADERs'} = sub {
    return undef unless $_[0]->{best}->{HEADER};
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{HEADER}}) {
        next if $_[0] eq $h;
        next if abs($_[0]->{top} - $h->{top}) > 5;
        next if abs($_[0]->{fsize} - $h->{fsize}) > 1;
        next if length($_[0]->{plaintext}) != length($h->{plaintext});
        $count++;
    }
    return min(1, $count/4);
};

$f{'resembles other FOOTERs'} = sub {
    return undef unless $_[0]->{best}->{FOOTER};
    my $num = scalar @{$_[0]->{best}->{FOOTER}} || 1;
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{FOOTER}}) {
        next if $_[0] eq $h;
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
    return undef unless @{$_[0]->{best}->{FOOTNOTESTART}};
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
        # less than 0.3 is 0, more than 0.9 is 1:
        return min(1, max(0, ($_[0]->{p}->($label)-0.3) * 1.6))
    };
}

$f{'narrowish'} = sub {
    my $frac = $_[0]->{width} / $_[0]->{page}->{width};
    return max(0, 1 - 2*abs(0.25 - $frac));
};

$f{'several words'} = memoize(sub { 
     $_[0]->{plaintext} =~ /\p{IsAlpha}{2,}.*\s.*\p{IsAlpha}{2,}/o;
});

$f{'long'} = memoize(sub {
    return min(length($_[0]->{plaintext})/70, 1);
});

sub in_tag {
    my $tag = shift;
    return sub {
        my $remainder = $_[0]->{text};
        $remainder =~ s/<$tag>.*?<\/$tag>//gi;
        $remainder = strip_tags($remainder);
        return $remainder !~ /\w/;
    };
}

$f{'bold'} = in_tag('b');

$f{'italic'} = in_tag('i');

$f{'all caps'} = memoize(sub {
    return 0 if $_[0]->{plaintext} =~ /[a-z]/;
    return 1 if $_[0]->{plaintext} =~ /[A-Z]/;
    return 0;
});

$f{'large font'} = memoize(sub {
    if ($_[0]->{doc}->{largest_font} == 0) {
        # no large font in document
        return undef;
    }
    return .5 + max(min($_[0]->{fsize}-2, 5), -5) / 10;
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

$f{'a lot of earlier ABSTRACTs'} = sub {
    my $ch = $_[0];
    my $n = 1;
    while (($ch = $ch->{prev})) {
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
    while ($sibling && $sibling->{page} eq $chunk->{page}) {
        my $sp = $dir eq 'prev' ? $chunk->{top} - $sibling->{top} :
            $sibling->{top} - $chunk->{top};
        if ($sp > 5) {
            # large fonts often include large gaps:
            my $fsize = max($chunk->{fsize}, $sibling->{fsize});
            #print "** fsize: $fsize, sp: $sp => ";
            $sp *= 1 + min(0.5, $fsize/10);
            my $height = min($chunk->{height}, $sibling->{height});
            my $spacing = $sp/$height;
            #print "** $sp, height: $height, gap: $spacing / $default\n";
            return $spacing / $default;
        }
        $sibling = $sibling->{$dir};
    }
    # no sibling:
    return 0;
};

$f{'gap above'} = memoize(sub {
    my $gap = gap($_[0], 'prev');
    return 1 unless $gap; # no element above
    return max(min($gap-1, 1), 0);
});

$f{'gap below'} = memoize(sub {
    my $gap = gap($_[0], 'next');
    return 1 unless $gap; # no element below
    return max(min($gap-1, 1), 0);
});

$f{'greater gap above than below'} = memoize(sub {
    my $gap_above = gap($_[0], 'prev');
    my $gap_below = gap($_[0], 'next');
    return undef unless $gap_above and $gap_below;
    return $gap_above > ($gap_below + 0.1);
});

my $re_address_word = qr/\b(?:
    universit\w+|institute?|college|
    avenue|street|professor|department|program|
    umass|uc
    )\b/ix;
$f{'contains address words'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_address_word;
});

my $re_bad_title = qr/\b(?:thanks?|@|[12]\d{3})/ix;
$f{'contains other bad title words'} = memoize(sub {
   $_[0]->{plaintext} =~ $re_bad_title;
});

$f{'abstract heading'} = sub {
   $_[0]->{plaintext} =~ /^\W*abstract\W*$/i;
};

$f{'matches content pattern'} = memoize(sub {
    $_[0]->{plaintext} =~ $re_content;
});

$f{'resembles anchor text'} = memoize(sub {
    my $atxt = $_[0]->{doc}->{anchortext};
    if (length($atxt) < 5 || $atxt =~ /version/i) {
        return undef;
    }
    if (amatch($atxt, ['i 20%'], $_[0]->{plaintext})) {
        return 1;
    }
    # current line might only be part of the full title:
    return is_rough_substring($_[0]->{plaintext}, $_[0]->{doc}->{anchortext});
});
 
$f{'resembles source author'} = memoize(sub {
    # xxx TODO should check name in {plaintext}, not text itself!
    return undef unless @{$_[0]->{doc}->{sourceauthors}};
    for my $str (@{$_[0]->{doc}->{sourceauthors}}) {
       return 1 if (amatch($str, ['i 30%'], $_[0]->{plaintext}));
    }
    return 0;
});

$f{'occurs on source page'} = memoize(sub {
    return undef unless $_[0]->{doc}->{sourcecontent};
    return is_rough_substring($_[0]->{plaintext}, $_[0]->{doc}->{sourcecontent});
});

$f{'occurs in marginals'} = memoize(sub {
    return undef if length($_[0]->{plaintext}) < 5;
    for my $ch (@{$_[0]->{doc}->{marginals}}) {
        next if $ch->{plaintext} =~ /^[\divx]+$/;
        return 1 if (amatch($_[0]->{plaintext}, ['i 20%'], $ch->{plaintext}));
    }
    return 0;
});

sub style_similarity {
    my ($ch1, $ch2) = @_;
    my $score = 1;
    $score *= 0.2 if $f{'bold'}->($ch1) != $f{'bold'}->($ch2);
    $score *= 0.2 if $f{'all caps'}->($ch1) != $f{'all caps'}->($ch2);
    $score *= 0.2 if $ch1->{fsize} != $ch2->{fsize};
    my $a1 = alignment($ch1);
    my $a2 = alignment($ch2);
    $score *= 0.8 if ($a2 ne 'justify' && $a2 ne 'justify' && $a1 ne $a2);
    return $score;
}

$f{'style appears on several pages'} = memoize(sub {
    my $numpages = $_[0]->{doc}->{numpages};
    return undef if $numpages < 2;
    my $ret = 0;
    my $ch = $_[0]->{doc}->{chunks}->[-1];
    while (($ch = $ch->{prev})) {
        next if length($ch->{plaintext}) < 5;
        next if $ch->{page} eq $_[0]->{page};
        # ignore intro pages:
        last if $ch->{page}->{number} <= ($numpages/5 + 1);
        if (style_similarity($_[0], $ch) >= 0.8) {
            $ret += 0.5;
        }
        return 1 if $ret >= 1;
    }
    return $ret;
});

$f{'in continuation with good TITLE'} = sub {
    my $best = $_[0]->{best}->{TITLE}->[0];
    return undef unless $best;
    my $best_p = $best->{p}->('TITLE');
    my @score = (1, 1); # prev, next
    foreach my $i (0, 1) {
        my $sib = $_[0]->{($i ? 'next' : 'prev')};
        unless ($sib && $sib->{page} eq $_[0]->{page}) {
            $score[$i] = 0;
            next;
        }
        $score[$i] *= ($sib->{p}->('TITLE')/$best_p) ** 2; 
        $score[$i] *= max(0.5, style_similarity($sib, $_[0]));
        my $gap = gap($_[0], $i ? 'next' : 'prev');
        $score[$i] *= max(0.5, min(1, 1.2/$gap)) if $gap;
        if ($i == 1) { # $sib is before $_[0]
            $score[$i] *= 1.5 if ($sib->{plaintext} =~ /([\:\;\-\,])$/);
        }
    }
    return min(1, max(0, $score[0], $score[1]));
};

$f{'words common in content'} = memoize(sub {
    # Assigning CONTENT labels to all text chunks takes a while, so
    # we use a simpler heuristic:
    unless ($_[0]->{doc}->{rough_content}) {
        my @txt;
        for my $page (@{$_[0]->{doc}->{pages}}) {
            for (3 .. $#{$page->{chunks}}-3) {
                push @txt, $page->{chunks}->[$_]->{plaintext};
            }
        }
        # set aside first 10% and last 20%:
        if (scalar @txt > 10) {
            @txt = @txt[int($#txt/10) .. int($#txt - $#txt/5)];
        }
        $_[0]->{doc}->{rough_content} = join("\n", @txt);
    }
    # 1 page is roughly 3000 chars, once per page is minimum for "common"
    my $common_freq = length($_[0]->{doc}->{rough_content})/3000;
    my $min_freq = 1000;
    my @words = ($_[0]->{plaintext} =~ /\w{4,}/ig);
    my $stemmer = Lingua::Stem::Snowball->new( lang => 'en' );
    $stemmer->stem_in_place( \@words );
    for my $w (@words) {
        my $count = () = ($_[0]->{doc}->{rough_content} =~ /$w/ig);
        #print "=== $w: $count\n";
        $min_freq = min($min_freq, $count);
    }
    return min(1, $min_freq/$common_freq);
});

$f{'continues abstract'} = sub {
    my $prev = $_[0]->{prev};
    unless ($prev && $prev->{page} eq $_[0]->{page}
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

sub is_best {
    my $label = shift;
    return sub {
        my $best = $_[0]->{best}->{$label}->[0];
        return undef unless $best;
        return 1 if $_[0] eq $best;
        my $dist = $best->{p}->($label) - $_[0]->{p}->($label);
        return max(1 - $dist*10, 0);
    };
}
 
$f{'best TITLE'} = is_best('TITLE');

$f{'best AUTHOR'} = is_best('AUTHOR');

sub other_good {
    my $label = shift;
    return sub {
        my $ch = $_[0]->{best}->{$label}->[0];
        return 0 unless $ch;
        return 1 if $_[0] ne $ch;
        $ch = $_[0]->{best}->{$label}->[1];
        return 0 unless $ch;
        my $dist = $_[0]->{p}->($label) - $ch->{p}->($label);
        return max(1 - $dist*4, 0); 
    };
}

$f{'other good TITLEs'} = other_good('TITLE');

$f{'other good AUTHORs'} = other_good('AUTHOR');

$f{'resembles best AUTHOR'} = sub {
    my $best = $_[0]->{best}->{AUTHOR}->[0];
    return undef unless $best;
    return 1 if $_[0] eq $best;
    return 0 if $_[0]->{page} ne $best->{page};
    return 0 if $f{'all caps'}->($_[0]) != $f{'all caps'}->($best);
    return 0 if ($_[0]->{text} =~ /,/) != ($best->{text} =~ /,/);
    # is on other side of title?
    if (@{$_[0]->{best}->{TITLE}}) {
        my $title = $_[0]->{best}->{TITLE}->[0]->{id};
        return 0 if ($_[0]->{id} < $title) != ($best->{id} < $title);
    }
    # smaller flaws:
    my $ret = 1;
    $ret -= 0.3 if alignment($_[0]) ne alignment($best);
    $ret -= abs($_[0]->{fsize} - $best->{fsize}) * 0.3;
    foreach my $feat ('bold', 'italic') {
        $ret -= 0.7 if $f{$feat}->($_[0]) != $f{$feat}->($best);
    }
    # far away:
    #my $dist = abs($_[0]->{textpos} - $best->{textpos});
    #$ret -= $dist/1000;
    return max($ret, 0);
};

$f{'resembles best TITLE'} = sub {
    my $best = $_[0]->{best}->{TITLE}->[0];
    return undef unless $best;
    return 1 if $_[0] eq $best;
    return 0 if $_[0]->{page} ne $best->{page};
    my $ret = 1;
    $ret -= 0.5 if $f{'all caps'}->($_[0]) != $f{'all caps'}->($best);
    $ret -= 0.3 if alignment($_[0]) ne alignment($best);
    $ret -= max(0.5, abs($_[0]->{fsize} - $best->{fsize}) * 0.1);
    foreach my $feat ('bold', 'italic') {
        $ret -= 0.3 if $f{$feat}->($_[0]) != $f{$feat}->($best);
    }
    return max($ret, 0);
};

$f{'resembles best BIB'} = sub {
    my $best = $_[0]->{best}->{BIB}->[0];
    return 0 unless $best;
    return 1 if $_[0] eq $best;
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
    return 1 if $_[0] eq $best;
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

$f{'SEP author'} = sub {
    return undef if ($_[0]->{doc}->{url} !~ /stanford\.edu\/entries/);
    # e.g.: Valentin Goranko &lt;<i>valentin.goranko@philosophy.su.se</i>&gt;
    return ($_[0]->{text} =~ /\w+ &lt;.+@.+&gt;$/);
};

$f{'typical list of names'} = sub {
    my $separator = qr/\s*(?:,?\s?\band\b|&amp;|,)\s*/;
    my @parts = split($separator, $_[0]->{plaintext});
    return 0 if @parts == 1;
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

$f{'previous line is abstract heading'} = sub {
    if ($_[0]->{prev} &&
        $_[0]->{prev}->{plaintext} =~ /^abstract.?/i) {
        return 1;
    }
    return 0;
};

$f{'separated from AUTHOR only by TITLE'} = sub {
    my %au_lookup = map { $_ => 1 } @{$_[0]->{best}->{AUTHOR}};
    my %ti_lookup = map { $_ => 1 } @{$_[0]->{best}->{TITLE}};
    return undef unless %au_lookup;
    my $best_au_p = 0;
    for my $dir ('next', 'prev') {
        my $ch = $_[0];
        while ($ch && (exists $au_lookup{$ch} || exists $ti_lookup{$ch})) {
            $best_au_p = max($best_au_p, $ch->{p}->('AUTHOR'));
            $ch = $ch->{$dir};
        }
    }
    return max(0, min(1, $best_au_p-0.3)*2);
};

$f{'near good TITLE'} = sub {
    my %ti_lookup = map { $_ => 1 } @{$_[0]->{best}->{TITLE}};
    return undef unless %ti_lookup;
    my $best_ti_p = 0;
    for my $dir ('next', 'prev') {
        my $ch = $_[0];
        for my $dist (0..3) {
            if (exists $ti_lookup{$ch}) {
                my $weight = ($dist < 2) ? 1 : 0.2+1/$dist;
                $best_ti_p = max($best_ti_p, $ch->{p}->('TITLE')*$weight);
            }
            $ch = $ch->{$dir};
            last unless $ch;
        }
    }
    return $best_ti_p;
};

$f{'near other good AUTHORs'} = sub {
    my %au_lookup = map { $_ => 1 } @{$_[0]->{best}->{AUTHOR}};
    return undef unless %au_lookup;
    my $best_au_p = 0;
    for my $dir ('next', 'prev') {
        my $ch = $_[0];
        for my $dist (1..4) {
            $ch = $ch->{$dir};
            last unless $ch;
            if (exists $au_lookup{$ch}) {
                my $weight = ($dist < 2) ? 1 : 0.2+1/$dist;
                $best_au_p = max($best_au_p, $ch->{p}->('AUTHOR')*$weight);
            }
        }
    }
    return $best_au_p;
};

sub neighbourhood {
    my ($dir, $label) = @_;
    return sub {
        my $ch = $_[0];
        my $res = 0;
        while (($ch = $ch->{$dir})) {
            next unless length($ch->{plaintext}) > 5;
            return $res unless $ch->{p}->($label) > 0.5;
            $res += (1-$res)/2; 
            return 1 if $res > 0.9;
        }
        return $res;
    };
}

$f{'follows CONTENT'} = neighbourhood('prev', 'CONTENT', 1);
$f{'preceeds CONTENT'} = neighbourhood('next', 'CONTENT', 1);
$f{'near other BIBs'} = someof(neighbourhood('prev', 'BIB', 1), 
                               neighbourhood('next', 'BIB', 1));
$f{'near other ABSTRACT'} = someof(neighbourhood('prev', 'ABSTRACT', 1), 
                                   neighbourhood('next', 'ABSTRACT', 1));

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

$f{'contains probable name'} = memoize(sub {
    unless (exists $_[0]->{names}) {
        $_[0]->{names} = rules::NameExtractor::parse($_[0]);
    }
    return 0 unless %{$_[0]->{names}};
    return max(values(%{$_[0]->{names}}));
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
    $_[0]->{plaintext} =~ /(?<!\d)[12]\d{3}(?!\d)/;    
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
    $_[0]->{plaintext} =~ /$re_year_words|$re_publication_word|$re_journal/i;    
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
    return sub {
        my $ch = $_[0];
        if ($ch->{doc}->{largest_font} == 0) {
            # no large font in document
            return undef;
        }
        my $largest_size = 0;
        while (($ch = $ch->{$dir}) && $ch->{page} eq $_[0]->{page}) {
            next if (length($ch->{plaintext}) < 5);
            $largest_size = max($largest_size, $ch->{fsize});
        }
        my $diff = $_[0]->{fsize} - $largest_size;
        # return 1 if nothing is as large, 0.8 if other chunks equally
        # large, 0 if other chunks significantly larger:
        return min(1, max(0, 0.8 + $diff/3));
    }
}



$f{'largest text on rest of page'} = largest_text('next');

$f{'largest text on page'} = memoize(allof(largest_text('next'),
                                           largest_text('prev')));

$f{'rest of page has same font size'} = sub {
    my $ch = $_[0];
    my $tolerance = $ch->{doc}->{fromOCR} ? 1 : 0;
    while (($ch = $ch->{next}) && $ch->{page} eq $_[0]->{page}) {
        next if (length($ch->{plaintext}) < 5);
        return 0 if $ch->{fsize} > $_[0]->{fsize}+$tolerance
            || $ch->{fsize} < $_[0]->{fsize}-$tolerance; 
    }
    return 1;
};

$f{'previous line has larger font'} = sub {
    my $tolerance = $_[0]->{doc}->{fromOCR} ? 1 : 0;
    if ($_[0]->{prev} && $_[0]->{page} eq $_[0]->{prev}->{page}
        && $_[0]->{prev}->{fsize} > $_[0]->{fsize}+$tolerance) {
        return 1;
    }
    return 0;
};

$f{'previous line short'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return undef unless $prev;
    return max(min(2 - length($prev->{plaintext})/40, 1), 0);
});

$f{'same length as previous line'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return undef unless $prev;
    return 0 if abs($_[0]->{left} - $prev->{left}) > 5;
    return 0 if abs($_[0]->{right} - $prev->{right}) > 5;
    return 1;
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
    return undef unless $_[0]->{prev};
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

