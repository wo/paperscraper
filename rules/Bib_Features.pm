package rules::Bib_Features;
use strict;
use warnings;
use List::Util qw/min max reduce/;
use Statistics::Lite qw/mean/;
use Memoize;
use rules::Helper;
use rules::Keywords;
use rules::KnownWork 'known_work';
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%word_features %block_features @parsing_features/;


our %word_features;

$word_features{CITLABEL} = [
    ['at beginning of entry', [0.2, -1]],
    ['contains digit', [0.2, -0.3]],
    ['in parentheses', [0.2, -0.3]],
    ];

$word_features{AUTHOR} = [
    ['contains letter', [0, -0.7]],
    ['contains uppercase letter', [0.1, -0.2]],
    ['lonely cap(s)', [0.25, 0]],
    ['editor string', [-0.6, 0]],
    ['contains digit', [-0.7, 0.1]],
    ['near beginning of entry', [0.7, -0.2]],
    ['early in entry', [0.2, -0.4]],
    ['in quotes', [-0.7, 0.05]],
    ['italic', [-0.4, 0.05]],
    ['after year string', [-0.4, 0.1]],
    ['after parenthesis', [-0.3, 0.05]],
    ['continues author', [0.6, -0.6], 2], 
    [$or->('is surname', 'is firstname', 'author separator'), [0.3, -0.2], 2],
    ['is English word', [-0.2, 0.2], 2],
    ['after title', [-0.4, 0.2], 3],
    ];

$word_features{AUTHORDASH} = [
    ['is dash', [0.5, -1]],
    ['near beginning of entry', [0.8, -0.8]],
    ];

$word_features{TITLE} = [
    [$or->('contains letter', 'is dash'), [0.4, -0.3]],
    ['in quotes', [0.6, -0.2]],
    ['italic', [0.4, -0.1]],
    ['in parentheses', [-0.3, 0]],
    ['early in entry', [0.2, -0.6]],
    ['after year string', [0.2, -0.1]],
    ['after "in"', [-0.3, 0]], 
    ['after italics', [-0.4, 0]], 
    ['after quote', [-0.4, 0.05]],
    ['probable AUTHOR', [-0.2, 0.05], 2], 
    ['contains journal or publisher word', [-0.2, 0], 2],
    ['part of lengthy unpunctuated string between punctuations', [0.3, -0.05]],
    [$or->('continues title', 'follows year', 'follows author'),
     [0.5, -0.5], 2], 
    ['continues OTHER', [-0.1, 0.1], 2], 
    ['followed by title', [0.4, 0], 2], 
    ['is English word', [0.15, -0.15], 2],
    ];
 
$word_features{YEAR} = [
    ['year', [0.9, -0.8]],
    ['publication status', [0.9, -0.1]],
    ];

$word_features{OTHER} = [
    ['default', [0.1, 0]],
    [$or->('probable CITLABEL', 'probable AUTHOR',
           'probable TITLE', 'probable YEAR'), [-0.4, 0.5], 2],
    ['italic', [0.2, 0], 2], # journal name
    ['in parentheses', [0.3, 0], 2],
    ['after "in"', [0.2, 0], 2],
    ['part of string followed by number', [0.2, 0], 2],
    ['ends in colon', [0.2, 0], 2], # Berlin: Springer
    ['near end of entry', [0.3, -0.05], 2],
    ['after italics', [0.15, 0], 2], 
    ['after quote', [0.15, 0], 2],
    ['editor string', [0.6, 0], 2],
    ['contains journal or publisher word', [0.4, 0], 2],
    ['followed by OTHER', [0.2, -0.1], 3],
    ];

our %block_features;

$block_features{TITLE} = [
    ['maybe TITLE', [1, -1]],
    ['begins with uppercase letter', [0.1, -0.3]],
    ['ends with punctuation', [0.2, -0.4]],
    ['surrounded by quotes or italics', [0.5, -0.2]],
    ['contains unclosed opening construct', [-0.3, 0.05]],
    ['followed by OTHER block', [0.05, -0.2]],
    ['contains journal or publisher word', [-0.25, 0]],
    ['journal/publisher word after punct.', [-0.2, 0]],
    ['contains late first comma', [-0.3, 0]],
    ];

$block_features{AUTHOR} = [
    ['maybe AUTHOR', [1, -1]],
    ['at least two words per author', [0.2, -0.4]],
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
    ['good title word OTHERed', [-0.5, 0.5]], 
    ['good author word OTHERed', [-0.5, 0.5]], 
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
	return 1 if ($w->{text} =~ /$re_year|$re_year_words/);
    }
    return 0;
});

$f{'follows year'} = memoize(sub {
    return 1 if ($_[0]->{text} =~ /$re_year|$re_year_words/);
    return 0;
});

$f{'follows author'} = sub {
    my $w = $_[0]->{prev};
    return 0 unless $w && $w->{text} =~ /[,:\.]$/;
    my $p = max(0, $w->{p}->('AUTHOR') - 0.3) * 1.4;
    return $p / (($& eq ',') ? 2 : 1); 
};

