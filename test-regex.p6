use v6;


my $source-code = q:to/END/;
class ClassA {

  method A { }
  sub B { }
  sub foo {
    my $var = 1;
    say "Hello, World!";
  }
}
class ClassB {
  
  class ClassC {
    
  };

  method A1 { }
  sub B1 { }
  sub foo1 {  }
}
END

my $to = 0;
my $line-number = 0;
my @line-ranges;
for $source-code.lines -> $line { 
  my $length = $line.chars;
  my $from = $to;
  $to += $length;
  @line-ranges.push: {
    line-number => $line-number++,
    from        => $from,
    to          => $to
  };
}

sub to-line-number(Int $position) {
  for @line-ranges -> $line-range {
    if $position >= $line-range<from> && $position <= $line-range<to> {
      return $line-range<line-number>;
    }
  }
  return -1;
}

# Find all package declarations
my @package-declarations = $source-code ~~ m:global/
  # Package declaration
  ('class'| 'grammar'| 'module'| 'package'| 'role')
  \s+
  # Package identifier
  (\w+)
/;
for @package-declarations -> $decl {
  my %record = %(
    from        => $decl[0].from,
    to          => $decl[0].pos,
    line-number => to-line-number($decl[0].from) + 1,
    type        => ~$decl[0],
    name        => ~$decl[1],
  );
  say %record;
}

# my $var = 1;
my @variable-declarations = $source-code ~~ m:global/
  # Package declaration
  ('my'| 'state')
  \s+
  # Package identifier
  (\w+)
/;
for @variable-declarations -> $decl {
  my %record = %(
    from        => $decl[0].from,
    to          => $decl[0].pos,
    line-number => to-line-number($decl[0].from) + 1,
    type        => ~$decl[0],
    name        => ~$decl[1],
  );
  say %record;
}
