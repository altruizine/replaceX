$MODULE_NAME = "replaceX";

use Purple;

my @names = ();
my %rules = ();

%PLUGIN_INFO = (
	perl_api_version => 2,
	name => "$MODULE_NAME",
	version => "0.1",
	summary =>     "Text replacement plugin, with regex support.",
	description => "Text replacement plugin, with regex support. See '/help rx' for more information.",
	author => "Sadrul Habib Chowdhury <sadrul\@pidgin.im> and contributors",
	url => "https://github.com/altruizine/replaceX",

	load => "plugin_load",
);

sub escape_text
{
	my $text = shift;
	$text =~ s/&/&amp/g;
	$text =~ s/</&lt;/g;
	return $text;
}

sub save_rules
{
	local @ar = ();
	while (my($k, $v) = each(%rules)) {
		push(@ar, $k) if($k);
	}
	push(@ar, "");
	Purple::Prefs::set_string_list("/plugins/core/rx/names", \@ar);
	load_prefs();
}

sub list_rules
{
}

sub remove_rules
{
	my @r = shift();
	foreach (@r) {
		Purple::Prefs::set_string("/plugins/core/rx/rules/$_/text", '');
		Purple::Prefs::set_string("/plugins/core/rx/rules/$_/replace", '');
		Purple::Prefs::remove("/plugins/core/rx/rules/$_");
		delete $rules{$_};
	}
	save_rules();
}

sub rx_cmd_cb
{
	my ($conv, $cmd, $data, @args) = @_;
	my $flag = shift(@args);
	my $len = scalar(@args);

	if ($flag eq "-l") {
		my $output = "List of replacement rules:\n";
		while (my ($key, $val) = each(%rules)) {
			my $text = $val->{'text'};
			my $replace = $val->{'replace'};
			$text = escape_text($text);
			$replace = escape_text($replace);
			$output .= "\t$key: $text ==> $replace\n" if($text);
		}
		$conv->write("", $output,
				Purple::Conversation::Flags::NO_LOG | Purple::Conversation::Flags::RAW | Purple::Conversation::Flags::NO_LINKIFY,
				0);
		return Purple::Cmd::Return::OK;
	}

	if ($flag eq "-d") {
		remove_rules(split(/ /, @args[0]));
		return Purple::Cmd::Return::OK;
	}

	if ($flag ne "-a") {
		return Purple::Cmd::Return::FAILED;
	}

	@args = split(/ /, $args[0]);
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

sub replace_stuff
{
	# XXX: do something about HTML messages so that the tags are not replaced.
	my $msg = shift;
	foreach (@names) {
		my $text = $rules{$_}{'text'};
		my $replace = $rules{$_}{'replace'};

		next if ($text eq "");

		$text =~ s/\//\\\//g;
		$replace =~ s/\//\\\//g;
		$replace =~ s/\$0/\$\&/g;

		eval("\$msg =~ s/$text/$replace/ig;");
	}
	return $msg;
}

sub sending_im_msg
{
#	my ($account, $sender, @message) = @_;
#	$_[2] = replace_stuff($message[0]);
	return 0;
}

sub sending_chat_msg
{
#	my ($account, @message) = @_;
#	$_[1] = replace_stuff($message[0]);
	return 0;
}

sub writing_msg
{
	my ($account, $sender, @message, $conv, $flag, $data) = @_;
	if ($flag & (Purple::Conversation::Flags::SEND | Purple::Conversation::Flags::RECV)) {
		$_[2] = replace_stuff(@message[0]);
	} else {
		# Other
	}
	return 0;
}

sub receiving_msg
{
	my ($account, $sender, @message, $conv, @flag, $data) = @_;
	$_[2] = replace_stuff($message[0]);
	return 0;
}

sub plugin_load
{
	my $plugin = shift;
	my $help = "Manage text replacement rules with perl-regex support.\n
EXAMPLES:
'/rx -a gf-trac gf#([0-9]+) ==> &lt;a href=\"http://plugins.guifications.org/trac/ticket/\$1\">\$\&&lt;/a>' : adds (or replaces) a replacement rule named 'gf-trac'.
'/rx -d gf-trac' : removes the replacement rule.
'/rx -l' : lists all the replacement rules.
";

	load_prefs();

	Purple::Cmd::register($plugin, "rx", "ws", Purple::Cmd::Priority::DEFAULT,
			Purple::Cmd::Flag::IM | Purple::Cmd::Flag::CHAT | Purple::Cmd::Flag::ALLOW_WRONG_ARGS,
			0, \&rx_cmd_cb, "$help", $plugin);

	my $conv = Purple::Conversations::get_handle();
	Purple::Signal::connect($conv, "writing-im-msg", $plugin,
			\&writing_msg, $plugin);
	Purple::Signal::connect($conv, "writing-chat-msg", $plugin,
			\&writing_msg, $plugin);
	Purple::Signal::connect($conv, "sending-im-msg", $plugin,
			\&sending_im_msg, $plugin);
	Purple::Signal::connect($conv, "sending-chat-msg", $plugin,
			\&sending_chat_msg, $plugin);
	Purple::Signal::connect($conv, "receiving-im-msg", $plugin,
			\&receiving_msg, $plugin);
	Purple::Signal::connect($conv, "receiving-chat-msg", $plugin,
			\&receiving_msg, $plugin);
}

sub init_prefs
{
	if (!Purple::Prefs::exists("/plugins/core/rx")) {
		Purple::Prefs::add_none("/plugins/core/rx");
		Purple::Prefs::add_none("/plugins/core/rx/rules");
		my @ar = ();
		Purple::Prefs::add_string_list("/plugins/core/rx/names", \@ar);
	}
}

sub load_prefs
{
	init_prefs();
	my @ar = Purple::Prefs::get_string_list("/plugins/core/rx/names");
	push(@names, $_) foreach (@ar);
	read_rules();
}

sub read_rules
{
	foreach (@names) {
		next unless($_);
		my $text = Purple::Prefs::get_string("/plugins/core/rx/rules/" . $_ . "/text");
		my $replace = Purple::Prefs::get_string("/plugins/core/rx/rules/" . $_ . "/replace");
		$rules{$_}{'text'} = $text;
		$rules{$_}{'replace'} = $replace;
	}
}

