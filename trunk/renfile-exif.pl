#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Add 'Exif date-time' to Image Files 
#                       （Exifによるファイル名への日時付加）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# renfile_exif_date.pl
# version 0.2 (2010/December/06)
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
# 
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
# 
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

#
# usage in GUI: perl renfile_exif_date.pl -gui
# usage in console: perl renfile_exif_date.pl
#
# target OS : Linux   対象OS : Linux
#

use strict;
use warnings;
use utf8;
use POSIX;
use Gtk2 qw/-init/;
use Image::ExifTool;
use File::Basename;
use Encode;

#use Data::Dumper;
#use Data::HexDump;

binmode( STDOUT, ":utf8" ); # "Wide character in print at ..." 警告を抑止

my $strTargetDir = $ENV{'HOME'};		# 対象ディレクトリ
my $flag_date_type = 'YYYY-mm-DD';	# 日時形式
my $flag_change_lowercase = 1;		# ファイル名を小文字に変換する

my @arrImageFiles = ();		# 画像ファイルを格納する配列
my @arrFileScanMask = ('*.jpg', '*.jpeg', '*.JPG', '*.JPEG');	# 処理対象

my $flag_gui = 0;
my $flag_verbose = 1;

my $return_code = undef;

# GUIスイッチを引数に起動されたとき（Gtk2でのユーザインターフェース対応）
if(defined($ARGV[0]) && !(lc($ARGV[0]) cmp '-gui')){ $flag_gui = 1; }

# ディクトリ、日時形式の入力
if($flag_gui == 1){ $return_code = sub_user_input_init_gui(); }
else { $return_code = sub_user_input_init(); }
if($return_code == 0){ exit(); }

# 対象ファイル一覧を @arrImageFiles 配列に格納する
sub_scan_imagefiles();

# 対象ファイル一覧を表示して、ファイル名変更を実行するかどうかユーザ選択させる
my $strPreview = sub_rename_main('preview');

if($flag_gui == 1){
	if(length($strPreview) > 0){
		if(sub_display_message($strPreview, "処理内容のプレビュー", "ファイル名変更処理をしますか？", "処理開始", "中止") == 0){ exit(); }
	}
	else {
		sub_display_message("", "指定されたフォルダには jpeg ファイルが見つかりませんでした", "", "", "終了");
		exit();
	}
}
else{
	if(length($strPreview)>0){
		print($strPreview);
		printf("ファイル名変更処理をしますか？ (Y) : ");
		$_ = <STDIN>;
		chomp($_);
		if(uc($_) ne 'Y' && $_ ne ''){ print("中止しました\n"); exit(); }
	}
	else {
		die("対象となるファイルが見つからないため終了します\n");
	}
}

$strPreview = sub_rename_main('exec');
if($flag_gui==1){ sub_display_message($strPreview, "", "以上の処理を完了しました", "", "終了"); }
else {
	print("===========================\n".$strPreview."\n以上の処理を完了しました\n");
}

exit();