$f{'after italics'} = memoize(sub {
    my $w = $_[0];
    while ($w = $w->{prev}) {
	return 1 if ($w->{text} =~ /<\/i>/);
    }
    return 0;
});

$f{'part of lengthy unpunctuated string between punctuations'} = sub {
    my $count = 1;
    my $stop = qr/[,\.!\?\)\]]$/;
    my $w = $_[0];
    if ($w->{text} !~ /$stop/) {
        while ($w = $w->{next}) {
            return 0 unless $w;
            $count++;
            last if $w->{text} =~ /$stop/;
        }
    }
    $w = $_[0];
    while ($w = $w->{prev}) {
        return 0 unless $w;
        last if $w->{text} =~ /$stop/;
        $count++;
    }
    return max(0, min(1, ($count-2)/4));
};

$f{'continues title'} = sub {
    my $w = $_[0]->{prev};
    return 0.5 unless $w;
    if ($w->{text} =~ /[^\pL]$/) {
        return $w->{p}->('TITLE') / (($& eq '.') ? 3 : 2); 
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
    # previous word ends in letter or comma or 'X.':
    if ($w->{text} =~ /(?:\pL|\b\pL\.),?$/) {
	return $w->{p}->('AUTHOR');
    }
    return $w->{p}->('AUTHOR') / 4;
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

$f{'part of string followed by number'} = sub {
    my $w = $_[0]->{next};
    my $stop = qr/[,\.!\?\)\]]$/;
    while ($w) {
        return 1 if ($w->{text} =~ /^(?:<[^>]+>\s*)?\d/);
        last if ($w->{prev}->{text} =~ /$stop/);
        $w = $w->{next};
    }
    return 0;
};

sub enclosed {
    my ($start, $end) = @_;
    return sub {
	my $w = $_[0];
	my $closed = 0;
	while ($w && $w->{text} !~ /$start/) {
	    $closed++ if $w->{text} =~ /$end/;
	    $w = $w->{prev};
	}
	return 0 unless $w;
	$w = $_[0];
	my $opened = 0;
	while ($w && $w->{text} !~ /$end/) {
	    $opened++ if $w->{text} =~ /$start/;
	    $w = $w->{next};
	}
	if ($closed || $opened) {
	    # this most often happens when an apostrophe is mistaken
	    # for a closing quote; thus:
	    return 0.5;
	}
	return $w ? 1 : 0;
    };
}

$f{'in quotes'} = memoize(enclosed($re_lquote, $re_rquote));

$f{'italic'} = memoize(enclosed('<i>', '</i>'));

$f{'in parentheses'} = memoize(enclosed('[\(\[]', '[\)\]]'));

$f{'after quote'} = memoize(sub {
    my $w = $_[0];
    my $in;
    while ($w = $w->{prev}) {
	return 1 if ($in && $w->{text} =~ /$re_lquote/);
	$in = 1 if ($w->{text} =~ /$re_rquote/);
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

$f{'author separator'} = matches("^$re_name_separator\$");

$f{'editor string'} = matches($re_editor);

$f{'ends in colon'} = matches(':$');

$f{'after "in"'} = memoize(sub {
    my $w = $_[0];
    while ($w) {
        my $prev = $w->{prev};
	return 1 if ($w->{text} =~ /^in$/i && $prev && $prev->{text} !~ /\pL$/);
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

$f{'is surname'} = memoize(sub {
    my $str = $_[0]->{text};
    $str =~ s/^\P{Letter}*(.+?)\P{Letter}*$/$1/;
    return 0 unless length($str) > 1;
    return in_dict($str, 'surnames');
});

$f{'is firstname'} = memoize(sub {
    my $str = $_[0]->{text};
    $str =~ s/^\P{Letter}*(.+?)\P{Letter}*$/$1/;
    return 0 unless $str;
    return in_dict($str, 'firstnames');
});

$f{'is English word'} = memoize(sub {
    my $str = $_[0]->{text};
    $str =~ s/^\P{Letter}*(.+?)\P{Letter}*$/$1/;
    return 0 unless $str;
    return english($str);
});

$f{'default'} = sub {
    return 1;
};

sub p {
    my $label = shift;
    return sub {
	if (exists $_[0]->{chunks}) {
	    my @probs = map { $_->{p}->($label) } @{$_[0]->{chunks}};
	    return (min(@probs) + mean(@probs))/2;
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

$f{'ends with punctuation'} = memoize(matches('[\.,;\?!](?:<[^>]+>)?.?$'));

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

$f{'good title word OTHERed'} = othered('TITLE');

$f{'good author word OTHERed'} = othered('AUTHOR');

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

$f{'is known work'} = sub {
    my (@authors, $title, $year);
    foreach my $bl (@{$_[0]->{blocks}}) {
        if ($bl->{label}->{TITLE}) {
            $title = $bl->{text};
        }
        elsif ($bl->{label}->{AUTHOR}) {
            push @authors, $bl->{text};
        }
    }
    return 0 unless (@authors && $title);
    # TODO: tidy up authors and title?
    return known_work(authors => \@authors, title => $title);
};

compile(\%word_features, \%f);
compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;
