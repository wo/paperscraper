package rules::Title_Features;
use warnings;
use List::Util qw/min max reduce/;
use Text::LevenshteinXS qw/distance/;
use Statistics::Lite qw/mean/;
use Text::Names qw/samePerson/;
use String::Approx 'amatch';
use rules::Helper;
use rules::Keywords;
use lib '../';
use util::String;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%block_features @parsing_features/;

our %block_features;

$block_features{TITLE} = [
    ['chunks probable TITLE', [0.4, -0.2]], # worst case is prob 0.5!
    ['adjacent chunks probable title', [-0.6, 0.2]],
    ['good title chunk missed', [-0.3, 0.3]],
    ['chunks are adjacent', [0, -1]],
    ['chunks are similar', [0.1, -0.3]],
    ['chunks are far apart', [-0.3, 0.1]],
    ['coincides with marginal', [0.4, 0]],
    ['implausible beginning', [-0.7, 0.1]],
    ['begins in lower case', [-0.3, 0.1]],
    ['implausible ending', [-0.7, 0.1]],
    ['not too short', [0, -0.4]],
    ];

$block_features{AUTHOR} = [
    ['chunks probable AUTHOR', [0.5, -0.3]],
    ['coincides with marginal', [0.4, 0]],
    ];

our @parsing_features = (
    ['has author', [0.1, -0.3]],
    ['has title', [0, -1]],
    ['author parts have high score', [0.7, -0.8]],
    ['title parts have high score', [0.7, -0.8]],
    ['good author block missed', [-0.6, 0.3]],
    ['author blocks are similar', [0.2, -0.4]],
    ['first author near title', [0.2, -0.5]],
    ['author and title on same page', [0, -0.5]],
    ['a lot of text between authors', [-0.6, 0]],
    ['author=title', [-0.1, 0]],
    ['author=title and further authors', [-0.4, 0]],
    ['author=title only has author part', [-0.6, 0]],
    # These are mainly here to adjust the confidence value:
    ['title is among first few lines', [0.2, -0.3]],
    ['title is largest text on page', [0.2, -0.2]],
    #['title occurs on source page', [0.4, -0.4]],
    #['authors contain source author', [0.2, -0.2]],
    );

my %f;

foreach my $label (qw/TITLE AUTHOR/) {
    $f{"chunks probable $label"} = sub {
        my $p;
        if (exists $_[0]->{chunks}) {
            $p = mean(map { $_->{p}->($label) } @{$_[0]->{chunks}});
        }
        else {
            $p = $_[0]->{p}->($label);
        }
        # zoom in on difference between 0.5 and 1:
        return max(0, ($p-0.5)*2);
    };
}

$f{'adjacent chunks probable title'} = sub {
    my $ch = $_[0]->{chunks}->[0]->{prev};
    my $p = $ch ? $ch->{p}->('TITLE') : 0;
    $ch = $_[0]->{chunks}->[-1]->{next};
    $p = max($p, $ch ? $ch->{p}->('TITLE') : 0);
    # emphasise differences between 0.5 and 1:
    return max(0, 0.35 + ($p-0.5)*1.3);
};

$f{'good title chunk missed'} = sub {
    my $ch0 = $_[0]->{chunks}->[0];
    my $ret = 0;
    foreach my $ch (@{$ch0->{best}->{TITLE}}) {
        next if grep { $_ eq $ch } @{$_[0]->{chunks}};
        $ret = max($ret, ($ch->{p}->('TITLE')-0.2)*1.25);
    }
    return $ret;
};

$f{'chunks are adjacent'} = sub {
    my $d = $_[0]->{chunks}->[-1]->{id} - $_[0]->{chunks}->[0]->{id};
    return $d == $#{$_[0]->{chunks}} ? 1 : 0;
};

$f{'chunks are similar'} = sub {
    my $ch0 = $_[0]->{chunks}->[0];
    my $res = 1;
    for my $ch (@{$_[0]->{chunks}}) {
        next if $ch eq $ch0;
        my $sim = 1;
        $sim = 0 if $ch->{page} != $ch0->{page};
        $sim -= 0.3 if (($ch->{plaintext} =~ /\p{IsLower}/)
                        != ($ch0->{plaintext} =~ /\p{IsLower}/));
        $sim -= abs($ch->{fsize} - $ch0->{fsize}) * 0.3;
        $sim -= 0.5 if (($ch->{text} =~ /^\s*<b>.*<\/b>\s*$/)
                        != ($ch0->{text} =~ /^\s*<b>.*<\/b>\s*$/));
        $res = min($res, $sim);
    }
    return max($res, 0);
};

$f{'chunks are far apart'} = sub {
    my $gap = 0;
    my $prev;
    for my $ch (@{$_[0]->{chunks}}) {
        if ($prev) {
            my $dist = $ch->{top} - $prev->{bottom};
            $gap = max($gap, $dist/$ch->{height});
        }
        $prev = $ch;
    }
    return min(1, max(0, $gap-0.5));
};

