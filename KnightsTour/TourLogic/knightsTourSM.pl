#!/usr/bin/perl/

###########################################$
# This script will solve the knights tour #
###########################################

#### Data structures ####
# $board[][] is a two dimensional array that holds 0 or move number => knight has been there
# $xx = xposition on board
# $yy = yposition on board
# $last_move[] = array of last moves from this position (stored as 1-hot 8-bit vector)
# $possible[] = packed byte that represents all possible moves from that square
#    bit0 = up and to left (-1,+2), bit1 = up and to right (+1,+2)
#    bit2 = left and up (-2,+1), bit3 = left and down (-2,-1)
#    bit4 = down and left (-1,-2), bit 5 down and right (-2,+1)
#    bit6 = right and up (+2,+1), bit7 = right and down (+2,-1)
# $move_num = move number
# size of board is assumed 5x5

## set starting position
$x_start = 0;
$y_start = 0;

##########################################################
# Initialize move offsets from LSB to MSB. These are the #
# encodings of the 8 possible moves a knight can make.   #
# One-hot encoding, each bit of a byte represents a      #
# possible move (note indecies 1,2,4,8 are power of 2.   #
# The choice of the offset for each move choice is       #
# arbitrary.  In this encoding the LSB represents a move #
# of 1 in the x and +2 in the Y.  The MSB represents a   #
# move of +2 in the X and 1 in the Y.  In my verilog     #
# implementation I have functions xoff and yoff that can #
# return a 3-bit signed number given an input argument   #
# that is a 1-hot encoded move byte.                     #
##########################################################
$xoff{1} = 1; $yoff{1} = 2;
$xoff{2} = -1; $yoff{2} = 2;
$xoff{4} = -2; $yoff{4} = 1;
$xoff{8} = -2; $yoff{8} = -1;
$xoff{16} = -1; $yoff{16} = -2;
$xoff{32} = 1; $yoff{32} = -2;
$xoff{64} = 2; $yoff{64} = -1;
$xoff{128} = 2; $yoff{128} = 1;

####################
# initialize state #
####################
$state = "IDLE";	## {IDLE,INIT,POSSIBLE,MAKE_MOVE,BACKUP}
$go = 1;

while ($go) {
  ##############
  # IDLE State #
  ##############
  if ($state=~/IDLE/) {
	if ($go) {
		## zero out board array & move_num ##
        for ($x=0; $x<5; $x++) {
          for ($y=0; $y<5; $y++) {
            $board[$x][$y] = 0;			## A 0 indicates this board position not visited yet
          }
        }
        $move_num = 0;				## we have made no moves yet.
		$state = "INIT";		    ## Initialize first board position
	}
  }
  ##############
  # INIT State #
  ##############
  elsif ($state=~/INIT/) {
	$board[$x_start][$y_start] = 1;	## mark starting position as visited with non-zero
	$xx = $x_start;					## initialize location as starting position
	$yy = $y_start;
    $state = "POSSIBLE";		  
  }
  #######################################################################
  # POSSIBLE State (discover all possible moves from this new position) #
  #######################################################################
  elsif ($state=~/POSSIBLE/) {
    $poss_moves[$move_num] = calc_possible();  # determine all possible moves from this square
	$move_try = 0x01;				## always start with LSB move
	$state = "MAKE_MOVE";
  }
  ###################
  # MAKE_MOVE State #
  ###################
  elsif ($state=~/MAKE_MOVE/) {
  #If move is possible and the position is not visited yet
	if (($poss_moves[$move_num] & $move_try) && 
  ($board[$xx+$xoff{$move_try}][$yy+$yoff{$move_try}]==0)) {
	  $board[$xx+$xoff{$move_try}][$yy+$yoff{$move_try}] = $move_num + 2;
    #Update position of knight
	  $xx = $xx+$xoff{$move_try};
	  $yy = $yy+$yoff{$move_try};

	  $last_move[$move_num] = $move_try;
      if ($move_num==23) {		# we are done!
        $go = 0;
        $state = "IDLE";
      }
      else {
        $state = "POSSIBLE";
      }
      $move_num++;
      prnt_brd();		
	}
	elsif ($move_try!=0x80) {  ## move was not possible, is there another we could try?
	  $move_try = ($move_try<<1);	# advance to see if next move is possible
    }
	else {					## no moves possible...we need to backup
	  $state = "BACKUP";
	}
  }
  ################
  # BACKUP State #
  ################
  elsif ($state=~/BACKUP/) {
	$board[$xx][$yy] = 0;			# since we are backing up we have no longer visited this square
	$xx = $xx - $xoff{$last_move[$move_num-1]};
	$yy = $yy - $yoff{$last_move[$move_num-1]};
	$move_try = ($last_move[$move_num-1]<<1);	# next move to try is last one advanced 1
	if ($last_move[$move_num-1]!=0x80) {  # after backing up we have some moves to try
		$state = MAKE_MOVE;
	}
	## there is an infered "else" here where we stay in BACKUP and backup yet again.
    $move_num--;	
  }
}
exit;

#################################
# Now print out results of move #
#################################
sub prnt_brd() {
	print "--------------------\n";
	for ($y=4; $y>=0; $y--) {
	  for ($x=0; $x<5; $x++) {
		if ($board[$x][$y]<10) { print " "; }
		print "$board[$x][$y]  ";
	  }
	  print "\n\n";
	}
}

sub calc_possible() {
  ###################################################################
  # The best case scenario there are 8 possible moves for a knight. #
  # Each possible move is represented by a bit in a byte.  The LSB  #
  # in this case represents a move of 1 in X and +2 in Y. ...       #
  # calc_possible will look at all 8 possible moves are in bounds   #
  # of the board. If a next move is in bounds of the board that     #
  # corresponding bit is set in the $poss byte. You can implement   #
  # a function that does this in verilog that is synthesizeable,    #
  # but it will be more parallel in nature (no loop).               #
  ###################################################################
  $poss = $0;
  $try = 1;					## Start with LSB
  for ($x=0; $x<8; $x++) {
    if (($xx+$xoff{$try}>=0) && ($xx+$xoff{$try}<5) &&	## if location tried is in bounds of board
 	    ($yy+$yoff{$try}>=0) && ($yy+$yoff{$try}<5)) {
			
		$poss = $poss | $try; 	## add it as an in bounds move

	}
    $try = $try<<1;		## Advance to next try
  }
  return $poss;
}

