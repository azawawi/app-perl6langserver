
use v6;
use MONKEY-SEE-NO-EVAL;

# Cache p6doc index.data (Hash of help topics strings)
my %help-index;

# 
# Return help search matched results against the given pattern
# in JSON format
#
sub help-search(Str $pattern is copy) {

	# Trim the pattern and make sure we dont fail on undefined
	$pattern = $pattern // '';
	$pattern = $pattern.trim;

	unless %help-index {
		my $index-file = qx{p6doc path-to-index}.chomp;
		unless $index-file.path ~~ :f
		{
			say "Building index.data... Please wait";

			# run p6doc-index build to build the index.data file
			my Str $dummy = qqx{p6doc build};
		}

		if $index-file.path ~~ :f
		{
			say "Loading index.data... Please wait";
			%help-index = EVAL $index-file.IO.slurp;
		}
		else
		{
			say "Cannot find $index-file";
		}
	}

	my @results;
	for %help-index.keys -> $topic {
		@results.push({
			"name"    => $topic,
			"matches" => %help-index{$topic}.unique(:as(&lc))
		}) if $topic ~~ m:i/"$pattern"/;
	}

	@results.sort(-> $a, $b { uc($a) leg uc($b) })
}

my @results = help-search("say");
my $contents = '';
for @results -> $result {
	for @($result<matches>) -> $match {
		my $name = $match[1].subst(/^ ( 'sub'| 'routine' | 'method' ) /, "").trim;
		my $keyword = $match[0] ~ $name;
		my $content = qqx{p6doc -n $keyword}.chomp;
		$contents ~= $content ~ "\n---\n";
	}
};
say $contents;