$f{'implausible ending'} = sub {
    my $txt = $_[0]->{chunks}->[-1]->{plaintext};
    return $txt =~ /$re_bad_ending$/i;
};

$f{'implausible beginning'} = sub {
    my $txt = $_[0]->{chunks}->[0]->{plaintext};
    return $txt =~ /^$re_bad_beginning/i;
};

$f{'begins in lower case'} = sub {
    my $txt = $_[0]->{chunks}->[0]->{plaintext};
    return $txt =~ /^\p{IsLower}/;
};

$f{'not too short'} = sub {
    my $txt = reduce { "$a $b->{plaintext}" } '', @{$_[0]->{chunks}};
    return min(1, max(0, (length($txt)-3) / 8));
};
    
$f{'coincides with marginal'} = sub {
    my $txt = reduce { "$a $b->{plaintext}" } '', @{$_[0]->{chunks}};
    for my $ch (@{$_[0]->{chunks}->[0]->{doc}->{marginals}}) {
        next if $ch->{plaintext} =~ /^[\divx]+$/;
        return 1 if distance($txt, $ch->{plaintext}) < 3;
    }
    return 0;
};

$f{'has author'} = sub {
    foreach (@{$_[0]->{blocks}}) {
        return 1 if $_->{label}->{AUTHOR};
    }
    return 0;
};

$f{'has title'} = sub {
    foreach (@{$_[0]->{blocks}}) {
        return 1 if $_->{label}->{TITLE};
    }
    return 0;
};

sub ok_parts {
    my $label = shift;
    return sub {
        my @parts = grep { $_->{label}->{$label} }
                    @{$_[0]->{blocks}};
        return undef unless @parts;
        my @probs = map { $_->{p}->($label) } @parts;
        my $p = mean(@probs);
        return min(1, $p+0.1) ** 2;
    };
}

$f{'author parts have high score'} = ok_parts('AUTHOR');

$f{'title parts have high score'} = ok_parts('TITLE');

sub chunk2block {
    my ($chunk, $blocks) = @_;
    foreach my $bl (@$blocks) {
	return $bl if grep { $chunk == $_ } @{$bl->{chunks}};  
    }
}

$f{'good author block missed'} = sub {
    my $ch0 = $_[0]->{blocks}->[0]->{chunks}->[0];
    my $ret = 0;
    foreach my $ch (@{$ch0->{best}->{AUTHOR}}) {
        my $bl = chunk2block($ch, $_[0]->{blocks});
        unless ($bl->{label}->{AUTHOR}) {
            my $r = max(0, ($ch->{p}->('AUTHOR')-0.2)*1.25);
            #print "good author ",$ch->{text}," missed: ",$ch->{p}->(AUTHOR);
            $r /= 2 if ($bl->{label}->{TITLE});
            $ret = max($ret, $r);
        }
    }
    return $ret;
};

$f{'author blocks are similar'} = sub {
    my @blocks = grep { $_->{label}->{'AUTHOR'} }
                      @{$_[0]->{blocks}};
    return undef unless scalar @blocks > 1;
    my $au1 = $blocks[0]->{chunks}->[0];
    my $res = 1;
    for my $i (1 .. $#blocks) {
        my $au2 = $blocks[$i]->{chunks}->[0];
        $res = 0 if $au1->{page} ne $au2->{page};
        $res = 0 if abs($au1->{fsize} - $au2->{fsize}) > 0.3;
        $res -= 0.8 if ($au1->{text} =~ /<b>/i) != ($au2->{text} =~ /<b>/i);
        $res -= 0.5 if ($au1->{plaintext} =~ /\p{IsLower}/)
                       != ($au2->{plaintext} =~ /\p{IsLower}/);
        $res -= 0.5 if ($au1->{text} =~ /,(?!\s*and)/i)
                       != ($au2->{text} =~ /,(?!\s*and)/);
    }
    return max(0, $res);
};

$f{'first author near title'} = sub {
    my $doc = $_[0]->{blocks}->[0]->{chunks}->[0]->{doc};
    return undef if ($doc->{url} =~ /stanford\.edu\/entries/);
    my ($author, $title);
    foreach (@{$_[0]->{blocks}}) {
        $author = $_ if $_->{label}->{AUTHOR} && !$author;
        $title = $_ if $_->{label}->{TITLE};
    }
    return undef unless $author && $title;
    $author = $author->{chunks}->[0];
    return 0 if $author->{page} != $title->{chunks}->[0]->{page};
    my $dist = $author->{top} < $title->{chunks}->[0]->{top} ?
        $title->{chunks}->[0]->{top} - $author->{bottom} :
        $author->{top} - $title->{chunks}->[-1]->{bottom};
    my $line_height = max($author->{height}, $title->{chunks}->[0]->{height});
    return ($dist > 0) ? min(1, $line_height*1.5 / $dist) : 1;
};

