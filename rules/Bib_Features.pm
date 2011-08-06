package rules::Bib_Features;
use strict;
use warnings;
use List::Util qw/min max reduce/;
use Statistics::Lite qw/mean/;
use Memoize;
use util::String;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK =
    qw/%fragment_features %block_features @parsing_features $known_work/;


our %fragment_features;

$fragment_features{CITLABEL} = [
    ['at beginning of entry', [0.2, -1]],
    ['contains digit', [0.2, -0.3]],
    ['in parentheses', [0.2, -0.3]],
    ];

$fragment_features{AUTHOR} = [
    ['contains letter', [0, -0.7]],
    ['contains uppercase letter', [0.1, -0.2]],
    ['lonely cap(s)', [0.25, 0]],
    ['contains editor string', [-0.6, 0]],
    ['contains digit', [-0.7, 0.1]],
    ['near beginning of entry', [0.7, -0.2]],
    ['early in entry', [0.2, -0.4]],
    ['in quotes', [-0.7, 0.05]],
    ['italic', [-0.4, 0.05]],
    ['publication status', [-0.7, 0]],
    ['after year string', [-0.4, 0.1]],
    ['after parenthesis', [-0.3, 0.05]],
    ['continues author', [0.6, -0.6], 2], 
    ['part of best author sequence', [0.3, -0.3], 2],
    ['only name words', [0.3, -0.2], 2],
    ['mostly dictionary words', [-0.2, 0.2], 2],
    ['after title', [-0.4, 0.2], 3],
    ];

$fragment_features{AUTHORDASH} = [
    ['is dash', [0.5, -1]],
    ['near beginning of entry', [0.8, -0.8]],
    ];

$fragment_features{TITLE} = [
    ['default', [0.2, 0]],
    ['contains letter', [0.1, -0.6]],
    ['in quotes', [0.6, -0.2]],
    ['italic', [0.3, -0.1]],
    ['in parentheses', [-0.3, 0]],
    ['early in entry', [0.2, -0.6]],
    ['after year string', [0.2, -0.1]],
    ['after "in"', [-0.4, 0]], 
    ['after italics', [-0.4, 0]], 
    ['after quote', [-0.4, 0.05]],
    ['contains editor string', [-0.5, 0]],
    ['publication status', [-0.7, 0]],
    ['probable AUTHOR', [-0.2, 0.05], 2], 
    ['part of best author sequence', [-0.3, 0.3], 2],
    ['contains journal or publisher word', [-0.2, 0], 2],
    ['long', [0.3, -0.05]],
    [$or->('continues title', 'follows year', 'follows author'),
     [0.6, -0.6], 2], 
    ['continues OTHER', [-0.1, 0.1], 2], 
    ['mostly dictionary words', [0.15, -0.15], 2],
    ];
 
$fragment_features{YEAR} = [
    [$or->('year', 'publication status'), [0.8, -0.8]],
    ['year', [0.9, -0.1]],
    ];

$fragment_features{OTHER} = [
    ['default', [0.1, 0]],
    [$or->('probable CITLABEL', 'probable AUTHOR',
           'probable TITLE', 'probable YEAR'), [-0.4, 0.5], 2],
    ['italic', [0.2, 0], 2], # journal name
    ['in parentheses', [0.3, 0], 2],
    ['after "in"', [0.2, 0], 2],
    ['followed by number', [0.2, 0], 2],
    ['ends in colon', [0.2, 0], 2], # Berlin: Springer
    ['near end of entry', [0.3, -0.05], 2],
    ['after italics', [0.15, 0], 2], 
    ['after quote', [0.15, 0], 2],
    ['contains editor string', [0.6, 0], 2],
    ['contains journal or publisher word', [0.4, 0], 2],
    ['followed by OTHER', [0.2, -0.1], 3],
    ];

our %block_features;

$block_features{TITLE} = [
    ['maybe TITLE', [1, -1]],
    ['begins with uppercase letter', [0.1, -0.3]],
    ['ends with punctuation', [0.25, -0.4]],
    ['surrounded by quotes or italics', [0.5, -0.15]],
    ['contains unclosed opening construct', [-0.3, 0.05]],
    ['contains dot and follows comma', [-0.15, 0]],
    ['followed by OTHER block', [0.05, -0.15]],
    ['contains journal or publisher word', [-0.2, 0]],
    ['journal/publisher word after punct.', [-0.15, 0]],
    ['contains late first comma', [-0.3, 0]],
    ];

$block_features{AUTHOR} = [
    ['maybe AUTHOR', [1, -1]],
    ['at least two words per author', [0.1, -0.4]],
    ['contains comma and ends in comma', [-0.3, 0]],
    # parse, and check against known authors...
    ];

