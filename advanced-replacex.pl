
use Purple;
use Pidgin;
use Gtk2;

# Changelog
#
# v0.1 - 27.02.2011 (DD.MM.YYYY)
#  - Release
#
#
# Based on ReplaceX from Sadrul Habib Chowdhury
#

my @names = ();
my %rules = ();

%PLUGIN_INFO = (
	perl_api_version => 2,
	name => "Advanced ReplaceX in Perl",
	version => "0.1",
	summary =>     "Text replacement plugin, with regex and gui support.",
	description => "Text replacement plugin, with regex and gui support. See '/help rx' for more information.",
	author => "Stefan Gipper <support\@coder-world.de>",
	url => "http://code.google.com/p/advanced-replacex-perl-pidgin/",
	load => "plugin_load",
	unload => "plugin_unload",
	prefs_info => "prefs_info_cb"
);

sub escape_text {
	my $text = shift;
	$text =~ s/&/&amp/g;
	$text =~ s/</&lt;/g;
	return $text;
}

sub save_rules {
	local @ar = ();
	while(my($k, $v) = each(%rules)){
		push(@ar, $k) if($k);
	}
	push(@ar, "");
	Purple::Prefs::set_string_list("/plugins/core/rx/names", \@ar);
	load_prefs();
}

sub prefs_info_cb {
	$windowtopreplace = Gtk2::Window->new();
	$windowtopreplace->set_title("Advanced ReplaceX");
	$windowtopreplace->set_size_request(607,520);
	$windowtopreplace->set_resizable(0);
	$windowtopreplace->set_position('center_always');
	$windowtopreplace->set_border_width(1);

	$filesfixed = new Gtk2::Fixed();
	$windowtopreplace->add( $filesfixed );
	$filesfixed->show();

	$filessuchword = Gtk2::Label->new();
	$filessuchword->set_markup(" <span size=\"7\"> Eingabe: </span> ");

	$filesentry = Gtk2::Entry->new();

	$filescompletion = Gtk2::EntryCompletion->new;
	$filesentry->set_completion ($filescompletion);
	$filescompletion->set_model (create_completion_model ());
	$filescompletion->set_text_column (0);
	$filesentry->set_size_request (415, 25);

	$filesbutton = Gtk2::Button->new_from_stock('gtk-find');
	find_and_set_label_in($filesbutton->child, " Suchen ");

	$filesfixed->put( $filessuchword, 8, 15 );
	$filesfixed->put( $filesentry, 85, 15 );
	$filesfixed->put( $filesbutton, 512, 14 );

	$filessearchtview1 = Gtk2::ScrolledWindow->new (undef, undef);
	$filessearchtview1->set_shadow_type ('etched-out');
	$filessearchtview1->set_policy ('automatic', 'automatic');
	$filessearchtview1->set_size_request (593, 415);

	@searchdata = ();
	my $data = &searchdata();
	foreach my $selectdata (@$data){
		push(@searchdata, \%$selectdata );
	}
	$replacemodel = create_model4();
	$filestreeview = Gtk2::TreeView->new ($replacemodel);
	$filestreeview->set_rules_hint(1);
	$filestreeview->get_selection->set_mode('single');
	$filestreeview->set_search_column(0);
	$filestreeview->set_enable_tree_lines(1);
	$filestreeview->set_grid_lines('vertical');#vertical, horizontal, none, both

	$filessearchtview1->add($filestreeview);
	add_columns4($filestreeview);
	$filesfixed->put( $filessearchtview1, 2, 60 );

	my $filesentrysend_sig = $filesentry->signal_connect ('key-press-event' => sub {
			my ($widget,$event)= @_;
			if( $event->keyval() == 65293){
				my $search = lc($filesentry->get_text());
				$replacemodel->clear;
				@filesdata = ();
				my $data = &searchdata();
				foreach my $selectdata (@$data){
					if(!$search or $search && lc($$selectdata{'name'}) =~ /\Q$search\E/i){
						push(@filesdata, \%$selectdata );
					}
				}
				foreach my $d (@filesdata) {
					my $iter = $replacemodel->append;
					$replacemodel->set ($iter,
					   0, $d->{name},
					   1, $d->{text},
					   2, $d->{replace}
					);
				}
			}
		}
	);
	my $filesbuttonsend_sig = $filesbutton->signal_connect ('clicked' => sub {
			my $search = lc($filesentry->get_text());
			$replacemodel->clear;
			@filesdata = ();
			my $data = &searchdata();
			foreach my $selectdata (@$data){
				if(!$search or $search && lc($$selectdata{'name'}) =~ /\Q$search\E/i){
					push(@filesdata, \%$selectdata );
				}
			}
			foreach my $d (@filesdata) {
				my $iter = $replacemodel->append;
				$replacemodel->set ($iter,
				   0, $d->{name},
				   1, $d->{text},
				   2, $d->{replace}
				);
			}
		}
	);
	$windowtopreplace->show_all;
}

