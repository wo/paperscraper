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

$features{HEADER} = [
    ['gap below', [0.2, -0.3]],
    ['small font', [0.2, -0.2]],
    ['begins or ends with digit', [0.2, -0.1]],
    ['resembles other HEADERs', [0.2, -0.3], 2]
    ];

$features{FOOTER} = [
    ['gap above', [0.2, -0.3]],
    ['small font', [0.2, -0.2]],
    ['is digit', [0.3, -0.1]],
    ['resembles other FOOTERs', [0.2, -0.3], 2]
    ];

$features{FOOTNOTESTART} = [
    ['gap above', [0.1, -0.1]],
    ['small font', [0.5, -0.5]],
    ['long', [0.1, -0.2]],
    ['previous line has larger font', [0.2, -0.3]],
    ['indented relative to previous line', [0.1, -0.15], 2],
    ['begins with footnote label', [0.3, -0.1], 2],
    ['rest of page has same font size', [0.15, -0.5], 2],
    ['near bottom of page', [0.1, -0.1], 2],
    ['resembles best FOOTNOTESTART', [0.2, -0.3], 3],
    ];

$features{TITLE} = [
    ['among first few lines', [0.4, -0.3]],
    ['within first few pages', [0.1, -1]],
    [$and->('large font', 'largest text on rest of page'), [0.5, -0.6], 2],
    ['largest text on rest of page', [0.2, 0], 2],
    ['bold', [0.3, -0.05], 2],
    ['centered', [0.3, -0.2], 2],
    ['gap above', [0.3, -0.3], 2],
    ['gap below', [0.2, -0.2], 2],
    ['matches title pattern', [0.1, -0.5], 2],
    ['several words', [0.1, -0.3], 2],
    ['high uppercase frequency', [0.1, -0.2], 2],
    [$or->('best title', 'may continue title'), [0.1, -0.4], 3],
    ['probable HEADING', [-0.2, 0.1], 3],
    ['probable AUTHOR', [-0.2, 0.05], 3],
    ];

if (defined $_[0]->{doc}->{anchortexts}) { # TODO
    push @{$features{'TITLE'}},
         ['resembles anchor text', [0.6, 0], 2];
}

$features{AUTHOR} = [
    ['among first few lines', [0.3, -0.2]],
    #[$or->('within first few pages', 'on last page'), [0.05, -0.8]],
    # need to make sure bib entries aren't taken as authors at end of
    # a paper; so right now I'm only considering authors at the start.
    ['within first few pages', [0.05, -0.8]],
    ['narrowish', [0.3, -0.3]],
    ['centered', [0.3, -0.2]],
    ['small font', [-0.2, 0.2]],
    ['begins with possible name', [0.4, -0.5]],
    ['largest text on page', [-0.4, 0], 2],
    ['contains digit', [-0.2, 0.05], 2],
    ['gap above', [0.25, -0.3], 2],
    ['gap below', [0.15, -0.15], 2],
    [$and->('best title', 'other good authors'), [-0.3, 0.05], 3],
    ['probable HEADING', [-0.3, 0.1], 3],
    ['contains publication keywords', [-0.4, 0], 3],
    ['contains year', [-0.1, 0], 3],
    ['contains page-range', [-0.3, 0], 3],
    ['contains actual name', [0.2, -0.4], 3],
    ['contains several English words', [-0.4, 0.1], 3],
    ['resembles best author', [0.1, -0.5], 4],
    ];

$features{HEADING} = [
    ['large font', [0.5, -0.3]],
    ['bold', [0.3, -0.2]],
    ['contains letters', [0, -0.5]],
    ['centered', [0.2, -0.05]],
    ['justified', [-0.4, 0]],
    ['gap above', [0.3, -0.4]],
    ['gap below', [0.2, -0.2]],
    ['high uppercase frequency', [0.1, -0.2]],
    ['begins with section number', [0.4, -0.1]],
    ['probable CONTENT', [-0.5, 0.05], 3],
    ['preceeds CONTENT', [0.3, -0.3], 3],
    ['follows CONTENT', [0.4, -0.2], 3],
    ];

$features{ABSTRACTSTART} = [
    ['"abstract" heading', [1, -0.3]],
    [$and->('begins with "abstract:"', 'gap above'), [0.8, -0.3], 1],
    # recursive:
    ['preceeds CONTENT', [0.1, -0,3], 4],
    ];

$features{CONTENT} = [
    ['bold', [-0.3, 0.05]],
    ['centered', [-0.5, 0.1]],
    ['justified', [0.3, -0.1]],
    [$or->('gap above', 'gap below'), [-0.2, 0.1]],
    [$and->('gap above', 'gap below'), [-0.6, 0.1]],
    ['high punctuation frequency', [-0.2, 0.1]],
    ['long', [0.1, -0.2]],
    ['normal font', [0.3, -0.6]],
    ['matches content pattern', [0.2, -0.3]],
    ];

