#!/usr/bin/env perl

use strict;
use utf8;
use 5.10.0;
use Mojolicious::Lite;
use Mojo::JSON qw(encode_json);
use Function::Parameters { fun => {}, route => { shift => '$app' } };
use LCS::BV;

# "normalise" a word by trimming it and converting to lowercase
fun norm_word($word) {
    $word =~ s/^\s+|\s+$//g;
    return lc $word;
}

# get an array of sorted characters
fun sort_chars($word) {
    return [sort split //, $word];
}

# read dictionary and set up structure for fast search
fun read_dict($dict_file = undef) {
    state $dict_word;

    if ($dict_word) { return $dict_word }
    unless ($dict_file) { die "Must specify dictionary file" }

    open my $fh, '<', $dict_file
        or die "Can’t open $dict_file";

    # this will be:
    # key: word length
    # value: arrayref of hashref of word and sorted chars
    while (<$fh>) {
        chomp;
        my $word = $_;
        my $norm_word = norm_word($word);
        my %w = (word => $word,
                 chars => sort_chars($norm_word),
                );
        push @{$dict_word->{length $norm_word}}, \%w;
    }

    close $fh;

    return $dict_word;
}

fun get_max($a, $b) {
    return $a > $b ? $a : $b;
}

# get LCS
fun get_lcs_len($m, $n) {
    state $lcs = LCS::BV->new;
    return $lcs->LLCS($m, $n);
}

# get dictionary words containing query letters
fun find_words($dict_word, $query, $min_len = 1, $max_len = undef) {
    my $query_len = length $query;

    $min_len //= 1;
    $max_len //= $query_len;
    if ($max_len > $query_len) {
        $max_len = $query_len;
    }

    if ($min_len > $max_len) {
        return (undef, 400,
                'Maximum length must not be less than minimum length'
               );
    }

    my $query_chars = sort_chars(norm_word($query));
    my @targets = ();

    # we can ignore dictionary words longer than the query as
    # they definitely cannot be made up of the query chars
    for my $len ($min_len .. $max_len) {
        for my $dict_word (@{$dict_word->{$len}}) {

            # a dictionary word is considered a target of the
            # query if the query (characters sorted) is a
            # subsequence of the dictionary word (characters
            # sorted). This can be attacked using the longest
            # common subsequence (LCS) problem, e.g. used in
            # <shameless plug> ishs’s PhD thesis:
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

route ping() {
    return $app->render(text => "OK\n", format => 'txt');
}

route wordfinder() {
    my ($words, $status, $msg) =
        find_words(read_dict(),
                   map { $app->param($_) } qw(input min_len max_len));

    unless ($words) {
        return $app->render(text => "$msg\n",
                            format => 'txt', status => $status);
    }

    return $app->render(text => encode_json($words) . "\n",
                        format => 'json');
}

plugin Config => {file => 'wordfinder.conf'};

get '/ping' => \&ping;
get '/wordfinder/:input' => \&wordfinder;
get '/wordfinder/:input/:min_len/:max_len' => \&wordfinder;

read_dict(app->config->{dict});
app->start;
