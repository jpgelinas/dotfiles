use strict;
use warnings;
use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Daniel Andersson',
    contact     => 'sskraep@gmail.com',
    name        => 'hilightnotify',
    description => 'Executes command on hilight and dehilight',
    license     => 'GNU GPL v2 or later',
    url     => 'http://510x.se/notes',
    changed     => '2012-02-12',
);

Irssi::command_bind('help', sub { if ($_[0] =~ '^hilightnotify ?') {&sig_help; Irssi::signal_stop;} });
sub sig_help
{
    my $usage = <<USAGEEND;
HILIGHTNOTIFY  -  Run external command when hilight status is set or removed.

USAGE
    Load script and customize settings.

    /dehilight
        Run dehilight command.

REQUIRES
    External scripts that do something useful.

SETTINGS
    hilight_run_cmd_when_away <bool>
        Should the command run when you are in away status? (*)

    hilight_cmd_on_hilight
        Command to run when hilighted.

    hilight_cmd_on_dehilight
        Command to run when hilight stops. (**)

EXAMPLE
    I use a Perl script that starts a blinking tray icon. When the icon is
    clicked, or when I issue a WM keyboard shortcut, the same command as
    'hilight_cmd_on_dehilight' is run, which
        1. stops the tray icon
        2. activates the available tmux session (or attaches a new one if one
           doesn't exist)
    Thus, after being hilighted, I can click he icon or press Mod4+i to switch
    to the correct virtual desktop and bring irssi to the front.

    My tray icon script can be found at
    <http://510x.se/hg/program/trayblinker>. My tmux session activator can be
    found at <http://510x.se/hg/program/tmux-irssi>.

NOTES
    (*):
        By choice, the dehilight command is always run even if away status is
        set. This simply makes sense during usage.

    (**):
        By choice, I don't run the dehilight command if I'm currently in the
        irssi window where I'm being hilighted, and thus is "automatically
        dehilighted". Since my tmux session always runs, just because an irssi
        window is active it doesn't mean that I'm looking at it, and I want to
        be notified in most cases. If I'm looking at it, I can just send
        '/dehilight', issue Mod4+i, or click the tray icon to make it stop.

CREDITS
    I looked at <http://scripts.irssi.org/scripts/hilightwin.pl> to get the
    trigger condition for hilight status.

    I got help from Bazerka in #irssi\@IRCnet to emulate a dehilight trigger.
USAGEEND
   Irssi::print($usage, MSGLEVEL_CLIENTCRAP);
}

### Start external settings handling
Irssi::settings_add_bool('hilightnotify', 'hilight_run_cmd_when_away', 1);
Irssi::settings_add_str ('hilightnotify', 'hilight_cmd_on_hilight', '/home/jp/src/notify-desktop/bin/notify-desktop "irssi" "New IRSSI message!" >> /dev/null');
Irssi::settings_add_str ('hilightnotify', 'hilight_cmd_on_dehilight', '/home/jp/src/notify-desktop/bin/notify-desktop "irssi" "New IRSSI message!" >> /dev/null');

my $hilight_run_cmd_when_away;
my $hilight_cmd_on_hilight;
my $hilight_cmd_on_dehilight;
sub load_settings
{
   $hilight_run_cmd_when_away = Irssi::settings_get_bool('hilight_run_cmd_when_away');
   $hilight_cmd_on_hilight =    Irssi::settings_get_str ('hilight_cmd_on_hilight');
   $hilight_cmd_on_dehilight =  Irssi::settings_get_str ('hilight_cmd_on_dehilight');
}
&load_settings;
Irssi::signal_add('setup changed', \&sig_setup_changed);
sub sig_setup_changed {&load_settings}
### End external settings handling

### Start signal handling

# Check if hilight status is triggered on the printed text. If so: &hilight.
sub sig_print_text
{
   my ($dest, $text, $stripped) = @_;
   my $server = $dest->{server};

   &hilight if (
       # If here or notifications are wanted anyway
       (!$server->{usermode_away} || $hilight_run_cmd_when_away)
       # If hilighted anywhere (including current window)
       && (
           ($dest->{level} & (MSGLEVEL_HILIGHT|MSGLEVEL_MSGS))
           && ($dest->{level} & MSGLEVEL_NOHILIGHT) == 0
       )
   );
}

# Check if you just switched to a window that _was_ hilighted. This indicates
# that you are present at the terminal and that you have read the message, so
# let's &dehilight.
sub sig_window_activity
{
    my ($dest, $old_level) = @_;
    # data_level 0 == DATA_LEVEL_NONE
    # data_level 1 == DATA_LEVEL_TEXT
    # data_level 2 == DATA_LEVEL_MSG
    # data_level 3 == DATA_LEVEL_HILIGHT
    &dehilight if ($old_level == 3 && $dest->{data_level} < $old_level)
}

# If you send a message, you are certainly in the window -> &dehilight.
# FEATURE: this enables you to dehilight by just pressing Enter! You'll trigger
# send_text, but you won't actually send a message.
sub sig_send_text
{
    # Running &dehilight unconditionally is a dealbreaker if you run
    # another script that sends text autonomously. Add conditions if
    # needed.
    &dehilight;
}
### End signal handling

sub run_cmd   {
    if ((my $pid = fork())) {Irssi::pidwait_add($pid)}
    elsif ($pid == 0) {exec(@_)}
    else {Irssi::print('Fork failed')}
}
sub hilight   {run_cmd($hilight_cmd_on_hilight)}
sub dehilight {run_cmd($hilight_cmd_on_dehilight)}

Irssi::signal_add('print text', \&sig_print_text);
Irssi::signal_add('window activity', \&sig_window_activity);
Irssi::signal_add('send text', \&sig_send_text);
##Two subs for debugging purposes:
#Irssi::command_bind('hl', \&hilight);
#Irssi::command_bind('dehl', \&dehilight);
