#!/usr/bin/perl
use strict;
use Net::OSCAR;

##
# Bot Settings
# This is the only area users should change!
##
my $info = "CSH Mass Message Bot v3.0\n --\nType \'help\' for more info!\n";

# Create the OSCAR object
my $aim = Net::OSCAR->new();

# Set the callbacks
$aim->set_callback_signon_done( \&signon_done );
$aim->set_callback_im_in( \&im_in );
$aim->set_callback_error( \&error );
$aim->set_callback_rate_alert( \&rate_alert );

# Call the login routine
login();

# The main loop
while ( 1 ) {
	$aim->do_one_loop();
}

##
# This callback is run when the bot successfuly logs in.
# This function should manage certain settings.
##
sub signon_done {
	$aim->set_info( $info );
	$aim->commit_buddylist;
	print "Connected!\n";
}

##
# Promp the user for a screen name and a password, then
# authenticate with the server
##
sub login {
	print "Screen Name: ";
	my $sn = <STDIN>;

	print "Password: ";
	`stty -echo`;
	my $pw = <STDIN>;
	`stty echo`;

	print "\n\nConnecting... \n";

	# Get rid of newlines
	chomp $sn;
	chomp $pw;

	$aim->signon( $sn, $pw );
}

##
# This callback is called when the bot recieves an instant message
# most of the work is done in here.
##
sub im_in {
	my ( $oscar, $from, $msg, $away ) = @_;

	# Strip HTML from the message
	$msg =~ s/<[^>]+>//g;

	print "$from: $msg\n";

	# Parse the commands
	my @cmd = split(/ /, $msg);

	# Get all of the text after the first space
	my $args = $msg;
	$args =~ s/[^ ]* (.*)/$1/;

	##
	# Display the help message
	##
	if ( $cmd[0] eq "help" ) {
		$aim->send_im( $from, 
			"\n<hr><b>*** Help Menu *** </b>\n" .
			"<b>help</b> - this menu.\n" .
			"<b>list</b> - list groups\n" .
			"<b>list group</b> - list users in group.\n" .
			"<b>create group</b> - creates a new group.\n" . 
			"<b>[sub]scribe group</b> - subscribe to group.\n" .
			"<b>[unsub]scribe group</b> - unsub from group.\n" .
			"<b>msg group:text</b> - send message to group." .
			"<hr>" );
	##
	# List all groups, or all members of a specific group
	##
	} elsif ( $cmd[0] eq "list" ) {
		if ( scalar( @cmd ) > 1 ) { # List for an individual group
			if ( group_exists( $args ) ) {
				my @userlist = $aim->buddies( $args );
				my $text = "\n<b>* List of users in $args *</b><hr>";
				foreach my $user( @userlist ) {
					$text .= "$user\n";
				}
				$aim->send_im( $from, $text . "<hr>" );
			} else {
				$aim->send_im( $from, "Error: Invalid group name" );
			}
		} else { # List all of the groups
			my @grouplist = $aim->groups;
			my $text = "\n<b>* Group Listing * </b><hr>";
			foreach my $group( @grouplist ) {
				$text .= "$group\n";
			}
			$aim->send_im($from, $text . "<hr>");
		}
	##
	# Creating a new group
	##
	} elsif ( $cmd[0] eq "create" ) {
		if ( scalar(@cmd) > 1 ) {
			if ( group_exists( $args ) ) {
				$aim->send_im( $from,
					"Error:  Group already exists.");
			} elsif ( $args !~ /^[0-9A-Za-z ]+$/ || 
				 length( $cmd[1] ) > 25 ) {
				 $aim->send_im( $from, 
				 		"Error: Invalid group name" );
			} else {
				$aim->add_buddy( $args, $from );
				$aim->send_im( $from, "Group $args created." );
				$aim->commit_buddylist;
			}
		} else {
			$aim->send_im( $from, "Error:  Invalid Syntax" );
		}
	##
	# Subscribing to a group
	##
	} elsif ( $cmd[0] eq "sub" || $cmd[0] eq "subscribe" ) {
		if ( group_exists( $args ) ) {
			$aim->add_buddy( $args, $from );
			$aim->commit_buddylist;
			$aim->send_im( $from, "Successfully added $from to " .
				"the $args group." );
		} else {
			$aim->send_im( $from, "Error: Group doesn't exist" );
		}
	##
	# Unsubscribing from a group
	##
	} elsif ( $cmd[0] eq "unsub" || $cmd[0] eq "unsubscribe" ) {
		if ( group_exists( $args ) ) {
			$aim->remove_buddy( $args, $from );
			$aim->commit_buddylist;
			$aim->send_im( $from, "Successfully removed $from " .
				      "from the $args group." );
		} else {
			$aim->send_im( $from, "Error: Group doesn't exist" );
		}
	##
	# Sending a message to an entire group
	##
	} elsif ( $cmd[0] eq "msg" ) {
		if ( scalar( @cmd ) > 1 ) {
			my @groupmsg = split(/:/, $args );
			if ( group_exists( $groupmsg[0] ) ) {
				my @users = $aim->buddies( $groupmsg[0] );
				my $message = $args;
				$message =~ s/[^:]*:(.*)/$1/;
				foreach my $user ( @users ) {
					my $taint = $aim->findbuddy( $user );
					print "sending $message to $user\n";
					$aim->send_im( $user, "\n<b>* Message from $from to " .
										"$groupmsg[0] *</b><hr>$message");
					sleep( 3 ); # Sleep n seconds between messages
				}
			} else {
				$aim->send_im( $from, "Error: Invalid group" );
			}
		} else {
			$aim->send_im( $from, "Error: Invalid syntax" );
		}
	}	
}

##
# Check if a group exists.  Return a non-zero value if found
##
sub group_exists {
	my $found = 0;
	my ( $gname ) = @_;
	my @grouplist = $aim->groups;
	foreach my $group( @grouplist ) {
		if ($group eq $gname) { $found++ }
	}
	return $found;
}

##
# Check if a user exists in a specific group.
# Return a non zero value if found.
##
sub user_exists {
	my $found = 0;
	my ( $gname, $user ) = @_;
	my @buddies = $aim->buddies( $gname );
	foreach my $buddy( @buddies ) {
		if ( $buddy eq $user ) { $found++ }
	}
	return $found;
}

##
# Rate alert callback
# This will get called alot when sending out messages
# to semi-large groups.  We only have to worry when the
# worrisome bit is set.  If it is, then sleep for a bit.
##
sub rate_alert {
	my ( $oscar, $level, $clear, $window, $worrisome ) = @_;
	if ( $worrisome ne 0 ) {
		print "Exceeded rate limit... sleeping\n";
		sleep( 5 );
	}
}

##
# Error callback... if called, then bail.
##
sub error {
	my ( $oscar, $conn, $error, $desc, $fatal ) = @_;
	print STDERR "Error: $desc\n";
}