$block_features{YEAR} = [
    ['maybe YEAR', [1, -1]],
    ];

$block_features{AUTHORDASH} = [
    ['maybe AUTHORDASH', [1, -1]],
    ];

$block_features{CITLABEL} = [
    ['maybe CITLABEL', [1, -1]],
    ];

$block_features{OTHER} = [
    ['maybe OTHER', [1, -1]],
    ];

our @parsing_features = (
    ['author part has high score', [0.7, -0.8]],
    ['title part has high score', [0.7, -0.8]],
    ['has title', [0.1, -1]],
    ['good title fragment OTHERed', [-0.4, 0.4]], 
    ['good author fragment OTHERed', [-0.4, 0.4]], 
    ['lengthy OTHER block before title', [-0.3, 0.05]], 
    ['is known work', [1, 0]],
    );


my %f;

$f{'at beginning of entry'} = sub {
    return $_[0]->{textpos} == 0 ? 1 : 0;
};

$f{'near beginning of entry'} = sub {
    return 1 - min($_[0]->{textpos}/30, 1);
};

$f{'early in entry'} = sub {
    my $pos = max($_[0]->{textpos} - 20, 0);
    return 1 - min($pos/150, 1);
};

$f{'near end of entry'} = memoize(sub {
    my $end = length($_[0]->{entry}->{text});
    my $pos = $_[0]->{textpos} + length($_[0]->{text});
    return 1 - min(($end-$pos)/30, 1);
});

my $re_year = '(?<!\d)[1-2]\d{3}(?!\d)';

$f{'after year string'} = memoize(sub {
    my $w = $_[0];
    while ($w = $w->{prev}) {
	return 1 if ($w->{text} =~ /$re_year|$re_year_words/i);
    }
    return 0;
});

$f{'follows year'} = sub {
    if ($_[0]->{prev} && 
        $_[0]->{text} =~ /$re_year|$re_year_words/i) {
        return 1;
    }
    return 0;
};

$f{'follows author'} = sub {
    my $w = $_[0]->{prev};
    return 0 unless $w && $w->{text} =~ /(.)[,:\.]$/;
    my $p = max(0, $w->{p}->('AUTHOR') - 0.3) * 1.4;
    if ($& eq ',' || $1 =~ /\p{Upper}/) { # initial
        $p /= 2;
    }
    return $p;
};

$f{'after italics'} = memoize(sub {
    my $w = $_[0];
    while ($w = $w->{prev}) {
	return 1 if ($w->{text} =~ /<\/i>/);
    }
    return 0;
});

$f{'long'} = sub {
    my $count = length($_[0]->{text});
    $count += 5 while ($_[0]->{text} =~ /\s/g);
    return max(0, min(1, ($count-20)/40));
};

$f{'continues title'} = sub {
    my $w = $_[0]->{prev};
    return 0.5 unless $w;
    if ($w->{text} =~ /(\S+)[^\pL\pN]$/) {
        my $punishment = ($& eq '.' && length($1) < 4) ? 2 :
            ($& eq ':') ? 0.2 : 0.5;
        $punishment /= 2 if $_[0]->{text} =~ /^\p{Lower}/;
        return $w->{p}->('TITLE') / (1+$punishment);
    }
    return $w->{p}->('TITLE');
};

$f{'continues OTHER'} = sub {
    my $w = $_[0]->{prev};
    return 0.5 unless $w;
    return $w->{p}->('TITLE');
};

$f{'continues author'} = sub {
    my $w = $_[0]->{prev};
    return 0.5 unless $w;
    if ($w->{text} =~ /(?:\b\pL\.,?|,)$/) {
	return $w->{p}->('AUTHOR');
    }
    return $w->{p}->('AUTHOR') / 4;
};

$f{'part of best author sequence'} = sub {
    my $w = $_[0]->{best}->{AUTHOR}->[0];
    return 0 unless $w;
    my $dir = $w->{id} < $_[0]->{id} ? 'next' : 'prev';
    while ($w != $_[0] && ($w = $w->{$dir})) {
        next if ($w->{text} =~ /(?:\b\pL\.,?|,)$/);
        next if ($w->{text} =~ /^$re_name_separator$/);
	return 0;
    }
    return 1;
};

$f{'followed by OTHER'} = sub {
    my $w = $_[0]->{next};
    return $w->{p}->('OTHER') if $w;
    return 0;
};

$f{'followed by title'} = sub {
    my $w = $_[0]->{next};
    if ($w && $_[0]->{text} =~ /\pL$/ && $w->{text} =~ /^\pL/) {
	return $w->{p}->('TITLE');
    }
    return 0;
};