# 対象ディレクトリ、処理形式などのユーザ入力（Gtk2のGUI版）
sub sub_user_input_init_gui {

	my $nReturn = 0;		# 戻り値（0:No, 1:Yes）

	my $window; # メインウインドウ

	$window = Gtk2::Window->new('toplevel');
	$window->signal_connect( "destroy" => sub { Gtk2::main_quit(); } ); # ウインドウの閉じるボタンの処理
	$window->set_title("$0 メインダイアログ");	# ダイアログのタイトルはスクリプト自身のファイル名
	$window->set_border_width(5);

	# 最上位コンテナ vbox を描画
	my $vbox = Gtk2::VBox->new();
	$window->add($vbox);

	# ラベル文字列
	my $label_top = Gtk2::Label->new("Exifを使ってファイル名に日時を付けます");
	$vbox->add($label_top);

	# 対象ディレクトリの選択（入力テキストボックスと、ブラウズ・ボタン）
	my $hbox_dir = Gtk2::HBox->new();
	$vbox->add($hbox_dir);

	my $label_dir = Gtk2::Label->new("対象ディレクトリ");
	$hbox_dir->add($label_dir);

	my $entry_dir = Gtk2::Entry->new();
	$entry_dir->set_text($strTargetDir);
	$entry_dir->set_width_chars(50);
	$hbox_dir->add($entry_dir);
	my $button_opendlg = Gtk2::Button->new("選択");
	$button_opendlg->signal_connect("clicked" => sub {
		my $strInput = $entry_dir->get_text();
		if(InputDialog_FileChooser($window, \$strInput, "select-folder", "ディレクトリを選択してください" ) == '1') {
			$entry_dir->set_text($strInput);
		}
		else {
			# $entry->set_text("Cancelが押されました");
		}
	});
	$hbox_dir->add($button_opendlg);

	# 日時の形式（コンボボックス）
	my $hbox_datetype = Gtk2::HBox->new();
	$vbox->add($hbox_datetype);

	my $label_datetype = Gtk2::Label->new("日時の形式");
	$hbox_datetype->add($label_datetype);
	
	my $combobox_datetype = Gtk2::ComboBox->new_text();
	$combobox_datetype->append_text('年月日（YYmmDD-）');
	$combobox_datetype->append_text('年月日（YYYYmmDD-）');
	$combobox_datetype->append_text('年月日時分（YYmmDDHHMM）');
	$combobox_datetype->append_text('年月日時分（YYYYmmDDHHMM）');
	$combobox_datetype->append_text('年月日（YY-mm-DD-）');
	$combobox_datetype->append_text('年月日（YYYY-mm-DD-）');
	$combobox_datetype->append_text('年月日時分（YY-mm-DD-HHMM）');
	$combobox_datetype->append_text('年月日時分（YYYY-mm-DD-HHMM）');
	$combobox_datetype->set_active(5);
	$hbox_datetype->add($combobox_datetype);


	# ファイル名の小文字変換（チェックボックス）
	my $hbox_lc = Gtk2::HBox->new();
	$vbox->add($hbox_lc);

	my $check_lc = Gtk2::CheckButton->new_with_label("ファイル名を小文字に変換する");
	if($flag_change_lowercase == 1){ $check_lc->set_active(1); }
	$hbox_lc->add($check_lc);


	# 実行・閉じるボタン
	my $hbox_buttons = Gtk2::HBox->new();
	$vbox->add($hbox_buttons);
	# 実行ボタン
	my $button_exec = Gtk2::Button->new("実行");
	$button_exec->signal_connect("clicked" => sub {
		# 実行ボタンが押されたときのコールバック関数
		$strTargetDir = $entry_dir->get_text();
		if(substr($strTargetDir,-1) ne '/'){ $strTargetDir .= '/'; }	# ディレクトリは / で終わるように修正
#		$strTargetDir = Encode::encode('utf8', $strTargetDir);	# Perl内部エンコードからUTF-8に変換し、かつ「UTF-8フラグを取る」
		my $nSelected = $combobox_datetype->get_active();
		if($nSelected == 0){ $flag_date_type = 'YYmmDD'; }
		elsif($nSelected == 1){ $flag_date_type = 'YYYYmmDD'; }
		elsif($nSelected == 2){ $flag_date_type = 'YYmmDDHHMM'; }
		elsif($nSelected == 3){ $flag_date_type = 'YYYYmmDDHHMM'; }
		elsif($nSelected == 4){ $flag_date_type = 'YY-mm-DD'; }
		elsif($nSelected == 5){ $flag_date_type = 'YYYY-mm-DD'; }
		elsif($nSelected == 6){ $flag_date_type = 'YY-mm-DD-HHMM'; }
		elsif($nSelected == 7){ $flag_date_type = 'YYYY-mm-DD-HHMM'; }
		if($check_lc->get_active() == 1){ $flag_change_lowercase = 1; }
		else{ $flag_change_lowercase = 0; }
		$nReturn = 1;
		Gtk2->main_quit();	# ウインドウのメインループを終了する
	});
	$hbox_buttons->add($button_exec);
	# 閉じるボタン
	my $button_cancel = Gtk2::Button->new("プログラム終了");
	$button_cancel->signal_connect("clicked" => sub { $nReturn=0; Gtk2->main_quit(); });
	$button_cancel->has_default(1);
	$hbox_buttons->add($button_cancel);

	$window->show_all();
	Gtk2->main();		# ダイアログのメインループ

#	$window->destroy();	# これはエラーが出る
	$window->hide_all();		# ウインドウが破棄後に残るのを対策する（この方法は正しいのか…）
	return($nReturn);

}

