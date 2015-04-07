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
    ['non-text filetype', [0.8, 0]],
    ['html', [0.1, -0.1]],
    ['no long text passages between links', [0.4, -0.1]],
    ['high tag density', [0.2, -0.1]],
    ['bad anchortext', [0.3, -0.1]],
    ['bad path', [0.3, -0.1]],
    ['Bayesian classifier thinks text is spam', [0.8, -0.3]],
    ['looks like course notes', [0.5, -0.1]],
    ['looks like interview', [0.2, 0]],
    ['few verbs', [0.5, -0.1]],
    ['short', [0.4, -0.1]],
    ['long', [-0.2, 0.1]],
    );

my %f;

my $path = dirname(abs_path(__FILE__));
my $SPAMCORPUS = "$path/../spamcorpus";
my $bayes = AI::Categorizer::Learner::NaiveBayes->restore_state(
                                      "$SPAMCORPUS/filterstate");
#$nb->verbose($verbosity > 1 ? 3 : 0);

$f{'Bayesian classifier thinks text is spam'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text});
    eval {
        my $ai_doc = AI::Categorizer::Document->new(content => $doc->{text});
        my $ai_res = $bayes->categorize($ai_doc);
        my $ai_ham = $ai_res->{scores}->{ham};
        my $ai_spam = $ai_res->{scores}->{spam};
        return max(0, $ai_spam - $ai_ham/2);
    };
    if ($@) {
        print "spam categorization failed! $@\n";
        return 0.5;
    }
};

my $re_bad_filetype = qr/\.(jpg|gif|ttf|ppt|php|asp)$/xi;
$f{'non-text filetype'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{url});
    return $doc->{url} =~ $re_bad_filetype;
};

$f{'html'} = sub {
    my $doc = shift;
    return (!$doc->{filetype} || $doc->{filetype} eq 'html') ? 1 : 0;
};

my $re_bad_anchortext = qr/^site\s*map$|^home|page\b/xi;
$f{'bad anchortext'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{anchortext});
    return $doc->{url} =~ $re_bad_anchortext;
};

my $re_bad_path = qr|://[^/]+/[^\.\?]*(index\..{3,4})?$|xi;
$f{'bad path'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{url});
    return $doc->{url} =~ m/$re_bad_path/ && $doc->{url} !~ /plato.stanford/;
};

my $re_course_words = qr/course|seminar|schedule|readings|textbook|students|presentation|handout|essay|week|hours/i;
$f{'looks like course notes'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text});
    my $count = () = ($doc->{text} =~ /$re_course_words/g);
    return min(1, ($count*1000)/length($doc->{text}));
};

my $re_interview_words = qr/interview|do you/i;
$f{'looks like interview'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text});
    my $count = () = ($doc->{text} =~ /$re_interview_words/g);
    return min(1, ($count*2000)/length($doc->{text}));
};

$f{'few verbs'} = sub {
    # e.g. bibliographies and other lists
    my $doc = shift;
    return undef unless defined($doc->{text});
    my $count = () = ($doc->{text} =~ /\bis\b/g);
    #print "xxx $count verbs in ".length($doc->{text})." Bytes\n";
    return max(0, 1 - ($count*2000)/length($doc->{text}));
};

$f{'high tag density'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text}) && $doc->{filetype} eq 'html';
    my $tag_ratio = 1 - length($doc->{text}) / length($doc->{content});
    return min(1, $tag_ratio + 0.5);
};

$f{'no long text passages between links'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text}) && $doc->{filetype} eq 'html';
    my $longest_text = 0; 
    foreach my $txt (split(/<a /i, $doc->{content})) {
        $longest_text = length($txt) if (length($txt) > $longest_text);
    }
    return max(0, 1 - longest_text/2000);
};

$f{'short'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text});
    return max(0, min(1, 1.5 - length($doc->{text}) / 5000));
};

$f{'long'} = sub {
    my $doc = shift;
    return undef unless defined($doc->{text});
    return max(0, min(1, length($doc->{text}) / 20000 - 0.2));
};

compile(\@spam_features, \%f);

1;
