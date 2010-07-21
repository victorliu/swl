package SWL::EquationSupport;

use 5.004;  # i.e. not tested under earlier versions
use strict;
use vars qw($VERSION @ISA @EXPORT $NEED_PATHMUNGE $DVIPNG_BIN $LATEX_BIN $EQUATION_BASELINE $DISPLAY_EQUATION_BEGIN $DISPLAY_EQUATION_END $INLINE_EQUATION_BEGIN $INLINE_EQUATION_END $EQUATION_DIR $EQUATION_COLOR $EQUATION_BACKGROUND);

$VERSION = '1.0';
$DVIPNG_BIN = 'dvipng';
$LATEX_BIN = 'latex';
$EQUATION_BASELINE = 'None';
$NEED_PATHMUNGE = 0;
$DISPLAY_EQUATION_BEGIN = '\[ ';
$DISPLAY_EQUATION_END = ' \]';
$INLINE_EQUATION_BEGIN = '\(';
$INLINE_EQUATION_END = '\)';
$EQUATION_DIR = 'eq';
$EQUATION_COLOR = '1.0 1.0 1.0';
$EQUATION_BACKGROUND = 'Transparent';

require Exporter;
@ISA = qw(Exporter);

use Config;
@EXPORT = qw(ReplaceEquation);

sub cygpathmunge{
	my $path = shift;
#	print "cygpathmunge in: $path\n";
	$path = `cygpath -m $path`;
	chomp $path;
#	print "cygpathmunge out: $path\n";
	return $path;
}

sub GenerateEquation{
	my $eqtex = shift;
	my $is_display = shift;
	my $image_filename = shift;
	my $tex_filename = "$image_filename.tex";
	
	my @LATEX_PACKAGES = ();
	my $TEX_LINES = '';
	
	my $preamble = "\\documentclass{article}\n";
	foreach(@LATEX_PACKAGES){
		$preamble .= "\\usepackage{$_}\n";
	}
	$preamble .= "\\pagestyle{empty}\n\\begin{document}\n";
	
	open(FP, ">$tex_filename");
	print FP $preamble;
	if($is_display){
		print FP "\\begin{displaymath} $eqtex \\end{displaymath}";
	}else{
		print FP "\$$eqtex\$";
	}
	print FP "\n\\newpage\n\\end{document}\n";
	close(FP);
	
	my $output_dir = $tex_filename;
	$output_dir =~ s/(\/[^\/]+)$//;
	if($output_dir eq '' || $1 eq ''){
		$output_dir = '.';
	}
	if($NEED_PATHMUNGE){
		$output_dir = &cygpathmunge($output_dir);
		$tex_filename  = &cygpathmunge($tex_filename);
		$image_filename  = &cygpathmunge($image_filename);
	}
	
	my $depth = 0;
	my $exts = '.tex .aux .dvi .log'; # extensions to clean up
	
	# Produce 
	my $latex_cmd = "$LATEX_BIN -file-line-error-style -interaction=nonstopmode -output-directory $output_dir $tex_filename";
#	print "Running: $latex_cmd\n";
	my @latex_lines = `$latex_cmd`;
#	print "Done\n";
	if($? != 0){
		print @latex_lines;
		$exts =~ s/\.tex//;
	}else{
		# perform conversion of DVI to PNG
		my $dvi_filename = $tex_filename; $dvi_filename =~ s/\.tex$/.dvi/;
		my @dvips_lines = `$DVIPNG_BIN --freetype0 -Q 9 -z 3 --depth -q -T tight -D 130 -fg \"rgb $EQUATION_COLOR\" -bg $EQUATION_BACKGROUND -o $image_filename $dvi_filename`;
		if($? != 0){
			print @dvips_lines;
		}else{
			$dvips_lines[-1] =~ m/=(.+)$/;
			$depth = int($1);
		}
	}
	# clean up temporary files
	foreach(split(/ /, $exts)){
		my $filename = $tex_filename;
		$filename =~ s/\.tex$/$_/;
		if(-e $filename){ unlink $filename; }
	}
	return $depth;
}

sub ReplaceEquation{
	my $eqstr = shift;
	my $image_filename = shift;
	my $is_display = shift;
	my $eqdir = $EQUATION_DIR;

	if($eqdir){
		if(! -d $eqdir){
			mkdir $eqdir;
		}
		
		if($eqdir !~ /\/^/){
			$eqdir = "$eqdir/";
		}
	}
	$image_filename = "$eqdir$image_filename";
	
	my $baseline = 0;
	
	# if baseline not yet determined, find it and cache
	if($EQUATION_BASELINE eq 'None'){
		# See if we can generate equations
		#my ($supported, $msg) = &TestEquationSupport();
		#if(0 == $supported){
		#	print "WARNING: equation support disabled\n";
		#	print $msg;
		#	$EQUATION_SUPPORT = 0;
		#	return '';
		#}

		# Compute the baseline
		my $eqt = '0123456789xxxXXxX';
		my $eqt_filename = 'baseline.png';
		$baseline = &GenerateEquation(
			$eqt,
			0, # 0 = inline equation, 1 = display
			$eqt_filename # output filename
			);
		if(-e $eqt_filename){
			unlink($eqt_filename);
		}
	}
	
	# make the equation
	my $depth = GenerateEquation(
		$eqstr,
		$is_display,
		$image_filename
		);
	# vertical-align should be negative of $offset
	my $offset = $depth - $baseline + 1;
	
	my $alt_text = $eqstr;
	$alt_text =~ s/\>/&gt;/g;
	$alt_text =~ s/\</&lt;/g;
	$alt_text =~ s/\&/&amp;/g;
	$alt_text =~ s/\"/&quot;/g;
	$alt_text =~ s/\n//g;
	$alt_text =~ s/\\//g;
	
	my $Tag = '';
	if($is_display){
		$Tag = "<img class=\"eqdisp\" src=\"$image_filename\" alt=\"$alt_text\">";
	}else{
		$offset .= 'px';
		$Tag = "<img class=\"eq\" src=\"$image_filename\" alt=\"$alt_text\" style=\"vertical-align: -$offset\">";
	}
	return $Tag;
}