sub remove_rules {
	my @r = shift();
	foreach (@r){
		Purple::Prefs::set_string("/plugins/core/rx/rules/$_/text", '');
		Purple::Prefs::set_string("/plugins/core/rx/rules/$_/replace", '');
		Purple::Prefs::remove("/plugins/core/rx/rules/$_");
		delete $rules{$_};
	}
	save_rules();
}

sub rx_cmd_cb {
	my($conv, $cmd, $data, @args) = @_;
	my $flag = shift(@args);
	my $len = scalar(@args);

	if($flag eq "-l"){
		my $output = "List of replacement rules:\n";
		while(my($key,$val) = each(%rules)){
			my $text = $val->{'text'};
			my $replace = $val->{'replace'};
			$text = escape_text($text);
			$replace = escape_text($replace);
			$output .= "\t$key: $text ==> $replace\n" if($text);
		}
		$conv->write("", $output, Purple::Conversation::Flags::NO_LOG | Purple::Conversation::Flags::RAW | Purple::Conversation::Flags::NO_LINKIFY, 0);
		return Purple::Cmd::Return::OK;
	}

	if($flag eq "-d"){
		remove_rules(split(/ /,@args[0]));
		return Purple::Cmd::Return::OK;
	}

	if($flag eq "-g"){
		prefs_info_cb();
		return Purple::Cmd::Return::OK;
	}

	if($flag ne "-a"){
		return Purple::Cmd::Return::FAILED;
	}

	@args = split(/ /,$args[0]);
	my $name = shift(@args);
	my @ar = split(/==>/, join(" ", @args));
	if (scalar(@ar) != 2) {
		return Purple::Cmd::Return::FAILED;
	}
	my $text = $ar[0];
	my $replace = $ar[1];
	$text =~ s/^\s*|\s*$//g;
	$replace =~ s/^\s*|\s*$//g;

	$rules{$name}{'text'} = $text;
	$rules{$name}{'replace'} = $replace;

	Purple::Prefs::add_none("/plugins/core/rx/rules/$name");
	Purple::Prefs::add_string("/plugins/core/rx/rules/$name/text", $text);
	Purple::Prefs::add_string("/plugins/core/rx/rules/$name/replace", $replace);
	Purple::Prefs::set_string("/plugins/core/rx/rules/$name/text", $text);
	Purple::Prefs::set_string("/plugins/core/rx/rules/$name/replace", $replace);

	push(@names, $name);
	save_rules();

	return Purple::Cmd::Return::OK;
}

sub replace_stuff {
	my $msg = shift;
	foreach (@names){
		my $text = $rules{$_}{'text'};
		my $replace = $rules{$_}{'replace'};
		next if($text eq "");

		$text =~ s/\//\\\//g;
		$replace =~ s/\//\\\//g;
		$replace =~ s/\$0/\$\&/g;

		eval("\$msg =~ s/$text/$replace/ig;");
	}
	return $msg;
}