$f{'followed by number'} = sub {
    my $w = $_[0]->{next};
    return 1 if ($w && $w->{text} =~ /^(?:<[^>]+>\s*)?\d/);
    return 0;
};

sub enclosed {
    my ($start, $end) = @_;
    return sub {
        my $w = $_[0];
	my $str = substr($w->{text}, 0, length($w->{text})/2);
	while (($w = $w->{prev})) {
            $str = $w->{text}.' '.$str;
        }
        return 0 unless $str =~ /.*$start(.*?)$/ && $1 !~ /$end/;
        $w = $_[0];
	$str = substr($w->{text}, length($w->{text})/2);
	while (($w = $w->{next})) {
            $str .= $w->{text};
        }
        return 0 unless $str =~ /^(.*?)$end/ && $1 !~ /$start/;
        return 1;
    };
}

$f{'in quotes'} = memoize(enclosed($re_lquote, $re_rquote));

$f{'italic'} = memoize(enclosed('<i>', '</i>'));

$f{'in parentheses'} = memoize(enclosed('[\(\[]', '[\)\]]'));

$f{'after quote'} = memoize(sub {
    my $w = $_[0];
    my $str = '';
    while (($w = $w->{prev})) {
        $str = $w->{text}.' '.$str;
    }
    if ($str =~ /$re_lquote(.*)$/ && $1 =~ /$re_rquote/) {
        return 1;
    }
    return 0;
});