$features{ABSTRACTCONTENT} = [
    [$or->('normal font', 'small font'), [0.3, -0.6]],
    ['centered', [-0.2, 0.1]],
    ['justified', [0.2, -0.1]],
    [$or->('gap above', 'gap below'), [-0.2, 0.1]],
    [$and->('gap above', 'gap below'), [-0.6, 0.1]],
    ['high punctuation frequency', [-0.2, 0.1]],
    ['long', [0.1, -0.2]],
    ['matches content pattern', [0.2, -0.3]],
    ['not far into content', [0.2, -0.8], 2],
    ['near other ABSTRACTCONTENT', [0.3, -0.3], 3],
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
    ];

$features{BIBSTART} = [
    ['probable BIB', [0.2, -0.8], 2],
    ['greater gap above than below', [0.3, -0.05], 2],
    ['next line indented', [0.3, -0.1], 2],
    ['indented relative to previous line', [-0.4, 0.05], 2],
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

$f{'begins or ends with digit'} = matches('^\d|\d$');

$f{'is digit'} = matches('^\d+$');

$f{'resembles other HEADERs'} = sub {
    my $num = scalar @{$_[0]->{best}->{HEADER}} || 1;
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{HEADER}}) {
        next if $_[0] == $h;
        next if $_[0]->{top} != $h->{top};
        next if $_[0]->{fsize} != $h->{fsize};
        next if length($_[0]->{text}) != length($h->{text});
        $count++;
    }
    return min(1, $count / $num*2);
};

$f{'resembles other FOOTERs'} = sub {
    my $num = scalar @{$_[0]->{best}->{FOOTER}} || 1;
    my $count = 0;
    foreach my $h (@{$_[0]->{best}->{FOOTER}}) {
        next if $_[0] == $h;
        next if $_[0]->{bottom} != $h->{bottom};
        next if $_[0]->{fsize} != $h->{fsize};
        next if length($_[0]->{text}) != length($h->{text});
        $count++;
    }
    return min(1, $count / $num*3);
};

$f{'resembles best FOOTNOTESTART'} = sub {
    my $best = $_[0]->{best}->{FOOTNOTESTART}->[0];
    return 0 unless $best;
    my $ret = 1;
    $ret -= 0.6 if alignment($_[0]) ne alignment($best);
    $ret -= 0.8 if $_[0]->{fsize} != $best->{fsize};
    $ret -= 0.8 if $f{'begins with footnote label'}->($_[0])
        != $f{'begins with footnote label'}->($best);
    return max($ret, 0);
};

foreach my $label (@labels) {
    $f{"probable $label"} = sub {
        return $_[0]->{p}->($label);
    };
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
    .5 + max(min(-1*$_[0]->{fsize}-1, 3), -3) / 6;
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
    return $_[0]->{page}->{number} == $_[0]->{doc}->{pages};
});

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
    my $default = min(1.5, $chunk->{doc}->{linespacing});
    my $sibling = $chunk->{$dir};
    while ($sibling && $sibling->{page} == $chunk->{page}) {
        my $sp = $dir eq 'prev' ? $chunk->{top} - $sibling->{top} :
            $sibling->{top} - $chunk->{top};
        if ($sp > 0) {
            # large fonts often include large gaps:
            my $fsize = max($chunk->{fsize}, $sibling->{fsize});
            #print "** fsize: $fsize, sp: $sp => ";
            $sp *= 1 + $fsize/10;
            my $height = min($chunk->{height}, $sibling->{height});
            #print "$sp, $height: $height, gap: ($sp/$height) / $default\n";
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
    for my $a (@{$_[0]->{doc}->{anchortexts}}) {
        return 1 if (amatch($a, ['i 30%'], $_[0]->{plaintext}));
    }
    return 0;
});
 
