#!/usr/bin/perl

###############
#
# runner.pl - A bot designed to automate CX package delivery in the MUD
#             Ancient Anguish.
#
###############
use strict;
use warnings;

use Config::IniFiles;
use Net::Telnet;
use Switch;

if( -e "runner.lock" ) {
   print "Bot is already running!.\n";
   exit(0);
}

open TEMP, ">runner.lock";
print TEMP $$;
close TEMP;

$| = 1;
my $conf_file = 'runner.conf';
my $state     = "";
my $loc       = "";
my $telnet    = "";
my $start     = "";
my $hold      = "";

my $ini        = Config::IniFiles->new( -file => $conf_file );
my $user       = $ini->val('Account', 'user');
my $passwd     = $ini->val('Account', 'password');
my $player     = $ini->val('Account', 'player');
my $path_file  = $ini->val('Files', 'path');
my $match_file = $ini->val('Files', 'matches');
my $cmd_file   = $ini->val('Files', 'cmd');
my $log_file   = $ini->val('Files', 'log');
my $catch_file = $ini->val('Files', 'catch');
my $broker     = $ini->val('Broker', 'name');
my $brokerage  = $ini->val('Broker', 'location');

$SIG{'INT'} = \&quit;
$SIG{'TERM'} = \&quit;

local $/=undef;
open TEMP, "< $path_file";
my $blurb = <TEMP>;
my %path;
eval('%path = (' . $blurb . ');');
close TEMP;

open TEMP, "<$match_file";
$blurb = <TEMP>;
my %matches;
eval('%matches = (' . $blurb . ');');
close TEMP;

open TEMP, "<$cmd_file" or die $!;
$blurb = <TEMP>;
my %cmds;
eval('%cmds = (' . $blurb . ');');
close TEMP;

my $counter = 0;
while( 1 ) {
   $telnet = new_conn();
   $start = time;
   $hold = 8;

   while( !establish_location() ) {
      send_cmd("quit");
      $telnet->close();
      $telnet = new_conn();
      sleep 3;
   }

   check_alive();
   move($brokerage);

   my $gap_counter = 0;
   while( $state ne "QUIT" ) {
      my $start = time;
      waiting();
      my $gap = time - $start;
      if( $gap < 1 ) {
         $gap_counter++;
      } else {
         $gap_counter = 0;
      }
      if( $gap_counter > 5 ) {
         $state = "QUIT";
      }
   }
   send_cmd("quit");
   $telnet->close;

   if( $counter < 5 ) {
      sleep 3000;
   } else {
      $counter = 0;
      sleep 22152;
   }
}

###############
#
# establish_location - Establishes the current location of the user
#
# params
#  none
#
# returns
#  "1" if the bot is in a known location
#  "0" if the bot is in an unknown location
#
###############
sub establish_location {

   my @lines = send_cmd("look");
   $state = "WAITING";
   foreach my $s (@lines) {
      if( $s =~ m/You are in the Commodities Exchange/ ) {
         $loc = "CX";
         return 1;
      } elsif( $s =~ m/common room of the Ancient Inn of Tantallon/ ) {
         $loc = "ANCIENTINN";
         return 1;
      }
   }
   $state = "STALLED";
   $loc = "UNKNOWN";
   return 0;

}

###############
#
# waiting - Forces the bot to wait for a trigger statement that it will act on
#
# params
#  none
#
###############
sub waiting {

   my $lou   = "$broker announces: Delivery of .* to (.*)";
   my $tell  = "$player tells you: (.*)";
   my $regex = "/$lou|$tell/";

   my ($prematch, $match) = $telnet->waitfor($regex);
   if( $match ) {
      if( $match =~ m/$lou/ ) {
         if( $state eq "WAITING" ) {
            accept_package($1);
         }
      } elsif( $match =~ m/$tell/ ) {
         command($1);
      }
   } else {
      send_cmd('time');
   }

}

###############
#
# move - Makes the bot move from his current location to the given location
#
# params
#  place - the code for the place to move to
#
###############
sub move {

   my $place = shift;
   if( $loc ne $place ) {
      my $temp = $state;
      $state = "TRANSIT";
      _rgo($loc);
      _go($place);
      $loc = $place;
      $state = $temp;
   }

}

###############
#
# _go - issues a series of directional commands to the MUD to move the bot to 
#       the given location, most of the stored commands are from the 
#       crossroads in Tantallon to the location in question.
#
# params
#  place - the code for the location the bot is to go to
#
###############
sub _go {

   my $place = shift;
   if( exists $path{$place} ) {
      my @arr = @{$path{$place}};
      foreach my $step (@arr) {
         send_cmd($step);
         sleep 1;
      }
   }

}

###############
#
# _rgo - issues a series of directional commands to the MUD to move the bot in
#        reverse order from the given location, most of the stored commands are
#        from the crossroads in Tantallon to the location in question.
#
###############
sub _rgo {

   my $place = shift;
   my @arr = reverse(@{$path{$place}});
   foreach my $step (@arr) {
      switch( $step ) {
         case 'n' {
            $step = 's';
         }
         case 's' {
            $step = 'n';
         }
         case 'e' {
            $step = 'w';
         }
         case 'w' {
            $step = 'e';
         }
         case 'nw' {
            $step = 'se';
         }
         case 'ne' {
            $step = 'sw';
         }
         case 'sw' {
            $step = 'ne';
         }
         case 'se' {
            $step = 'nw';
         }
         case 'u' {
            $step = 'd';
         }
         case 'd' {
            $step = 'u';
         }
         case 'walk' {
            $step = 'e';
         }
      }
      if( $step =~ m/enter/ ) {
         $step = "out";
      }
      send_cmd($step);
      sleep 1;
   }

}

