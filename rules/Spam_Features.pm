package rules::Spam_Features;
use warnings;
use rules::Helper;
use rules::Keywords;
use lib '../';
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Document;
use Algorithm::NaiveBayes::Model::Frequency;
use List::Util qw/min max reduce/;
use FindBin qw($Bin);
use Cwd 'abs_path';
use File::Basename;
use util::Io;
use util::String;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = '@spam_features';

our @spam_features = (
    ['non-text filetype', [1, 0]],
    ['html', [0.1, -0.1]],
    ['bad anchortext', [0.3, -0.1]],
    ['bad path', [0.3, -0.1]],
    ['index file', [0.4, -0.1]],
    ['Bayesian classifier thinks text is spam', [0.8, -0.5]],
    ['no long text passages between links', [0.4, -0.1]],
    ['high tag density', [0.2, -0.1]],
    ['contains words typical for course notes', [0.5, -0.1]],
    ['contains words typical for papers', [-0.4, 0.1]],
    ['contains words typical for interviews', [0.2, 0]],
    ['few verbs', [0.5, -0.1]],
    ['short', [0.4, -0.1]],
    ['long', [-0.2, 0.2]],
    ['contains bibliography section', [-0.2, 0.2]],
    ['most lines short', [0.4, 0]],
    ['low confidence', [0.3, -0.1]],
    );

my %f;

my $path = dirname(abs_path(__FILE__));
my $SPAMCORPUS = "$path/../spamcorpus";
my $bayes = AI::Categorizer::Learner::NaiveBayes->restore_state(
                                      "$SPAMCORPUS/filterstate");
#$nb->verbose($verbosity > 1 ? 3 : 0);

$f{'Bayesian classifier thinks text is spam'} = sub {
    # This mainly serves to detect non-philosophy papers as well as
    # department homepages, stat counters etc.; it's not good at
    # detecting e.g. papers vs handouts or syllabi.
    my $loc = shift;
    return undef unless defined($loc->{text});
    my $ret;
    eval {
        my $ai_doc = AI::Categorizer::Document->new(content => $loc->{text});
        my $ai_res = $bayes->categorize($ai_doc);
        my $ai_ham = $ai_res->{scores}->{ham};
        my $ai_spam = $ai_res->{scores}->{spam};
        $ret = max(0, $ai_spam - $ai_ham/2);
    };
    if ($@) {
        print "spam categorization failed! $@\n";
        return undef;
    }
    return $ret;
};

my $re_bad_filetype = qr/\.(jpg|gif|ttf|ppt|php|asp)$/xi;
$f{'non-text filetype'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{url});
    return $loc->{url} =~ $re_bad_filetype;
};

$f{'html'} = sub {
    my $loc = shift;
    return (!$loc->{filetype} || $loc->{filetype} eq 'html') ? 1 : 0;
};

my $re_bad_anchortext = qr/^site\s*map$|^home|page\b|\bslides\b|handout/xi;
$f{'bad anchortext'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{anchortext});
    return $loc->{url} =~ $re_bad_anchortext;
};

my $re_index_path = qr|://[^/]+/[^\.\?]*(index\..{3,4})?$|xi;
$f{'index file'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{url});
    return $loc->{url} =~ m/$re_index_path/ && $loc->{url} !~ /plato.stanford/;
};

my $re_bad_path = qr/\bcours|lecture/xi;
$f{'bad path'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{url});
    return $loc->{url} =~ m/$re_bad_path/;
};

my $re_course_words = qr/course|seminar|schedule|readings|textbook|students|presentation|handout|essay|week|hours/i;
$f{'contains words typical for course notes'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    my $count = () = ($loc->{text} =~ /$re_course_words/g);
    return min(1, ($count*1000)/length($loc->{text}));
};

my $re_interview_words = qr/interview|do you/i;
$f{'contains words typical for interviews'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    my $count = () = ($loc->{text} =~ /$re_interview_words/g);
    return min(1, ($count*2000)/length($loc->{text}));
};

my $re_paper_words = qr/in section|finally,/i;
$f{'contains words typical for papers'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    my $count = () = ($loc->{text} =~ /$re_paper_words/g);
    return min(1, ($count*4000)/length($loc->{text}));
};

$f{'few verbs'} = sub {
    # e.g. bibliographies and other lists
    my $loc = shift;
    return undef unless defined($loc->{text});
    my $count = () = ($loc->{text} =~ /\bis\b/g);
    #print "xxx $count verbs in ".length($loc->{text})." Bytes\n";
    return max(0, 1 - ($count*2000)/length($loc->{text}));
};

$f{'high tag density'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text}) && $loc->{filetype} eq 'html';
    my $tag_ratio = 1 - length($loc->{text}) / length($loc->{content});
    return min(1, $tag_ratio + 0.5);
};

$f{'no long text passages between links'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text}) && $loc->{filetype} eq 'html';
    my $longest_text = 0; 
    foreach my $txt (split(/<a /i, $loc->{content})) {
        $longest_text = length($txt) if (length($txt) > $longest_text);
    }
    return max(0, 1 - $longest_text/2000);
};

$f{'short'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    return max(0, min(1, 1.5 - length($loc->{text}) / 5000));
};

$f{'long'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    return max(0, min(1, length($loc->{text}) / 20000 - 0.2));
};

$f{'contains bibliography section'} = sub {
    my $loc = shift;
    return undef unless defined($loc->{text});
    return $loc->{text} =~ /\n$re_bib_heading\n/ ? 1 : 0;
};

$f{'most lines short'} = sub {
    # indicates presentation slides
    my $loc = shift;
    return undef unless defined($loc->{text});
    @lines = split('\n', $loc->{text});
    my @lengths = sort { $a <=> $b } map(length, @lines);
    return undef unless @lengths;
    my $median = $lengths[int((0+@lengths)/2)];
    #print "median $median\n";
    return max(0, min(1, 1.5 - $median/70));
};

$f{'low confidence'} = sub {
    # suggests not the layout of an ordinary paper
    my $loc = shift;
    return undef unless defined($loc->{confidence});
    return min(1, 1.2 - ($loc->{confidence}-0.5)*2);
};


compile(\@spam_features, \%f);

1;