# ファイル（又はディレクトリ）を選択するコモンダイアログ
sub InputDialog_FileChooser
{
	my $window_main = shift; # 関数の引数（親ウインドウのハンドル）
	my $ref_strInput = shift; # 関数の引数（参照渡し。テキストボックスの文字列を返す）
	my $strMode = shift; # 関数の引数（ダイアログのモード。open, save, select-folder, create-folderのいづれか）
	my $sMessage = shift; # 関数の引数（メッセージとして表示する文字列）
	my $nResult = 0; # 戻り値（OK=1, Cancel=0）

	my $dialog = Gtk2::FileChooserDialog->new($sMessage, $window_main, $strMode, 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_current_folder($$ref_strInput);

	if($strMode ne "select-folder" && $strMode ne "create-folder") {
		# ファイル表示のフィルタ
		my $filter_text = Gtk2::FileFilter->new();
		$filter_text->set_name("画像ファイル");
		$filter_text->add_mime_type("image/*");
		$dialog->add_filter($filter_text);

		my $filter_all = Gtk2::FileFilter->new();
		$filter_all->set_name("全てのファイル");
		$filter_all->add_pattern("*");
		$dialog->add_filter($filter_all);
	}

	# 保存モードの時は、「無題.txt」と表示する
	if($strMode eq "save"){ $dialog->set_current_name("無題.txt"); }

	# ダイアログの応答ループ
	my $response = $dialog->run();
	if($response eq 'ok') {
		$nResult = 1;
		$$ref_strInput = $dialog->get_filename();
	}
	else{$nResult = 0;}

	$dialog->destroy;
	return($nResult);
}

# メッセージ・ダイアログ
#
# 例： sub_display_message("メッセージ文字列", "タイトル", "選択してください", "YES", "NO");
#
sub sub_display_message {

	# サブルーチンの引数
	my $strTextMain = shift;	# ウインドウ内に表示するテキスト
	my $strTextTitle = shift;	# タイトルに表示するテキスト
	my $strTextQuestion = shift;	# 選択肢を選択するよう促すテキスト
	my $strYes = shift;		# YESの文字列
	my $strNo = shift;		# NOの文字列

	my $nReturn = 0;		# 戻り値（0:No, 1:Yes）

	my $window; # メインウインドウ

	$window = Gtk2::Window->new('toplevel');
	$window->signal_connect( "destroy" => sub { Gtk2::main_quit(); } ); # ウインドウの閉じるボタンの処理
	$window->set_title("$0");	# ダイアログのタイトルは、スクリプト自身のファイル名
	$window->set_border_width(5);

	my $vbox = Gtk2::VBox->new();
	$window->add($vbox);

	# ダイアログの一番上に表示されるラベル（文字列）
	if(length($strTextTitle)>0) {
		my $label_top = Gtk2::Label->new($strTextTitle);
		$vbox->add($label_top);
	}

	# テキスト・ビュー（スクロール可能）
	if(length($strTextMain)>0) {
		my $scroll = Gtk2::ScrolledWindow->new();
		$scroll->set_size_request(500, 350);
		my $text_view = Gtk2::TextView->new();
		# $text_view->set_editable(0);
		my $text_buffer = Gtk2::TextBuffer->new();
		$text_buffer->set_text($strTextMain);
		$text_view->set_buffer($text_buffer);
		$scroll->add($text_view);
		$vbox->add($scroll);
	}

	# 選択ボタンのすぐ上に表示されるラベル（文字列）
	if(length($strTextQuestion)>0) {
		my $label_bottom = Gtk2::Label->new($strTextQuestion);
		$vbox->add($label_bottom);
	}

	# 実行・閉じるボタン
	my $hbox_buttons = Gtk2::HBox->new();
	$vbox->add($hbox_buttons);
	# YESボタン
	if(length($strYes)>0) {
		my $button_exec = Gtk2::Button->new($strYes);
		$button_exec->signal_connect("clicked" => sub { $nReturn=1; Gtk2->main_quit(); });
		$hbox_buttons->add($button_exec);
	}
	# NOボタン
	if(length($strNo)>0) {
		my $button_cancel = Gtk2::Button->new($strNo);
		$button_cancel->signal_connect("clicked" => sub { $nReturn=0; Gtk2->main_quit(); });
		$hbox_buttons->add($button_cancel);
	}

	$window->show_all();
	Gtk2->main();

	$window->hide_all();
	return($nReturn);

}

# 対象ディレクトリ、処理形式などのユーザ入力（コンソール版）
sub sub_user_input_init {

	print("対象ディレクトリ : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<1){ die("ディレクトリが入力されませんでした\n"); }
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $_){ die("指定されたディレクトリは存在しません\n"); }
	$strTargetDir = $_;

	print("日時形式の選択\n1.YYmmDD\n2.YYYYmmDD\n3.YYmmDDHHMM\n4.YYYYmmDDHHMM\n".
		"5.YY-mm-DD\n6.YYYY-mm-DD\n7.YY-mm-DD-HHMM\n8.YYYY-mm-DD-HHMM\n[1〜8] : ");
	$_ = <STDIN>;
	chomp;
	if(int($_)<1 || int($_)>8){ die("1〜8の範囲外が入力されました\n"); }
	if($_==1){$flag_date_type = 'YYmmDD'; }
	elsif($_==2){$flag_date_type = 'YYYYmmDD'; }
	elsif($_==3){$flag_date_type = 'YYmmDDHHMM'; }
	elsif($_==4){$flag_date_type = 'YYYYmmDDHHMM'; }
	elsif($_==5){$flag_date_type = 'YY-mm-DD'; }
	elsif($_==6){$flag_date_type = 'YYYY-mm-DD'; }
	elsif($_==7){$flag_date_type = 'YY-mm-DD-HHMM'; }
	elsif($_==8){$flag_date_type = 'YYYY-mm-DD-HHMM'; }


	printf("同時に、ファイル名を小文字に変換しますか？ (Y) : ");
	$_ = <STDIN>;
	chomp;
	if(uc($_) eq 'Y'){ $flag_change_lowercase = 1; }
	else {$flag_change_lowercase = 0; }

	return(1);
}

# 対象画像ファイルを配列に格納する
sub sub_scan_imagefiles {

	my @arrScan = undef;	# ファイル一覧を一時的に格納する配列
	my $tmpDate = undef;	# UNIX秒（ファイル/Exifのタイムスタンプ）
	my $exifTool = Image::ExifTool->new();
#	$exifTool->Options(DateFormat => "%s", StrictDate=> 1);		# 環境によって %s がサポートされない場合有り
	$exifTool->Options(DateFormat => "%Y,%m,%d,%H,%M,%S", StrictDate=> 1);

	# grob で用いるファイル検索パターン文字列を作成
	my $strScanPattern = '';
	foreach(@arrFileScanMask){
		if(length($strScanPattern)>1 && substr($strScanPattern,-1) ne ' '){$strScanPattern .= ' ';}
		$strScanPattern .= $strTargetDir.$_;
	}

	# ファイル一覧を得て、配列に格納
	@arrScan = glob($strScanPattern);

	# 各ファイルのディレクトリ名、Exif日時を配列 @arrImageFiles に格納
	foreach(@arrScan)
	{
		if(length($_) <= 0){ next; }
		$exifTool->ImageInfo($_);
		$tmpDate = $exifTool->GetValue('CreateDate');
		if(!defined($tmpDate)){ $tmpDate = 0; }	# Exifが無い場合は 0
		else{
			my @arrTime_t = split(/,/,$tmpDate);
			$tmpDate = mktime($arrTime_t[5], $arrTime_t[4], $arrTime_t[3], $arrTime_t[2], $arrTime_t[1]-1, $arrTime_t[0]-1900);
		}
		my @arrTemp = ($_, dirname($_), basename($_), $tmpDate);
		push(@arrImageFiles, \@arrTemp);
	}

}


# ファイルのリネーム
sub sub_rename_main {

	my $flag_preview = shift;	# プレビューの時 'preview'
	my $strReturn = '';		# 処理一覧（ファイルの一覧）をユーザ用に整形した文字列
	my $nCount = 0;		# 処理対象ファイル数

	if($#arrImageFiles < 0){ return(''); }

	$strReturn .= sprintf("対象ディレクトリ : %s", decode('utf8', $arrImageFiles[0][1]))."\n\n";

	foreach(@arrImageFiles){
		if(length($_->[3])<8){ $strReturn .= sprintf("--   : %s (no exif)", decode('utf8', $_->[2]))."\n"; }
		else{
			my @tm = localtime($_->[3]);
			my $strFormat;
			my $nFormatYear;
			if($flag_date_type eq 'YYmmDD'){ $strFormat = "%02d%02d%02d"; $nFormatYear = ($tm[5]+1900)%100; }
			elsif($flag_date_type eq 'YYYYmmDD'){ $strFormat = "%04d%02d%02d"; $nFormatYear = ($tm[5]+1900);}
			elsif($flag_date_type eq 'YYmmDDHHMM'){ $strFormat = "%02d%02d%02d%02d%02d"; $nFormatYear = ($tm[5]+1900)%100;}
			elsif($flag_date_type eq 'YYYYmmDDHHMM'){ $strFormat = "%04d%02d%02d%02d%02d"; $nFormatYear = ($tm[5]+1900);}
			elsif($flag_date_type eq 'YY-mm-DD'){ $strFormat = "%02d-%02d-%02d"; $nFormatYear = ($tm[5]+1900)%100; }
			elsif($flag_date_type eq 'YYYY-mm-DD'){ $strFormat = "%04d-%02d-%02d"; $nFormatYear = ($tm[5]+1900);}
			elsif($flag_date_type eq 'YY-mm-DD-HHMM'){ $strFormat = "%02d-%02d-%02d-%02d%02d"; $nFormatYear = ($tm[5]+1900)%100;}
			elsif($flag_date_type eq 'YYYY-mm-DD-HHMM'){ $strFormat = "%04d-%02d-%02d-%02d%02d"; $nFormatYear = ($tm[5]+1900);}
			else{ $strFormat = "%02d%02d%02d"; $nFormatYear = ($tm[5]+1900)%100; }

			my $strYMD = sprintf($strFormat, $nFormatYear,		# year
								$tm[4]+1,		# month
								$tm[3],		# day
								$tm[2],		# hour
								$tm[1]			# sec
								);
			my $strNewName = sprintf("%s/%s-%s", $_->[1],		# dir
								$strYMD,		# YMD
								$_->[2]		# filename
								);
			
			if($flag_change_lowercase == 1){ $strNewName = lc($strNewName); }
			
			if(length($strYMD)<length($_->[2]) && substr($_->[2], 0, length($strYMD)) eq $strYMD) {
				# 改名済みの時は、スキップ
				$strReturn .= sprintf("-- : %s", decode('utf8', $_->[2]))."\n";
			}
			else{
				# 改名する
				if($flag_preview eq 'preview'){
					# プレビューモード
					$strReturn .= sprintf("変更 : %s -> %s", decode('utf8', $_->[2]), decode('utf8', basename($strNewName)))."\n";
					$nCount++;
				}
				else {
					# 改名
					if(rename($_->[0], $strNewName) == 1){
						$strReturn .= sprintf("変更 : %s -> %s", decode('utf8', $_->[2]), decode('utf8', basename($strNewName)))."\n";
						$nCount++;
					}
					else{ $strReturn .= sprintf("失敗 : %s", decode('utf8', $_->[2]))."\n"; }
				}
			}
		}
	}

	if($flag_preview eq 'preview'){
		$strReturn .= "\n".sprintf("%d 個のファイル中、対象画像は %d 個です", $#arrImageFiles + 1, $nCount)."\n";
	}
	else{
		$strReturn .= "\n".sprintf("%d 個のファイルを改名しました", $nCount)."\n";
	}

	return($strReturn);
}

# スクリプト終了 EOF