$f{'may continue title'} = sub {
    # errs on the side of 'yes'
    my $prev = $_[0]->{prev};
    return 0 unless $prev && $prev->{page} == $_[0]->{page};
    my $score = 0.5;
    $score += $prev->{p}->('TITLE') - 0.8;
    $score += 0.2 if ($prev->{plaintext} =~ /([\:\;\-\,])$/);
    $score += ($_[0]->{fsize} == $prev->{fsize}) ? 0.1 : -0.1;
    $score -= (gap($_[0], 'prev')-1.5) / 10;
    my $align1 = alignment($_[0]);
    my $align2 = alignment($prev);
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
    $ret -= 0.3 if alignment($_[0]) ne alignment($best);
    $ret -= 0.3 if $_[0]->{fsize} != $best->{fsize};
    foreach my $feat ('bold', 'italic') {
        $ret -= 0.7 if $f{$feat}->($_[0]) != $f{$feat}->($best);
    }
    # far away:
    my $dist = abs($_[0]->{textpos} - $best->{textpos});
    $ret -= $dist/1000;
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
    $ret *= 0.3 if $_[0]->{fsize} != $best->{fsize};
    $ret *= 0.3 if abs($_[0]->{left} - $best->{left}) > 10;
    $ret *= 1 - abs($_[0]->{page}->{number} - $best->{page}->{number})/10;
    my $inbib = $f{'in bibliography section'};
    $ret *= 0.2 if $inbib->($best) && !$inbib->($_[0]);
    my $citlab = $f{'begins with citation label'};
    $ret *= 0.3 if $citlab->($best) && !$citlab->($_[0]);
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
        foreach my $chunk (@chunks) {
            my $p = $chunk->{p}->('HEADING');
            #print "** heading $p: $chunk->{text}\n";
            next unless $p > $min_heading + @{$_[0]->{_headings}}/20;
            push @{$_[0]->{_headings}}, $chunk;
            if ($chunk->{plaintext} =~ /$re_title/ && !$res) {
                $res = $p * 1/@{$_[0]->{_headings}};            
            }
            last if @{$_[0]->{_headings}} == 5;
        }
        #print "** result: $res\n";
        return $res;
    };
}

$f{'in bibliography section'} = in_section("^$re_bib_heading\$");

sub old_inbib {
    my $prev = $_[0];
    $_[0]->{_in_bib} = 0;
    my $other_heading = 0;
    while ($prev = $prev->{prev}) {
        print "previous is $prev->{text}\n";
        if ($prev->{p}->('HEADING') > 0.4) {
            print "previous is heading\n";
            if ($prev->{plaintext} =~ /^$re_bib_heading$/) {
                $_[0]->{_in_bib} = $other_heading ? 0.5 : 1; 
                last;
            }
            else {
                $other_heading = 1;
            }
        }
        if (exists $prev->{_in_bib}) {
            print "previous has in_bib\n";
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

$f{'not far into content'} = sub {
    my $ch = $_[0];
    my $n = 1;
    while ($ch = $ch->{prev}) {
        $n++ if $ch->{p}->('CONTENT') > 0.5;
        last if $n >= 100;
    }
    return 1 - $n/100;
};

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

$f{'begins with "abstract:"'} = begins_plain($re_abstract);

$f{'begins with dash'} = begins_plain($re_dash);

$f{'begins with possible name'} = memoize(sub {
    my @parts = split($re_name_separator, $_[0]->{plaintext}, 2);
    return 0 if ($parts[0] =~ /$re_noname/);
    return 1 if ($parts[0] =~ /(?:$re_name_before)?$re_name(?:$re_name_after)?/);
    return 0;
});

$f{'begins with dictionary word'} = memoize(sub {
    my $w = $_[0]->{plaintext};
    $w =~ s/^(\p{Letter}+)/$1/;
    return ($w && english($w)) ? 1 : 0;
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
        $c++ if english($w);
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
        my $anything_smaller = 0;
        while (($ch = $ch->{$dir}) && $ch->{page} == $_[0]->{page}) {
            next if (length($ch->{plaintext}) < 5);
            return 0 if $ch->{fsize} > $_[0]->{fsize};
            $anything_smaller = 1 if $ch->{fsize} < $_[0]->{fsize};
        }
        return $count_allequal ? $anything_smaller : 1;
    }
}

$f{'largest text on rest of page'} = memoize(largest_text('next'));

$f{'largest text on page'} = memoize(allof(largest_text('next', 1),
                                            largest_text('prev', 1)));

$f{'rest of page has same font size'} = sub {
    my $ch = $_[0];
    while (($ch = $ch->{next}) && $ch->{page} == $_[0]->{page}) {
        next if (length($ch->{plaintext}) < 5);
        return 0 if $ch->{fsize} != $_[0]->{fsize};
    }
    return 1;
};

$f{'previous line has larger font'} = sub {
    if ($_[0]->{prev} && $_[0]->{page} == $_[0]->{prev}->{page}
        && $_[0]->{prev}->{fsize} > $_[0]->{fsize}) {
        return 1;
    }
    return 0;
};

$f{'previous line short'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return max(min(2 - length($prev->{plaintext})/40, 1), 0);
});

$f{'previous line ends with terminator'} = memoize(sub {
    my $prev = $_[0]->{prev};
    return 0.5 unless $prev;
    return $prev->{plaintext} =~ /
       [\.!\?]\s*(?:<[^>]+>)?(?:$re_rquote)?\s*$
       /xo;
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

