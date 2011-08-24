AA-CX-Bot is a bot written to interact with the Multi-User Dungeon called
[Ancient Anguish](http://anguish.org/).  In the game there is a mechanism for
players to earn in-game currency in which they deliver packages from a
location called the Commodities Exchange (or CX for short) to various
locations in the game world.  The packages are irrelevant to the game or
players and are automatically generated during the operating hours (6am-6pm
game time) of the CX.  Both the CX broker (named Lou or Pembrook) and the
package receiver are automatons of the game.

## Disclaimer ##

This is not intended for actual use in the game.  I developed this project to
see if I could automate the entire process and how successful it would be.  If
you get your account banned for ACTUALLY using this, don't blame me.

## Delivery Cycle ##

When run, this bot will autonomously move to the CX, accept packages, and
deliver packages for the duration it is running.  There are a few caveats to
this:

* A character may only earn 3000 coins per game day, in the event that the bot
* reaches this limit it will commence the logoff routine
* A character can only carry so much (based on the strength attribute), if the
* bot is not capable of carrying a package it has tried to accept, it will go
* to the bank, deposit all its money, and return to the CX to commence the
* delivery cycle.
* The CX is closed for half the game day.  If the bot enters the CX during
* closed hours, it will commence the logoff routine.
* If the broker refuses to give the bot a requested package, the bot will
* reset to the waiting state until a package is announced that they may
* successfully accept.

## Logoff Routine ##

When the bot is incapable of delivering any more packages for the game day,
the logoff routine will initiate.  From the CX, the bot will go to the bank
and deposit all of its money.  It will then proceed to the Adventurers Guild
where it will advance its strength attribute (making it more capable of
carrying things) as far as allowed.  If the bot reaches its strength cap for
that level, it will attempt to raise its level and continue raising strength.
At this point, the bot will check the time and disconnect from the game.
While disconnected from the game, it will continuously poll the system time
until the estimated in-game time is 6am at which point it will log in again.

## Time Delays ##

Because "botting" is against the rules in Ancient Anguish, several features
have been put into place in order to thwart attempts at identifying the bot as
a bot.

* Each movement is accompanied by a one second delay so that the bot does not
* move through the game suspiciously fast.
* When waiting for a package, there is a five second delay built into the
* initial acceptance state of the bot so that the bot doesn't accept every
* package suspiciously fast.  So when the bot first arrives at the CX, it will
* not accept packages for five seconds.
* If a tell is sent to the bot, it will occasionally respond with a random
* statement like "No hablo Ingles" or "I'm busy right now", etc.
* (TODO) Jitter - every so often the bot will "go the wrong direction" and
* have to correct itself.

## Remote Command ##

The user may issue commands from a different account (specified in the config
file) using the "tell" system in the game.  These commands may be customized
via the runner.command file.

* **follow** - Signals the bot to follow you.  Must be at the same location as
* the bot for this to work.
* **deliver** - Attempts to deliver the package at the current location.
* There is no check to ensure that the bot is at the correct location.
* **accept** - Attempts to accept a package.  Does not check to see if the bot
* is at the CX.
* **location** - Replies to the controlled character with its last reported
* location.
* **state** - Replies to the controlled character with its last reported
* state.
* (TODO) **resume** - Continue the previously interrupted delivery run.
* **withdraw** - Withdraw all money from the bank.  Assumes that the bot is
* currently in the bank.
* **deposit** - Deposit all money into the bank.  Assumes that the bot is
* currently in the bank.

## runner.conf ##
### Account ###
* **user** - The user account for the bot
* **password** - The associated password for the bot
* **player** - The name of the character that will issue remote commands to
* the bot

### Files ###
* **path** - The file holding an array of paths.  All paths assume a starting
* point of the Crossroads in Tantallon. (Default: runner.path)
* **matches** - The file holding an array of locations keyed on phrases used
* by the broker when announcing packages. (Default: runner.matches)
* **cmd** - The file containing an array of commands keyed on the phrases used
* by the remote character. (Default: runner.command)
* **log** - The file that the script outputs its log info to. (Default:
* runner.log)
* **catch** - When the bot doesn't recognize the phrase used when announcing a
* package, it will dump that phrase into this file. It is then the
* responsibility of the user to peruse these phrases to determine what
* location they should be associated with and manually add them to the matches
* and path files. (Default: runner.catch)
* (TODO)**lock** - The lock file used to establish whether the bot is running
* or not. (Default: runner.lock)

### Broker ###
* **name** - The name of the broker to be used by the bot, can be Lou or
* Pembrook. (Default: Lou)
* **location** - The location term (as specified in the path file) of the
* exchange being used, can be CX or PEMBROOK. (Default: CX)