$f{'after parenthesis'} = memoize(sub {
    my $w = $_[0];
    do {
        # don't count citation label parentheses:
	return 1 if ($w->{text} =~ /[\(\[]/ && $w->{prev});
    } while ($w = $w->{prev});
    return 0;
});

sub matches {
    my $re = shift;
    return sub {
	$_[0]->{text} =~ /$re/;
    };
}
    
$f{'year'} = matches('^\D?[1-2]\d{3}(?!\d)\D?');

$f{'publication status'} = matches($re_year_words);

$f{'contains letter'} = matches('\p{Letter}');

$f{'contains digit'} = matches('\d');

$f{'lonely cap(s)'} = matches('^\p{Upper}(?:\.\p{Upper})*\.?$');

$f{'contains uppercase letter'} = matches('\p{Upper}');

$f{'contains journal or publisher word'} =
    memoize(matches("$re_journal|$re_publisher"));

$f{'is dash'} = matches("^$re_dash+\$");

$f{'contains editor string'} = matches($re_editor);

$f{'ends in colon'} = matches(':$');

$f{'after "in"'} = memoize(sub {
    my $w = $_[0];
    while ($w) {
        my $prev = $w->{prev};
	return 1 if ($w->{text} =~ /^in/i && $prev && $prev->{text} !~ /\pL$/);
        $w = $prev;
    };
    return 0;
});

$f{'after title'} = sub {
    my @titles = @{$_[0]->{best}->{TITLE}};
    return 0.5 unless @titles;
    return 0 if $_[0]->{id} < $titles[0]->{id};
    return $titles[0]->{p}->('TITLE');
};

$f{'only name words'} = memoize(sub {
    my $str = $_[0]->{text};
    my ($names, $all) = (0, 0);
    while ($str =~ /\pL{2,}/g) {
        $names++ if (in_dict($&, 'surnames')
                     || in_dict($&, 'firstnames')
                     || $& =~ /^$re_name_separator$/);
        $all++;
    }
    return 0.5 unless $all;
    return max(0, $names/$all - 0.5) * 2;
});

$f{'mostly dictionary words'} = memoize(sub {
    my $str = $_[0]->{text};
    my ($dict, $all) = (0, 0);
    while ($str =~ /\pL{2,}/g) {
        $dict++ if is_word($&);
        $all++;
    }
    return 0.5 unless $all;
    return max(0, $dict/$all - 0.5) * 2;
});

$f{'default'} = sub {
    return 1;
};

sub p {
    my $label = shift;
    return sub {
	if (exists $_[0]->{chunks}) {
	    my @probs = map { $_->{p}->($label) } @{$_[0]->{chunks}};
            if (scalar @probs > 1) {
                return (min(@probs) + mean(@probs))/2;
            }
            # don't reward single-chunk blocks too much:
            return $probs[0] * 0.9;
	}
	return $_[0]->{p}->($label);
    };
}

foreach (qw/CITLABEL TITLE AUTHOR AUTHORDASH YEAR OTHER/) {
    $f{"maybe $_"} = p($_);
}

foreach my $lab (qw/CITLABEL TITLE AUTHOR AUTHORDASH YEAR OTHER/) {
    $f{"probable $lab"} = sub {
	return max(0, (p($lab)->($_[0]) - 0.2) * 1.25);
    };
}

# used for blocks:

$f{'ends with punctuation'} = sub {
    if ($_[0]->{text} =~ /([\.,;\?!])(?:<[^>]+>)?.?$/) {
        return $1 eq '.' ? 1 : 0.75;
    }
    return 0;
};

$f{'surrounded by quotes or italics'} = 
    memoize(matches("^(?:<i>.+</i>|$re_lquote.+$re_rquote).?\$"));

$f{'followed by OTHER block'} = sub {
    my $bl = $_[0]->{next};
    return $bl && $bl->{label}->{OTHER} ? 1 : 0;
};

$f{'journal/publisher word after punct.'} = 
    memoize(matches("[,\\.:].*(?:$re_journal|$re_publisher)"));

$f{'begins with uppercase letter'} = 
    matches('^(?:<[^>]+>|)?.?\p{Upper}');

$f{'at least two words per author'} = memoize(sub {
    foreach my $au (split /\b(?:and|&)\b/, $_[0]->{text}, -1) {
	return 0 unless $au =~ /\pL.*\s.*\pL/;
    }
    return 1;
});

$f{'contains late first comma'} = memoize(sub {
    my ($before, $after) = split(/,/, $_[0]->{text}, 2);
    return 0 unless $after;
    my $words = 0;
    $words++ while ($before =~ /\s+/g);
    return 1 if $words > 2;
    return 0.5 if $words == 2;
    return 0;
});

$f{'contains dot and follows comma'} = sub {
   if ($_[0]->{text} =~ /\pL\./ && $_[0]->{prev}
       && $_[0]->{prev}->{text} =~ /,\s*$/) {
        return 1;
    }
    return 0;
};

$f{'contains comma and ends in comma'} = sub {
    return 1 if ($_[0]->{text} =~ /,.+,\s*$/);
    return 0;
};

$f{'contains unclosed opening construct'} = sub {
    if ($_[0]->{text} =~ /.*$re_lquote(.*)/) {
        return 1 unless $1 =~ /$re_rquote/;
    }
    if ($_[0]->{text} =~ /.*\((.*)/) {
        return 1 unless $1 =~ /\)/;
    }
    if ($_[0]->{text} =~ /.*<.>(.*)/) {
        return 1 unless $1 =~ /<\/.*>/;
    }
    return 0;
};

# for parsings:

sub ok_part {
    my $label = shift;
    return sub {
	foreach my $bl (@{$_[0]->{blocks}}) {
	    next unless $bl->{label}->{$label};
	    my $p = $bl->{p}->($label);
	    # emphasise differences between 0.5 and 0.1:
	    return max(0, 0.35 + ($p-0.5)*1.3);
	}
	return 0.5;
    };
}

$f{'author part has high score'} = ok_part('AUTHOR');

$f{'title part has high score'} = ok_part('TITLE');

sub chunk2block {
    my ($chunk, $blocks) = @_;
    foreach my $bl (@$blocks) {
	return $bl if grep { $chunk == $_ } @{$bl->{chunks}};  
    }
}

sub othered {
    my $label = shift;
    return sub {
	my $ch0 = $_[0]->{blocks}->[0]->{chunks}->[0];
	foreach my $ch (@{$ch0->{best}->{$label}}) {
	    my $bl = chunk2block($ch, $_[0]->{blocks});
	    if ($bl->{label}->{OTHER}) {
		return max(0, ($ch->{p}->($label)-0.2)*1.25);
	    }
	}
	return 0.5; # don't reward having no OTHER parts
    }
}

$f{'good title fragment OTHERed'} = othered('TITLE');

$f{'good author fragment OTHERed'} = othered('AUTHOR');

$f{'has title'} = sub {
    my @parts = grep { $_->{label}->{TITLE} }
                @{$_[0]->{blocks}};
    return @parts ? 1 : 0;
};

$f{'lengthy OTHER block before title'} = sub {
    my $lengthy = 0;
    foreach my $bl (@{$_[0]->{blocks}}) {
	if ($bl->{label}->{TITLE}) {
	    return $lengthy;
	}
	if ($bl->{label}->{OTHER}) {
	    foreach (@{$bl->{chunks}}) {
		$lengthy += (1-$lengthy)/2;
	    }
	}
    }
};

our $known_work = \&known_work;
$f{'is known work'} = sub {
    my $bib = $_[0]->{bib};
    return 0 unless (@{$bib->{authors}} && $bib->{title});
    my $id = $known_work->(authors => $bib->{authors},
                           title => $bib->{title},
                           year => $bib->{year});
    $bib->{known_id} = $id if $id;
    return $id ? 1 : 0;
};


compile(\%fragment_features, \%f);
compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;