sub sending_msg {
	my ($account, $sender, @message) = @_;
	$_[2] = replace_stuff($message[0]);
	return 0;
}

sub writing_msg {
	my ($account, $sender, @message, $conv, $flag, $data) = @_;
	if ($flag & (Purple::Conversation::Flags::SEND | Purple::Conversation::Flags::RECV)) {
		$_[2] = replace_stuff(@message[0]);
	}else{
		# Other
	}
	return 0;
}

sub plugin_unload {
	my $plugin = shift;
	&dbmsg("plugin_unload() - Advanced ReplaceX Plugin in Perl unloaded.");
	if($windowtopreplace){
		$windowtopreplace->destroy;
	}
}

sub plugin_load {
	my $plugin = shift;
	&dbmsg("plugin_load() - Advanced ReplaceX Plugin in Perl loaded.");
	my $help = "Manage text replacement rules with perl-regex support.\n
EXAMPLES:
'/rx -a gf-trac gf#([0-9]+) ==> &lt;a href=\"http://plugins.guifications.org/trac/ticket/\$1\">\$\&&lt;/a>' : adds (or replaces) a replacement rule named 'gf-trac'.
'/rx -d gf-trac' : removes the replacement rule.

'/rx -l' : lists all the replacement rules.
'/rx -g' : lists all the replacement rules with search and edit in gtk2 window as gui.
";

	load_prefs();
	Purple::Cmd::register($plugin, "rx", "ws", Purple::Cmd::Priority::DEFAULT, Purple::Cmd::Flag::IM | Purple::Cmd::Flag::CHAT | Purple::Cmd::Flag::ALLOW_WRONG_ARGS, 0, \&rx_cmd_cb, "$help", $plugin);

	my $conv = Purple::Conversations::get_handle();
	Purple::Signal::connect($conv, "writing-im-msg", $plugin, \&writing_msg, $plugin);
	Purple::Signal::connect($conv, "writing-chat-msg", $plugin, \&writing_msg, $plugin);
	Purple::Signal::connect($conv, "sending-im-msg", $plugin, \&sending_msg, $plugin);
	Purple::Signal::connect($conv, "sending-chat-msg", $plugin, \&sending_msg, $plugin);
}

sub init_prefs {
	if(!Purple::Prefs::exists("/plugins/core/rx")){
		Purple::Prefs::add_none("/plugins/core/rx");
		Purple::Prefs::add_none("/plugins/core/rx/rules");
		my @ar = ();
		Purple::Prefs::add_string_list("/plugins/core/rx/names", \@ar);
	}
}

sub load_prefs {
	init_prefs();
	my @ar = Purple::Prefs::get_string_list("/plugins/core/rx/names");
	push(@names, $_) foreach (@ar);
	read_rules();
}

sub read_rules {
	foreach (@names){
		next unless($_);
		my $text = Purple::Prefs::get_string("/plugins/core/rx/rules/" . $_ . "/text");
		my $replace = Purple::Prefs::get_string("/plugins/core/rx/rules/" . $_ . "/replace");
		$rules{$_}{'text'} = $text;
		$rules{$_}{'replace'} = $replace;
	}
}

sub searchdata {
	my @searchdata;

	foreach (keys %rules){
		next unless($rules{$_}{'text'});
		my %data = (
			text => $rules{$_}{'text'},
			replace => $rules{$_}{'replace'},
			name => $_,
		);
		push(@searchdata,\%data);
	}
	return \@searchdata;
}

sub create_completion_model {
	my $store = Gtk2::ListStore->new (Glib::String::);

	my %newset;
	my $data = &searchdata();
	foreach my $selectdata (@$data){
		$store->set($store->append, 0, $$selectdata{'text'}) if($$selectdata{'text'});
		$store->set($store->append, 0, $$selectdata{'name'}) if($$selectdata{'name'});
	}
	return $store;
}

