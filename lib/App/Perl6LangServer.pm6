
use v6;

unit class App::Perl6LangServer;

use File::Temp;
use JSON::Fast;

#TODO refactor bin/perl6-langserver into here.

my %text-documents;

method run {

  # No standard input/output buffering to prevent unwanted hangs/failures/waits
  $*OUT.out-buffer = False;
  $*ERR.out-buffer = False;

  debug-log("🙂: Starting perl6-langserver... Reading/writing stdin/stdout.");

  my $initialized = False;
  loop {
    my %headers;
    for $*IN.lines -> $line {
      # we're done here
      last if $line eq '';

      # Parse HTTP-style header
      my ($name, $value) = $line.split(': ');
      if $name eq 'Content-Length' {
          $value = +$value;
      }
      %headers{$name} = $value;
    }
    # debug-log("Headers found: {%headers.perl}");

    # Read JSON::RPC request
    my $content-length = 0 + %headers<Content-Length>;
    if $content-length > 0 {
        my $json    = $*IN.read($content-length).decode;
        my $request = from-json($json);
        my $id      = $request<id>;
        my $method  = $request<method>;
        # debug-log("\c[BELL]: {$request.perl}");

        #TODO throw an exception if a method is called before $initialized = True
        given $method {
          when 'initialize' {
            my $result = initialize($request<params>);
            send-json-response($id, $result);
          }
          when 'initialized' {
            # Initialization done
            # debug-log("🙂: Initialized handshake!");
            $initialized = True;
          }
          when 'textDocument/didOpen' {
            text-document-did-open($request<params>);
          }
          when 'textDocument/didSave' {
            text-document-did-save($request<params>);
          }
          when 'textDocument/didChange' {
            text-document-did-change($request<params>);
          }
          when 'textDocument/didClose' {
            text-document-did-close($request<params>);
          }
          when 'shutdown' {
            # Client requested to shutdown...
            # debug-log("\c[Bell]: shutdown called, cya 👋");
            send-json-response($id, Any);
          }
          when 'exit' {
            exit 0;
          }
        }
    }

  }
}

sub debug-log($text) {
  $*ERR.say($text);
}

sub send-json-response($id, $result) {
  my %response = %(
    jsonrpc => "2.0",
    id       => $id,
    result   => $result,
  );
  my $json-response = to-json(%response, :!pretty);
  my $content-length = $json-response.chars;
  my $response = "Content-Length: $content-length\r\n\r\n$json-response";
  print($response);
  # debug-log("\c[BELL]: {$response.perl}");
}

sub send-json-request($method, %params) {
  my %request = %(
    jsonrpc  => "2.0",
    'method' => $method,
    params   => %params,
  );
  my $json-request = to-json(%request, :!pretty);
  my $content-length = $json-request.chars;
  my $request = "Content-Length: $content-length\r\n\r\n$json-request";
  print($request);
  # debug-log("\c[BELL]: {$request}");
}

sub initialize(%params) {
  # debug-log("\c[Bell]: initialize({%params.perl})");
  %(
    capabilities => {
      # TextDocumentSyncKind.Full
      # Documents are synced by always sending the full content of the document.
      textDocumentSync => 1,
    }
  )
}

sub text-document-did-open(%params) {
  # debug-log("\c[Bell]: text-document-did-open");
  my %text-document = %params<textDocument>;
  %text-documents{%text-document<uri>} = %text-document;

  return;
}

sub publish-diagnostics($uri) {
  # debug-log("publish-diagnostics($uri)");

  # Create a temporary file for Perl 6 source code buffer
	my ($file-name,$file-handle) = tempfile(:!unlink);

  # Remove temporary file when leaving lexical scope
  LEAVE unlink $file-handle;

  # Write source code and flush
  my $source = %text-documents{$uri}<text>;
	$file-handle.print($source);
  $file-handle.flush;

  # Invoke perl -c temp-filder
  #TODO handle windows platform
  my Str $output = qqx{$*EXECUTABLE -c $file-name 2>&1};

  my @problems;
  if $output !~~ /^'Syntax OK'/ &&
    $output   ~~ m/\n(.+?)at\s.+?\:(\d+)/ {

    # A syntax error occurred
    my $message     = ~$/[0];
    my $line-number = +$/[1];
    @problems.push: {
      range => {
        start => {
          line      => $line-number,
          character => 0
        },
        end => {
          line      => $line-number,
          character => 0
        },
      },
      severity => 1,
      source   => 'perl6 -c',
      message  => $message
    }
  }

  my %parameters = %(
    uri         => $uri,
    diagnostics => @problems
  );
  send-json-request('textDocument/publishDiagnostics', %parameters);
}


sub text-document-did-save(%params) {
  # debug-log("\c[Bell]: text-document-did-save");

  my %text-document = %params<textDocument>;
#  publish-diagnostics(%text-document<uri>);

  return;
}

sub text-document-did-change(%params) {
  # debug-log("\c[Bell]: text-document-did-change");
  my %text-document          = %params<textDocument>;
  my $uri                    = %text-document<uri>;
  %text-documents{$uri}<text> = %params<contentChanges>[0]<text>;
  publish-diagnostics($uri);

  return;
}

sub text-document-did-close(%params) {
  # debug-log("\c[Bell]: text-document-did-close");
  my %text-document = %params<textDocument>;
  %text-documents{%text-document<uri>}:delete;

  return;
}
