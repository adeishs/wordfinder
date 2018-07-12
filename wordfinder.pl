#!/usr/bin/perl

use strict;
use utf8;
use feature ':5.10';
use Readonly;
use List::MoreUtils qw(uniq);
use LCS::Tiny;
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json);
use Data::Dumper;

Readonly::Scalar my $LCS => LCS::Tiny->new;

# "normalise" a word by trimming it and converting to lowercase
sub norm_word {
    my ($word) = @_;

    $word =~ s/^\s+|\s+$//g;
    return lc $word;
}

sub read_dict {
    my ($dict_file) = @_;

    open my $fh, '<', $dict_file
        or die "Can't open $dict_file";

    my @dict_words;
    while (<$fh>) {
        chomp;
        push @dict_words, norm_word($_);
    }
    @dict_words = uniq sort @dict_words;
    return \@dict_words;
}

sub sort_chars {
    my ($word) = @_;

    my @chars = sort split //, $word;
    return \@chars;
}

sub find_words {
    my ($dict_words, $query) = @_;

    $query = norm_word($query);

    my $query_chars = sort_chars($query);
    my $query_len = length $query;
    my @targets = ();

    for my $dict_word (@{$dict_words}) {
        my $dict_word_chars = sort_chars($dict_word);
        my $dict_word_len = length $dict_word;

        # a dictionary word is considered a target of the
        # query if the query (characters sorted) is a
        # subsequence of the dictionary word (characters
        # sorted). This can be attacked using the longest
        # common subsequence (LCS)problem, e.g. used in
        # <shameless plug> ishs's PhD thesis:
        # http://researchbank.rmit.edu.au/eserv/rmit:6823/Suyoto.pdf
        #
        # If the LCS score = query length, we have a match
        my $lcs_matches = $LCS->LCS($dict_word_chars,
                                    $query_chars);

        if ($lcs_matches
            && scalar @{$lcs_matches} == $dict_word_len) {
            push @targets, $dict_word;
        }
    }

    return \@targets;
}

plugin Config => {file => 'wordfinder.conf'};
my $dict_file = app->config->{dict};
my $dict_words = read_dict($dict_file);

get '/ping' => sub {
    my $c = shift;

    return $c->render(text => "OK\n");
};

get '/wordfinder/:input' => sub {
    my $c = shift;
    my $input = $c->param('input');

    my $words = find_words($dict_words, $input);
    return $c->render(text => encode_json($words) . "\n");
};

app->start;