###############
#
# new_conn - create a new connection to the MUD
#
# params
#  none
#
# returns
#  the connection to the MUD as a resource
#
###############
sub new_conn {

   my $telnet = new Net::Telnet( Timeout=>300, Errmode=>'return' );
   $telnet->open(Host=>'ancient.anguish.org', Port=>2222);
   $telnet->waitfor('/What is your name: $/i');
   $telnet->print($user);
   $telnet->waitfor('/password: $/i');
   $telnet->print($passwd);
   return $telnet;

}

###############
#
# accept_package - accepts a package from the CX
#
# params
#  text - the text received from the MUD
#
###############
sub accept_package {

   my $text = shift;
   if( exists $matches{$text} ) {
      my @lines = send_cmd('accept');
      foreach my $line (@lines) {
         if( $line =~ m/$broker says: The job is yours, kid, make me look / ) {
            deliver($matches{$text});
            return;
         } elsif( $line =~ m/$broker says: Sorry, kid, you've already made near three thousand coins today/) {
            deposit();
            advance();
            $state = "QUIT";
            return;
         } elsif( $line =~ m/$broker says: Kid, I don't think you can carry this package,/ ) {
            deposit();
            return;
         }
      }
   } else {
      open LOG, ">> $catch_file";
      print LOG $text . "\n";
      close LOG;
   }

}

###############
#
# deliver - Issues commands to deliver the package
#
# params
#  place - the code for the location to deliver the package to
#
###############
sub deliver {

   my $place = shift;
   move($place);
   my $temp = $state;
   $state = "DELIVERING";
   my @lines = send_cmd('deliver');
   foreach my $line (@lines) {
      if( $line =~ m/You give the package to / ) {
         $state = $temp;
         move($brokerage);
         sleep 5;
         return;
      }
   }
   $state = "STALLED";
   send_cmd('tell ' . $player . ' help! ' . $loc);

}

###############
#
# command - Issue a command to the MUD
#
# params
#  cmd - the command to be issued
#
###############
sub command {

   my $cmd = shift;
   if( exists $cmds{$cmd} ) {
      if( $cmd eq "resume" ) {
         $state = "WAITING";
         $loc = "CX";
         return;
      } elsif( $cmd eq "state" ) {
         send_cmd("tell $player $state");
      } elsif( $cmd eq "location" ) {
         send_cmd("tell $player $loc");
      } elsif( $cmd eq "renew" ) {
         my $old_loc = $loc;
         move("TANTALLONBANK");
         send_cmd("withdraw 6000");
         send_cmd($cmds{$cmd});
         send_cmd("deposit all");
         move($old_loc);
      } else {
         $state = "STALLED";
         $loc = "UNKNOWN";
         send_cmd($cmds{$cmd});
      }
   } else {
      send_cmd("tell moghedien I don't understand");
   }
   return;

}

###############
#
# deposit - deposit all money in the bank
#
###############
sub deposit {
   
   my $temp = $loc;
   move("TANTALLONBANK");
   send_cmd('deposit all');
   move($temp);

}

###############
#
# advance - advance the bots strength and level as far as possible
#
###############
sub advance {

   my $temp = $loc;
   move("ADVENTURERS");
   my $att = " strength";
   while( 1 ) {
      my @lines = send_cmd("advance" . $att);
      if( $att eq "" ) {
         $att = " strength";
      }
      foreach my $line (@lines) {
         if( $line =~ m/You must advance your level first./ ) {
            $att = "";
            last;
         } elsif( $line =~ m/You don't have enough experience./ ) {
            return;
         } elsif( $line =~ m/You need another \d+ experience points./ ) {
            return;
         } elsif( $line =~ m/You are not a member of this class./ ) {
            return;
         }
      }
      sleep 2;
   }
   move($temp);
}

###############
#
# send_cmd - sends a command to the MUD and logs it to a log file
#
# params
#  cmd - the command to send
#
# returns
#  an array containing the response text (line-by-line) from the MUD
#
###############
sub send_cmd {
   
   my $cmd = shift;
   my $now = time;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $year += 1900;
   $mon++;
   if( $mon < 10 ) {
      $mon = "0$mon";
   }
   if( $mday < 10 ) {
      $mday = "0$mday";
   }
   if( $hour < 10 ) {
      $hour = "0$hour";
   }
   if( $min < 10 ) {
      $min = "0$min";
   }
   if( $sec < 10 ) {
      $sec = "0$sec";
   }
   open LOG, ">> $log_file";
   print LOG "$year-$mon-$mday $hour:$min:$sec > $cmd\n";
   close LOG;
   my @lines = $telnet->cmd($cmd);
   return @lines;

}

###############
#
# check_alive - check if runner is alive
#
###############
sub check_alive {

   my @lines = send_cmd("look at $user");
   foreach my $l (@lines) {
      if( $l =~ m/This is the ghost of $user./i ) {
         move("VILLAGECHURCH");
         send_cmd("pray");
         return;
      }
   }

} # end of check_alive method

###############
#
# quit - issues the quit command to the MUD
#
###############
sub quit {
   
   send_cmd("quit");
   $telnet->close;
   unlink("runner.lock");
   exit(0);

}
