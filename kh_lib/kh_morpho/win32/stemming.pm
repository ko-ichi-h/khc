package kh_morpho::win32::stemming;
use strict;
use base qw( kh_morpho::win32 );

use Lingua::Sentence;
use Lingua::Stem::Snowball;

use Text::Unaccent::PurePerl qw(unac_string);

use kh_morpho::win32::stemming::de;
use kh_morpho::win32::stemming::en;
use kh_morpho::win32::stemming::es;
use kh_morpho::win32::stemming::fr;
use kh_morpho::win32::stemming::it;
use kh_morpho::win32::stemming::nl;
use kh_morpho::win32::stemming::pt;

use utf8;
use Encode;

my $sjis = find_encoding('shiftjis');

#-----------------------#
#   Stemmerの実行関係   #
#-----------------------#

sub _run_morpho{
	my $self = shift;	

	my $class = "kh_morpho::win32::stemming::".$::config_obj->stemming_lang;
	bless $self, $class;

	if (-e $self->output){
		unlink $self->output or 
			gui_errormsg->open(
				thefile => $self->output,
				type => 'file'
			);
	}

	open (TRGT,$self->target) or 
		gui_errormsg->open(
			thefile => $self->target,
			type => 'file'
		);
	
	open (my $fh_out,'>',$self->output) or 
		gui_errormsg->open(
			thefile => $self->output,
			type => 'file'
		);

	# Perlapp用にLingua::Sentenceのデータを解凍
	if(defined(&PerlApp::extract_bound_file)){
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.ca',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.de',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.el',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.en',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.es',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.fr',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.it',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.nl',
		);
		PerlApp::extract_bound_file(
			'auto/share/dist/Lingua-Sentence/nonbreaking_prefix.pt',
		);
	}

	$self->init;

	# 処理開始
	while ( <TRGT> ){
		chomp;
		my $t   = decode("latin1",$_);
		#$t =~ tr/(?:\x81\x40)/ /; # SJISの全角スペースを半角に変換（Win32）
		
		# 見出し行
		if ($t =~ /^(<h[1-5]>)(.+)(<\/h[1-5]>)$/io){
			print $fh_out $sjis->encode("$1\t$1\t$1\tタグ\n");
			$self->_tokenize_stem($2, $fh_out);
			print $fh_out $sjis->encode("$3\t$3\t$3\tタグ\n");
		} else {
			while ( index($t,'<') > -1){
				my $pre = substr($t,0,index($t,'<'));
				my $cnt = substr(
					$t,
					index($t,'<'),
					index($t,'>') - index($t,'<') + 1
				);
				unless ( index($t,'>') > -1 ){
					gui_errormsg->open(
						msg => '山カッコ（<>）による正しくないマーキングがありました。',
						type => 'msg'
					);
					exit;
				}
				substr($t,0,index($t,'>') + 1) = '';
				
				$self->_sentence($pre, $fh_out);
				$self->_tag($cnt, $fh_out);
				
				#print "[[$pre << $cnt >> $t]]\n";
			}
			$self->_sentence($t, $fh_out);
		}
		print $fh_out $sjis->encode("EOS\n");
	}
	close (TRGT);
	close ($fh_out);

	#exit;

	# 出力ファイルをASCIIに変換
	#$self->to_ascii($self->output);
	
	#kh_jchar->to_sjis($self->output);

	return 1;
}

sub _tag{
	my $self = shift;
	my $t    = shift;
	my $fh   = shift;

	$t =~ tr/ /_/;
	print $fh $sjis->encode(
		unac_string(
			"$t\t$t\t$t\tタグ\n"
		)
	);

}

sub _sentence{
	my $self = shift;
	my $t    = shift;
	my $fh   = shift;
	
	unless (length($t)){
		#print "Empty!\n";
		return 1;
	}
	
	my @sentences = $self->{splitter}->split_array($t);
	
	foreach my $i (@sentences) {
		$self->_tokenize_stem($i, $fh);
		print $fh $sjis->encode("。\t。\t。\tALL\tSP\n");
	}

	return 1;
}


sub _tokenize_stem{
	my $self = shift;
	my $t    = shift;
	my $fh   = shift;
	
	my @words_hyoso;
	my @words_pos;
	
	my ($words_hyoso, $words_pos) = $self->tokenize($t);
	
	# Stemming
	my $words_stem = $self->stemming($words_hyoso);
	
	# Stemming結果のチェック
	my $n1 = @{$words_hyoso};
	my $n2 = @{$words_stem};
	unless ($n1 == $n2){
		print "t: $t\n";
		gui_errormsg->open(
			msg  => "Something wrong: stemmer's output",
			type => 'msg',
		);
		exit;
	}
	
	# Print
	my $n = 0;
	
	
	foreach my $i (@{$words_hyoso}){
		unless (length($words_stem->[$n])){
			$words_stem->[$n] = $i;
		}
		my $pos = '.';
		$pos = $words_pos->[$n] if $words_pos;
		print $fh $sjis->encode(
			unac_string(
				"$i\t$i\t$words_stem->[$n]\tALL\t\t$pos\n"
			)
		);
		++$n;
	}
	
	return 1;
}

sub stemming{
	my $self = shift;
	my $words_hyoso = shift;
		
	my $words_stem = [$self->{stemmer}->stem($words_hyoso)];
	
	# Stemming結果の前後に記号がついている場合は落とす
	foreach my $i (@{$words_stem}){
		if ($i =~ /^(\w+)\W+$/o){
			$i = $1;
		}
		elsif ($i =~ /^\W+(\w+)$/o){
			$i = $1;
		}
		#elsif ($i =~ /\w\W/o || $i =~ /\W\w/o){
		#	print "$i,";
		#}
	}
	return $words_stem;
}

sub to_ascii{
	my $self = shift;
	my $file = shift;
	
	use Text::Unaccent::PurePerl qw(unac_string);
	
	open (TEMP,$self->target)
		or gui_errormsg->open(type => 'file',thefile => $file);
	my $n = 0;
	my $t;
	while (<TEMP>){
		$t .= $_;
		++$n;
		last if $n > 1000;
	}
	close (TEMP);
	
	use Encode::Guess;
	my $enc = guess_encoding($t, qw/ascii latin1/);
	ref($enc) or die "illegal char-code!";
	
	print "name: ".$enc->name."\n";
	
	if ($enc->name eq 'ascii'){
		return 1;
	}
	
	my $temp_file = $::config_obj->file_temp;
	
	open (FROMF,$file)
		or gui_errormsg->open(type => 'file',thefile => "$file");
	open (TEMP,">$temp_file")
		or gui_errormsg->open(type => 'file',thefile => "$temp_file");

	while (<FROMF>){
		my $temp = $_;
		if ($temp =~ /。\t。\t。\t/o || $temp =~ /タグ/o){
			Encode::from_to(
				$temp,
				'euc-jp',
				'utf8'
			);
			print TEMP $temp;
		} else {
			#$temp = unac_string('latin1', $temp);
			Encode::from_to(
				$temp,
				'latin1',
				'utf8'
			);
			print TEMP $temp;
		}
	}

	close (FROMF);
	close (TEMP);
	unlink ("$file");
	rename ("$temp_file","$file");
	
	exit;
	
	return 1;
}



sub exec_error_mes{
	return "KH Coder Error!!\nStemmerによる処理に失敗しました。";
}


1;