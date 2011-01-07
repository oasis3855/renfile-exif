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
# version 0.3 (2011/January/04)
# version 0.4 (2011/January/05)
# version 0.5 (2011/January/07)
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

my $flag_os = 'linux';	# linux/windows
my $flag_charcode = 'utf8';		# utf8/shiftjis

use POSIX;
use Gtk2 qw/-init/;	# Windowsの場合は、この行をコメントアウト
use Image::ExifTool;
use File::Basename;
use Encode::Guess qw/euc-jp shiftjis iso-2022-jp/;	# 必要ないエンコードは削除すること

#use Data::Dumper;
#use Data::HexDump;


# IOの文字コードを規定
if($flag_charcode eq 'utf8'){
	binmode(STDIN, ":utf8");
	binmode(STDOUT, ":utf8");
	binmode(STDERR, ":utf8");
}
if($flag_charcode eq 'shiftjis'){
	binmode(STDIN, "encoding(sjis)");
	binmode(STDOUT, "encoding(sjis)");
	binmode(STDERR, "encoding(sjis)");
}

my $strTargetDir = $ENV{'HOME'};		# 対象ディレクトリ
my $flag_date_type = 'YYYY-mm-DD';	# 日時形式
my $flag_change_lowercase = 1;		# ファイル名を小文字に変換する

my @arrImageFiles = ();		# 画像ファイルを格納する配列

my @arrFileScanMask = undef;
if($flag_os eq 'linux'){
	@arrFileScanMask = ('*.jpg', '*.jpeg', '*.JPG', '*.JPEG');	# 処理対象
}
if($flag_os eq 'windows'){
	@arrFileScanMask = ('*.jpg', '*.jpeg');	# 処理対象
				# Windowsの場合は、大文字の .JPG .JPEG の記述不要
}
my @arrKnownExt = ('.jpg', '.jpeg', '.JPG', '.JPEG');

my $flag_gui = 0;	# GUIを表示するとき 1
my $flag_fname_style = 'date-base';		# date-base, base-date, date : ファイル名決定で日時と元ファイル名の利用方法
my $flag_undo_mode = 0;		# 0:OFF, 1:ON
my $flag_verbose = 1;

my $return_code = undef;

# GUIスイッチを引数に起動されたとき（Gtk2でのユーザインターフェース対応）
if(defined($ARGV[0]) && !(lc($ARGV[0]) cmp '-gui')){ $flag_gui = 1; }
else{
	print("\n".basename($0)." - ファイル名にExifより日時を付加するスクリプト\n".
		"GUI版は -gui スイッチで起動できます\n\n");
}

# ディクトリ、日時形式の入力
if($flag_gui == 1){ $return_code = sub_user_input_init_gui(); }
else { $return_code = sub_user_input_init(); }
if($return_code == 0){ exit(); }

# 対象ファイル一覧を @arrImageFiles 配列に格納する
sub_scan_imagefiles();
sub_sort_imagefiles();

# 対象ファイル一覧を表示して、ファイル名変更を実行するかどうかユーザ選択させる
my $strPreview = sub_rename_main('preview');

