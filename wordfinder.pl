#!/usr/bin/perl

use strict;
use utf8;
use feature ':5.10';
use List::MoreUtils qw(uniq);
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json);

# "normalise" a word by trimming it and converting to lowercase
sub norm_word {
    my ($word) = @_;

    $word =~ s/^\s+|\s+$//g;
    return lc $word;
}

# get an array of sorted characters
sub sort_chars {
    my ($word) = @_;

    my @chars = sort split //, $word;
    return \@chars;
}

# read dictionary and set up structure for fast search
sub read_dict {
    my ($dict_file) = @_;

    open my $fh, '<', $dict_file
        or die "Can't open $dict_file";

    # this will be:
    # key: word length
    # value: arrayref of hashref of word and sorted chars
    my %dict_word;
    while (<$fh>) {
        chomp;
        my $word = $_;
        my $norm_word = norm_word($word);
        my %w = (word => $word,
                 chars => sort_chars($norm_word),
                );
        push @{$dict_word{length $norm_word}}, \%w;
    }

    close $fh;

    return \%dict_word;
}

sub get_max {
    my ($a, $b) = @_;

    return $a > $b ? $a : $b;
}

# get LCS
sub get_lcs_len {
    my ($m, $n) = @_;

    my $m_len = scalar @{$m};
    my $n_len = scalar @{$n};
    my @scores = ();
    my $i_m;
    my $i_n;

    # the original LCS requires construction of a 2D matrix of
    # size |m| + 1 by |n| + 1. For space efficiency, we can use
    # only 2 by |n| + 1 as only two rows are accessed in every
    # iteration

    # init
    for $i_n (0 .. $n_len) {
        $scores[0]->[$i_n] = 0;
    }
    $scores[1]->[0] = 0;

    my $curr_row = 1;
    my $prev_row = 0;

    # calculate alignment scores
    for $i_m (1 .. $m_len) {
        for $i_n (1 .. $n_len) {
            $scores[$curr_row]->[$i_n]
            = $m->[$i_m - 1] eq $n->[$i_n - 1]
              ? $scores[$prev_row]->[$i_n - 1] + 1
              : get_max($scores[$prev_row]->[$i_n],
                        $scores[$curr_row]->[$i_n - 1]);
        }

        $curr_row = 1 - $curr_row;
        $prev_row = 1 - $prev_row;
    }

    return $scores[$prev_row]->[$n_len];
}

# get dictionary words containing query letters
sub find_words {
    my ($dict_word, $query) = @_;

    $query = norm_word($query);

    my $query_chars = sort_chars($query);
    my $query_len = length $query;
    my @targets = ();

    # we can ignore dictionary words longer than the query as
    # they definitely cannot be made up of the query chars
    for my $len (1 .. $query_len) {
        for my $dict_word (@{$dict_word->{$len}}) {

            # a dictionary word is considered a target of the
            # query if the query (characters sorted) is a
            # subsequence of the dictionary word (characters
            # sorted). This can be attacked using the longest
            # common subsequence (LCS) problem, e.g. used in
            # <shameless plug> ishs's PhD thesis:
            # http://researchbank.rmit.edu.au/eserv/rmit:6823/Suyoto.pdf
            my $lcs_len = get_lcs_len($dict_word->{chars},
                                      $query_chars);

            # We hit a target if the LCS score is equal to the
            # dict word length
            if ($lcs_len == scalar @{$dict_word->{chars}}) {
                push @targets, $dict_word->{word};
            }
        }
    }

    return [sort @targets];
}

plugin Config => {file => 'wordfinder.conf'};
my $dict_file = app->config->{dict};
my $dict_word = read_dict($dict_file);

get '/ping' => sub {
    my $c = shift;

    return $c->render(text => "OK\n", format => 'txt');
};

get '/wordfinder/:input' => sub {
    my $c = shift;
    my $input = $c->param('input');

    my $words = find_words($dict_word, $input);
    return $c->render(text => encode_json($words) . "\n",
                      format => 'json');
};

app->start;
