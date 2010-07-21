package SWL::MarkdownSupport;

use 5.004;  # i.e. not tested under earlier versions
use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;
@ISA = qw(Exporter);

use Config;
@EXPORT = qw(Markdown);






# Handles:
#   &,<,> replacement
#   _italic_, **bold**, `code`

# Table of hash values for escaped characters:
my %g_escape_table;
foreach my $char (split //, '\\`*_{}[]()>#+-.!') {
	$g_escape_table{$char} = "MD_ESCAPED_CHAR_".ord($char)."_";
}

sub _UnescapeSpecialChars {
#
# Swap back in all the special characters we've hidden.
#
	my $text = shift;

	while( my($char, $hash) = each(%g_escape_table) ) {
		$text =~ s/$hash/$char/g;
	}
    return $text;
}

sub _EncodeCode {
#
# Encode/escape certain characters inside Markdown code runs.
# The point is that in code, these characters are literals,
# and lose their special Markdown meanings.
#
    local $_ = shift;

	# Encode all ampersands; HTML entities are not
	# entities within a Markdown code span.
	s/&/&amp;/g;

	# Do the angle bracket song and dance:
	s! <  !&lt;!gx;
	s! >  !&gt;!gx;

	# Now, escape characters that are magic in Markdown:
	s! \* !$g_escape_table{'*'}!gx;
	s! _  !$g_escape_table{'_'}!gx;
	s! {  !$g_escape_table{'{'}!gx;
	s! }  !$g_escape_table{'}'}!gx;
	s! \[ !$g_escape_table{'['}!gx;
	s! \] !$g_escape_table{']'}!gx;
	s! \\ !$g_escape_table{'\\'}!gx;

	return $_;
}


sub _DoCodeSpans {
#
# 	*	Backtick quotes are used for <code></code> spans.
# 
# 	*	You can use multiple backticks as the delimiters if you want to
# 		include literal backticks in the code span. So, this input:
#     
#         Just type ``foo `bar` baz`` at the prompt.
#     
#     	Will translate to:
#     
#         <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
#     
#		There's no arbitrary limit to the number of backticks you
#		can use as delimters. If you need three consecutive backticks
#		in your code, use four for delimiters, etc.
#
#	*	You can use spaces to get literal backticks at the edges:
#     
#         ... type `` `bar` `` ...
#     
#     	Turns to:
#     
#         ... type <code>`bar`</code> ...
#

	my $text = shift;

	$text =~ s@
			(`+)		# $1 = Opening run of `
			(.+?)		# $2 = The code block
			(?<!`)
			\1			# Matching closer
			(?!`)
		@
 			my $c = "$2";
 			$c =~ s/^[ \t]*//g; # leading whitespace
 			$c =~ s/[ \t]*$//g; # trailing whitespace
 			$c = _EncodeCode($c);
			"<code>$c</code>";
		@egsx;

	return $text;
}


sub _DoItalicsAndBold {
	my $text = shift;

	# <strong> must go first:
	$text =~ s{ (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
		{<strong>$2</strong>}gsx;

	$text =~ s{ (\*|_) (?=\S) (.+?) (?<=\S) \1 }
		{<em>$2</em>}gsx;

	return $text;
}

sub _DoSuperscripts{
	my $text = shift;

	$text =~ s{ \^ (\d+) \s+ }
		{<sup>$1</sup>}gsx;

	return $text;
}

sub _EncodeAmpsAndAngles {
# Smart processing for ampersands and angle brackets that need to be encoded.

	my $text = shift;

	# Ampersand-encoding based entirely on Nat Irons's Amputator MT plugin:
	#   http://bumppo.net/projects/amputator/
 	$text =~ s/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/&amp;/g;

	# Encode naked <'s
 	$text =~ s{<(?![a-z/?\$!])}{&lt;}gi;

	return $text;
}


sub _EncodeBackslashEscapes {
#
#   Parameter:  String.
#   Returns:    The string, with after processing the following backslash
#               escape sequences.
#
    local $_ = shift;

    s! \\\\  !$g_escape_table{'\\'}!gx;		# Must process escaped backslashes first.
    s! \\`   !$g_escape_table{'`'}!gx;
    s! \\\*  !$g_escape_table{'*'}!gx;
    s! \\_   !$g_escape_table{'_'}!gx;
    s! \\\{  !$g_escape_table{'{'}!gx;
    s! \\\}  !$g_escape_table{'}'}!gx;
    s! \\\[  !$g_escape_table{'['}!gx;
    s! \\\]  !$g_escape_table{']'}!gx;
    s! \\\(  !$g_escape_table{'('}!gx;
    s! \\\)  !$g_escape_table{')'}!gx;
    s! \\>   !$g_escape_table{'>'}!gx;
    s! \\\#  !$g_escape_table{'#'}!gx;
    s! \\\+  !$g_escape_table{'+'}!gx;
    s! \\\-  !$g_escape_table{'-'}!gx;
    s! \\\.  !$g_escape_table{'.'}!gx;
    s{ \\!  }{$g_escape_table{'!'}}gx;

    return $_;
}

sub Markdown{
	my $text = shift;
	
	$text = _DoCodeSpans($text);
	#$text = _EncodeBackslashEscapes($text);
	#$text = _EscapeSpecialChars($text);
	#$text = _EncodeAmpsAndAngles($text);
	$text = _DoItalicsAndBold($text);
	$text = _DoSuperscripts($text);
	
	$text = _UnescapeSpecialChars($text);
	return $text;
}

1;