if($flag_gui == 1){
	if(length($strPreview) > 0){
		if(sub_display_message($strPreview, "処理内容のプレビュー", "ファイル名変更処理をしますか？",
			 "処理開始", "中止") == 0){ exit(); }
	}
	else {
		sub_display_message("", "指定されたフォルダには jpeg ファイルが見つかりませんでした", "", "", "終了");
		exit();
	}
}
else{
	if(length($strPreview)>0){
		print($strPreview);
		printf("ファイル名変更処理をしますか？ (Y/N) [N] : ");
		$_ = <STDIN>;
		chomp($_);
		if(length($_)<=0 || uc($_) ne 'Y'){ die("User Cansel(キャンセルしました)\n"); }
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
	$combobox_datetype->set_active(0);
	$hbox_datetype->add($combobox_datetype);

	# ファイル名形式（コンボボックス）
	my $hbox_filenametype = Gtk2::HBox->new();
	$vbox->add($hbox_filenametype);

	my $label_filenametype = Gtk2::Label->new("ファイル名形式");
	$hbox_filenametype->add($label_filenametype);
	
	my $combobox_filenametype = Gtk2::ComboBox->new_text();
	$combobox_filenametype->append_text('日時-元ファイル名（YMD-basename.jpg）');
	$combobox_filenametype->append_text('元ファイル名-日時（basename-YMD.jpg）');
	$combobox_filenametype->append_text('日時（YMD.jpg）');
	$combobox_filenametype->set_active(0);
	$hbox_filenametype->add($combobox_filenametype);

	# ファイル名の小文字変換（チェックボックス）
	my $hbox_lc = Gtk2::HBox->new();
	$vbox->add($hbox_lc);

	my $check_lc = Gtk2::CheckButton->new_with_label("ファイル名を小文字に変換する");
	if($flag_change_lowercase == 1){ $check_lc->set_active(1); }
	$hbox_lc->add($check_lc);

	# Undoモード（チェックボックス）
	my $hbox_undo = Gtk2::HBox->new();
	$vbox->add($hbox_undo);

	my $check_undo = Gtk2::CheckButton->new_with_label("Undoモード（ファイル名を元に戻す）");
	if($flag_undo_mode == 1){ $check_undo->set_active(1); }
	$hbox_undo->add($check_undo);


	# 実行・閉じるボタン
	my $hbox_buttons = Gtk2::HBox->new();
	$vbox->add($hbox_buttons);
	# 実行ボタン
	my $button_exec = Gtk2::Button->new("実行");
	$button_exec->signal_connect("clicked" => sub {
		# 実行ボタンが押されたときのコールバック関数
		$strTargetDir = $entry_dir->get_text();
		if(substr($strTargetDir,-1) ne '/'){ $strTargetDir .= '/'; }	# ディレクトリは / で終わるように修正

		my $nSelected = $combobox_datetype->get_active();
		if($nSelected == 0){ $flag_date_type = 'YYmmDD'; }
		elsif($nSelected == 1){ $flag_date_type = 'YYYYmmDD'; }
		elsif($nSelected == 2){ $flag_date_type = 'YYmmDDHHMM'; }
		elsif($nSelected == 3){ $flag_date_type = 'YYYYmmDDHHMM'; }
		elsif($nSelected == 4){ $flag_date_type = 'YY-mm-DD'; }
		elsif($nSelected == 5){ $flag_date_type = 'YYYY-mm-DD'; }
		elsif($nSelected == 6){ $flag_date_type = 'YY-mm-DD-HHMM'; }
		elsif($nSelected == 7){ $flag_date_type = 'YYYY-mm-DD-HHMM'; }

		$nSelected = $combobox_filenametype->get_active();
		if($nSelected == 0){ $flag_fname_style = 'date-base'; }
		elsif($nSelected == 1){ $flag_fname_style = 'base-date'; }
		elsif($nSelected == 2){ $flag_fname_style = 'date'; }

		if($check_lc->get_active() == 1){ $flag_change_lowercase = 1; }
		else{ $flag_change_lowercase = 0; }

		if($check_undo->get_active() == 1){ $flag_undo_mode = 1; }
		else{ $flag_undo_mode = 0; }

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

	# プログラムの引数は、対象ディレクトリとする
	if($#ARGV == 0 && length($ARGV[0])>1)
	{
		$strTargetDir = sub_conv_to_flagged_utf8($ARGV[0]);
	}

	# 対象ディレクトリの入力
	print("対象ディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）");
	if(length($strTargetDir)>0){ print("[$strTargetDir] :"); }
	else{ print(":"); }
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){
		if(length($strTargetDir)>0){ $_ = $strTargetDir; }	# スクリプトの引数のデフォルトを使う場合
		else{ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	}
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d sub_conv_to_local_charset($_)){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	unless($_ =~ m/^\// || $_ =~ m/^\.\//){ $strTargetDir = "./".$_; }
	else{ $strTargetDir = $_; }
	$strTargetDir = sub_conv_to_flagged_utf8($strTargetDir);
	print("対象ディレクトリ : " . $strTargetDir . "\n\n");


	printf("元のファイル名に復元するUndoモードで実行しますか？ (Y/N) [N] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0 || uc($_) eq 'N'){
		$flag_undo_mode = 0;
		print("Undoモード : OFF（通常のExifリネームを行います）\n\n");
	}
	else {
		$flag_undo_mode = 1;
		print("Undoモード : ON（元のファイル名に復元します）\n\n");
	}


	if($flag_undo_mode == 0){
		print("日時形式の選択\n1.YYmmDD\n2.YYYYmmDD\n3.YYmmDDHHMM\n4.YYYYmmDDHHMM\n".
			"5.YY-mm-DD\n6.YYYY-mm-DD\n7.YY-mm-DD-HHMM\n8.YYYY-mm-DD-HHMM\n(1-8) [1] : ");
		$_ = <STDIN>;
		chomp;
		if(length($_)<=0){ $_ = 1; }
		if(int($_)<1 || int($_)>8){ die("1-8の範囲外が入力されました\n"); }
		if($_==1){$flag_date_type = 'YYmmDD'; }
		elsif($_==2){$flag_date_type = 'YYYYmmDD'; }
		elsif($_==3){$flag_date_type = 'YYmmDDHHMM'; }
		elsif($_==4){$flag_date_type = 'YYYYmmDDHHMM'; }
		elsif($_==5){$flag_date_type = 'YY-mm-DD'; }
		elsif($_==6){$flag_date_type = 'YYYY-mm-DD'; }
		elsif($_==7){$flag_date_type = 'YY-mm-DD-HHMM'; }
		elsif($_==8){$flag_date_type = 'YYYY-mm-DD-HHMM'; }

		print("日付形式 : ".$flag_date_type."\n\n");
	}

	print("ファイル名形式の選択\n1.日時-元ファイル名.jpg\n2.元ファイル名-日時.jpg\n3.日時.jpg\n".
		"\n(1-3) [1] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){ $_ = 1; }
	if(int($_)<1 || int($_)>3){ die("1-3の範囲外が入力されました\n"); }
	if($_==1){$flag_fname_style = 'date-base'; }
	elsif($_==2){$flag_fname_style = 'base-date'; }
	elsif($_==3){$flag_fname_style = 'date'; }

	print("ファイル名形式 : ".$flag_fname_style."\n\n");

	if($flag_fname_style eq 'date' && $flag_undo_mode == 1){
		die("元のファイル名が失われていますので Undo できません。\n");
	}

	printf("同時に、ファイル名を小文字に変換しますか？ (Y/N) [Y] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0 || uc($_) eq 'Y'){
		$flag_change_lowercase = 1;
		print("ファイル名小文字化 : ON\n\n");
	}
	else {
		$flag_change_lowercase = 0;
		print("ファイル名小文字化 : OFF\n\n");
	}

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
	@arrScan = glob(sub_conv_to_local_charset($strScanPattern));

	# 各ファイルのディレクトリ名、Exif日時を配列 @arrImageFiles に格納
	foreach(@arrScan)
	{
		if(length($_) <= 0){ next; }
		$_ = sub_conv_to_flagged_utf8($_);
		$exifTool->ImageInfo(sub_conv_to_local_charset($_));
		$tmpDate = $exifTool->GetValue('CreateDate');
		if(!defined($tmpDate)){ $tmpDate = 0; }	# Exifが無い場合は 0
		else{
			my @arrTime_t = split(/,/,$tmpDate);
			$tmpDate = mktime($arrTime_t[5], $arrTime_t[4], $arrTime_t[3], $arrTime_t[2], $arrTime_t[1]-1, $arrTime_t[0]-1900);
		}
		my $str_dirname = dirname($_);
		unless($str_dirname =~ /\/$/){ $str_dirname .= '/'; }		# ディレクトリ名は末尾が / で終わるよう調整
		my @arrTemp = ($_,			# [0]: 元ファイルのフルパス
					$str_dirname,	# [1]: ディレクトリ名
					basename($_, @arrKnownExt),	# [2]: 拡張子抜きのbasename
					$tmpDate,		# [3]: 日時unix時刻
					''				# [4]: 変更後のファイル名
					);

		push(@arrImageFiles, \@arrTemp);
	}

}


# 対象画像ファイルの配列をソートする
sub sub_sort_imagefiles {

	# unux時間でソートする

	@arrImageFiles = sort { @$a[3] <=> @$b[3]} @arrImageFiles;

}



# ファイルのリネーム
sub sub_rename_main {

	my $flag_preview = shift;	# プレビューの時 'preview'
	my $strReturn = '';		# 処理一覧（ファイルの一覧）をユーザ用に整形した文字列
	my $nCount = 0;		# 処理対象ファイル数

	if($#arrImageFiles < 0){ return(''); }

	$strReturn .= "対象ディレクトリ : ".$arrImageFiles[0][1]."\n\n";

	# ファイル一時退避用のランダム文字列（元ファイル→一時退避→新ファイル）
	my $strT = '.';
	for(1 .. 5){ $strT .= sub_rand_char(); }

	# 改名orプレビュー pass1 （新ファイル名作成、一時ファイル名へ退避）
	for(my $i=0; $i<=$#arrImageFiles; $i++){
		if(length($arrImageFiles[$i][3]) < 8){
				# unix秒が8桁未満は異常
				$strReturn .= "--   : ".$arrImageFiles[$i][2]." (no exif)\n";
				$arrImageFiles[$i][4] = $arrImageFiles[$i][2].'.jpg';	# 新ファイル名リストに入れる（ファイル名重複検査用）
			}
		else{
			my $strNewName = sub_make_new_filename($arrImageFiles[$i][2], $arrImageFiles[$i][3]);
			$arrImageFiles[$i][4] = $strNewName;	# 新ファイル名リストに入れる（ファイル重複検査用）
			$strNewName = $arrImageFiles[$i][1].$strNewName;
			
			if($arrImageFiles[$i][0] eq $strNewName){
				# 変更前後のファイル名が同一の時、何もしない
				$strReturn .= "---- : ".basename($arrImageFiles[$i][0])." == ".basename($strNewName)."\n";
			}
			else{
				# 改名する
				if($flag_preview eq 'preview'){
					# プレビューモード
					$strReturn .= "変更 : ".basename($arrImageFiles[$i][0])." -> ".basename($strNewName)."\n";
					$nCount++;
				}
				else {
					# 改名（元ファイル→一時ファイル）
					my $strTempFile = $arrImageFiles[$i][0] . $strT;

					if(rename(sub_conv_to_local_charset($arrImageFiles[$i][0]),
						 sub_conv_to_local_charset($strTempFile)) == 1){
#						$strReturn .= "変更 : ".basename($arrImageFiles[$i][0])." -> ".basename($strTempFile)."\n";
					}
					else{ $strReturn .= "失敗 : ".basename($arrImageFiles[$i][0])." -> ".basename($strTempFile)."\n"; }
				}
			}
		}
	}

	# 改名 pass2 （一時ファイルから新ファイル）
	if($flag_preview ne 'preview'){
		for(my $i=0; $i<=$#arrImageFiles; $i++){

			if(length($arrImageFiles[$i][3]) < 8){ next; }	# exif無しスキップ
			my $strNewName = $arrImageFiles[$i][1].$arrImageFiles[$i][4];	# 新ファイル名
			if($arrImageFiles[$i][0] eq $strNewName){ next; }	# 新旧ファイル名同一スキップ
			my $strTempFile = $arrImageFiles[$i][0] . $strT;
			if(rename(sub_conv_to_local_charset($strTempFile),
				 sub_conv_to_local_charset($strNewName)) == 1){
				$strReturn .= "変更 : ".basename($arrImageFiles[$i][0])." -> ".basename($strNewName)."\n";
				$nCount++;
			}
			else{ $strReturn .= "失敗 : ".basename($strTempFile)." -> ".basename($strNewName)."\n"; }

		}
	}


	if($flag_preview eq 'preview'){
		$strReturn .= "\n".sprintf("%d 個のファイル中、対象画像は %d 個です", $#arrImageFiles + 1, $nCount)."\n";
		
		# 新ファイル名（チェック用）をクリア
		for(my $i=0; $i<=$#arrImageFiles; $i++){ $arrImageFiles[$i][4] = ''; }
	}
	else{
		$strReturn .= "\n".sprintf("%d 個のファイルを改名しました", $nCount)."\n";
	}

	return($strReturn);
}


# 改名予定のファイル名と一致しない、新ファイル名を生成する。（末尾に-000から-999の枝番を振る）
sub sub_make_new_filename{
	my $strOrgBasename = shift;
	my $tm = shift;
	
	my @arr_basename = split(/-/, $strOrgBasename);
	if($flag_fname_style eq 'date-base'){ $strOrgBasename = $arr_basename[$#arr_basename]; }
	if($flag_fname_style eq 'base-date'){ $strOrgBasename = $arr_basename[0]; }

	my @tm = localtime($tm);
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

	if($flag_change_lowercase == 1){ $strOrgBasename = lc($strOrgBasename); }	# ファイル名の小文字化

	# 新ファイル名を決定する
	my $strNewName = undef;
	if($flag_undo_mode == 1){
		$strNewName = $strOrgBasename.'.jpg';
	}
	elsif($flag_fname_style eq 'date-base'){
		$strNewName = sprintf("%s-%s.jpg", $strYMD, $strOrgBasename);
	}
	elsif($flag_fname_style eq 'base-date'){
		$strNewName = sprintf("%s-%s.jpg", $strOrgBasename, $strYMD);
	}
	elsif($flag_fname_style eq 'date'){
		$strNewName = sprintf("%s.jpg", $strYMD);
	}

	# 内部サブルーチン（ファイル名リスト内で一致すれば1を返す）
	my $include = sub { $_=shift; for(my $i=0; $i<=$#arrImageFiles; $i++){ if($_ eq $arrImageFiles[$i][4]){ return(1); } } return(0); };

	# 改名予定の新ファイル名リストに一致していれば、枝番を振る
	for(my $i=1; $i<=1000; $i++){
		if(&$include($strNewName) == 1)
		{
			if($i >= 1000){ die("exceed counter 999 at ".$strOrgBasename."\n"); }
			if($flag_undo_mode == 1){
				$strNewName = sprintf("%s-%03d.jpg", $i, $strOrgBasename);
			}
			elsif($flag_fname_style eq 'date-base'){
				$strNewName = sprintf("%s-%03d-%s.jpg", $strYMD, $i, $strOrgBasename);
			}
			elsif($flag_fname_style eq 'base-date'){
				$strNewName = sprintf("%s-%s-%03d.jpg", $strOrgBasename, $strYMD, $i);
			}
			elsif($flag_fname_style eq 'date'){
				$strNewName = sprintf("%s-%03d.jpg", $strYMD, $i);
			}
		}
		else{ last; }
	}
	
	return($strNewName);
}

# 任意の文字コードの文字列を、UTF-8フラグ付きのUTF-8に変換する
sub sub_conv_to_flagged_utf8{

	my $str = shift;

	my $enc = Encode::Guess->guess($str);	# 文字列のエンコードの判定

	# デバッグ表示
#	print Data::Dumper->Dumper(\$enc)."\n";
#	if(ref($enc) eq 'Encode::XS'){
#		print("detect : ".$enc->mime_name()."\n");
#	}
#	print "is_utf8: ".utf8::is_utf8($str)."\n";

	unless(ref($enc)){
		# エンコード形式が2個以上帰ってきた場合 （shiftjis or utf8）
		# 最初の候補でデコードする
		my @arr_encodes = split(/ /, $enc);
		if(lc($arr_encodes[0]) eq 'shiftjis' || lc($arr_encodes[0]) eq 'euc-jp' || 
			lc($arr_encodes[0]) eq 'utf8' || lc($arr_encodes[0]) eq 'us-ascii'){
				$str = Encode::decode($arr_encodes[0], $str);
			}
	}
	else{
		# UTF-8でUTF-8フラグが立っている時以外は、変換を行う
		unless(ref($enc) eq 'Encode::utf8' && utf8::is_utf8($str) == 1){
			$str = $enc->decode($str);
		}
	}

	# デバッグ表示
#	print "debug: ".$str."\n";

	return($str);

}


# 任意の文字コードの文字列を、UTF-8フラグ無しのUTF-8に変換する
sub sub_conv_to_unflagged_utf8{

	my $str = shift;

	# いったん、フラグ付きのUTF-8に変換
	$str = sub_conv_to_flagged_utf8($str);

	return(Encode::encode('utf8', $str));

}


# UTF8から現在のOSの文字コードに変換する
sub sub_conv_to_local_charset{
	my $str = shift;

	# UTF8から、指定された（OSの）文字コードに変換する
	$str = Encode::encode($flag_charcode, $str);
	
	return($str);
}


# ランダムな文字を作成する
sub sub_rand_char {

	my @arrSeedChars = ();
	
	push @arrSeedChars, ('a'..'z');
	push @arrSeedChars, ('A'..'Z');
	push @arrSeedChars, ('0'..'9');

	return $arrSeedChars[int(rand($#arrSeedChars+1))];
}


# スクリプト終了 EOF