sub mydatetime {
	my($mytime) = @_;
	return "no data" unless($mytime);
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mytime);
	$mon++;
	$hour = "0$hour" if($hour < 10);
	$min = "0$min" if($min < 10);
	$sec = "0$sec" if($sec < 10);
	$year += 1900;
	$mon = "0$mon" if($mon < 10);
	$mday = "0$mday" if($mday < 10);
	return("$mday\.$mon\.$year\/$hour:$min");
}

sub find_and_set_label_in {
	my($widget, $text) = @_;
	if($widget->isa (Gtk2::Container::)){
		$widget->foreach (sub { find_and_set_label_in ($_[0], $text); });
	}elsif($widget->isa (Gtk2::Label::)){
		$widget->set_text ($text);
	}
}

sub create_model4 {
	my $store = Gtk2::ListStore->new (
		'Glib::String',
		'Glib::String',
		'Glib::String'
	);

	foreach my $d (@searchdata) {
		my $iter = $store->append;
		$store->set ($iter,
		   0, $d->{name},
		   1, $d->{text},
		   2, $d->{replace}
		);
	}
	return $store;
}

sub add_columns4 {
	my $treeview = shift;
	my $model = $treeview->get_model;
	my $sel = $treeview->get_selection();
	$sel->signal_connect ('changed' => sub { cell_clicked($sel) }, $model);

	my $renderer = Gtk2::CellRendererText->new;
	$renderer->set_property('editable', 0);
	my $column = Gtk2::TreeViewColumn->new_with_attributes ("Name",
						       $renderer,
						       text => 0);
	$column->set_resizable(1);
	$column->set_sort_column_id(0);
	$treeview->append_column ($column);

	my $renderer = Gtk2::CellRendererText->new;
	$renderer->signal_connect (edited => sub {
			my ($cell, $text_path, $new_text, $model) = @_;
			my $path = Gtk2::TreePath->new_from_string ($text_path);
			my $iter = $model->get_iter ($path);

			Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/text", $new_text);
			Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/replace", $model->get_value($iter, 2));
			load_prefs();

			$model->set ($iter, 1, $new_text);
		}, $model);
	$renderer->set_property('editable', 1);
	my $column = Gtk2::TreeViewColumn->new_with_attributes ("Text",
						       $renderer,
						       text => 1);
	$column->set_resizable(1);
	$column->set_sort_column_id(1);
	$treeview->append_column ($column);

	my $renderer = Gtk2::CellRendererText->new;
	$renderer->signal_connect (edited => sub {
			my ($cell, $text_path, $new_text, $model) = @_;
			my $path = Gtk2::TreePath->new_from_string($text_path);
			my $iter = $model->get_iter($path);

			Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/text", $model->get_value($iter, 1));
			Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/replace", $new_text);
			load_prefs();

			$model->set ($iter, 2, $new_text);
		}, $model);
	$renderer->set_property('editable', 1);

	my $column = Gtk2::TreeViewColumn->new_with_attributes ("Replace",
						       $renderer,
						       text => 2);
	$column->set_resizable(1);
	$column->set_sort_column_id(2);
	$treeview->append_column ($column);
}

sub cell_clicked {
	my($TreeSelection) = @_;
	my($model, $iter) = $TreeSelection->get_selected();

	if($iter){
		#Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/text", $model->get_value($iter, 1));
		#Purple::Prefs::set_string("/plugins/core/rx/rules/".$model->get_value($iter, 0)."/replace", $model->get_value($iter, 2));
		#load_prefs();

		my $data1 = $model->get($iter,0);
		my $data2 = $model->get($iter,1);
		my $data3 = $model->get($iter,2);
		my $pos = $model->get_path($iter)->get_indices;
	}
}

sub dbmsg {
	my $msg = shift;
	Purple::Debug::misc("replacex", $msg."\n");
}