$f{'author and title on same page'} = sub {
    my $doc = $_[0]->{blocks}->[0]->{chunks}->[0]->{doc};
    return undef if ($doc->{url} =~ /stanford\.edu\/entries/);
    my ($author, $title);
    foreach (@{$_[0]->{blocks}}) {
        $author = $_ if $_->{label}->{AUTHOR} && !$author;
        $title = $_ if $_->{label}->{TITLE};
    }
    return undef unless $author && $title;
    $author = $author->{chunks}->[0];
    return $author->{page} == $title->{chunks}->[0]->{page};
};
    
$f{'a lot of text between authors'} = sub {
    my @blocks = grep { $_->{label}->{AUTHOR} } @{$_[0]->{blocks}};
    return undef unless scalar @blocks > 1;
    my $max_textlen = 0;
    for my $i (1 .. $#blocks) {
        my $ch = $blocks[$i-1]->{chunks}->[0];
        my $end = $blocks[$i]->{chunks}->[0];
        my $textlen = 0;
        #print "text between $ch->{text} and $end->{text}:\n";
        while (($ch = $ch->{next}) && ($ch ne $end)) {
            #print "    $ch->{text}\n";
            $textlen += length($ch->{plaintext});
        }
        $max_textlen = max($max_textlen, $textlen);
    }
    return ($max_textlen-200)/500;
};

$f{'author=title'} = sub {
   return 1 if grep {
        $_->{label}->{TITLE} && $_->{label}->{AUTHOR}
    } @{$_[0]->{blocks}};
    return 0;
};

$f{'author=title and further authors'} = sub {
    my @authors = grep { $_->{label}->{AUTHOR} } @{$_[0]->{blocks}};
    return 0 unless grep { $_->{label}->{TITLE} } @authors;
    return scalar @authors > 1 ? 1 : 0;
};

$f{'author=title only has author part'} = sub {
    my @blocks = grep {
           $_->{label}->{TITLE} && $_->{label}->{AUTHOR}
        } @{$_[0]->{blocks}};
    return 0 unless @blocks;
    my $text = $blocks[0]->{text};
    $text = tidy_text($text);
    foreach my $name (keys %{$blocks[0]->{chunks}->[0]->{names}}) {
        $text =~ s/$name//i;
        $text =~ s/$re_name_separator//;
    }
    return length($text) < 5 ? 1 : 0;
};

$f{'title is among first few lines'} = sub {
    my @blocks = grep {$_->{label}->{TITLE}} @{$_[0]->{blocks}};
    return 0 unless @blocks;
    return 3 / max($blocks[0]->{chunks}->[0]->{id}+1, 3);
};

$f{'title is largest text on page'} = sub {
    my @blocks = grep {$_->{label}->{TITLE}} @{$_[0]->{blocks}};
    return 0 unless @blocks;
    my @title_chunks = @{$blocks[0]->{chunks}};
    my $largest_size = 0;
    for my $ch (@{$blocks[0]->{chunks}->[0]->{page}->{chunks}}) {
        next if (grep { $ch eq $_ } @title_chunks);
        next if (length($ch->{plaintext}) < 5);
        $largest_size = max($largest_size, $ch->{fsize});
    }
    my $diff = $title_chunks[0]->{fsize} - $largest_size;
    # return 1 if nothing is as large, 0.5 if other chunks equally
    # large, 0 if other chunks significantly larger:
    return min(1, max(0, 0.5 + $diff/5));
};
    
$f{'title occurs on source page'} = sub {
    my @blocks = grep {$_->{label}->{TITLE}} @{$_[0]->{blocks}};
    return 0 unless @blocks;
    my $sourcecontent = $blocks[0]->{chunks}->[0]->{doc}->{sourcecontent};
    return undef unless $sourcecontent;
    my $str = tidy_text($blocks[0]->{text});
    return $sourcecontent =~ /\Q$str/i;
};

$f{'authors contain source author'} = sub {
    my @blocks = grep {$_->{label}->{AUTHOR}} @{$_[0]->{blocks}};
    return 0 unless @blocks;
    my @sourceauthors = @{$blocks[0]->{chunks}->[0]->{doc}->{sourceauthors}};
    return undef unless @sourceauthors;
    my @authors;
    for my $block (@blocks) {
        for my $ch (@{$block->{chunks}}) {
            while (my ($name, $prob) = each %{$ch->{names}}) {
                push @authors, tidy_text($name);
            }
        }
    }
    for my $src_au (@sourceauthors) {
        foreach my $au (@authors) {
            return 1 if Text::Names::samePerson($src_au, $au);
            return 1 if (amatch($src_au, ['i 30%'], $au));
        }
    }
    return 0;
};

compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;
