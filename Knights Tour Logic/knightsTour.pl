#!/usr/bin/perl/

###########################################
# This script will solve the knights tour #
###########################################

#### Data structures ####
# $board[][] is a two dimensional array that holds 0 or 1, 1 => knight has been there
# $xx = xposition on board
# $yy = yposition on board
# $last_move[] = array of last moves from this position
# $possible[] = packed byte that represents all possible moves from that square
#    bit0 = up and to right (+1,+2), bit1 = up and to left (-1,+2)
#    bit2 = left and up (-2,+1), bit3 = left and down (-2,-1)
#    bit4 = down and left (-1,-2), bit 5 down and right (+1,-2)
#    bit6 = right and down (+2,-1), bit7 = right and up (+2,+1)
# $move_num = move number
# $N = size of board (assumed square NxN)

####################
# initialize board #
####################
for ($x=0; $x<5; $x++) {
  for ($y=0; $y<5; $y++) {
    $board[$x][$y] = 0;			# a 0 indicates this board position not visited yet
  }
}
###########################################
# Initialize move offsets from LSB to MSB #
###########################################
# This is a decode of a packed byte where #
# the LSB of that byte represents a move  #
# of -1 in the X and +2 in the Y.  The    #
# MSB of the byte represents a move of +2 #
# in the X and -1 in the Y.               #
###########################################
$xoff{1} = 1; $yoff{1} = 2;
$xoff{2} = -1; $yoff{2} = 2;
$xoff{4} = -2; $yoff{4} = 1;
$xoff{8} = -2; $yoff{8} = -1;
$xoff{16} = -1; $yoff{16} = -2;
$xoff{32} = 1; $yoff{32} = -2;
$xoff{64} = 2; $yoff{64} = -1;
$xoff{128} = 2; $yoff{128} = 1;

#### set starting location ####
$xx = 0;	# center of the board
$yy = 0;
$tot_moves = 24;	# total of 24 moves for a 5x5 board

$move_num = 0;
$new_move = 1;					# we start at 2,2 which is considered our "1st" move
while ($move_num<$tot_moves) {	# while we have not completed the tour
  if ($new_move) {				# if we have made a new move, mark our position as visited			
    $board[$xx][$yy] = $move_num+1;			# Mark this position as visited by writing move number
    $possible[$move_num] = calc_possible(); # calculate all possible moves from this position
    $move_try = 0x01;			# always start with LSB move
	prnt_brd();					# print board with every new move
  }
  $moved = 0;					# now knock down moved flag and try to make a new move
  while (($possible[$move_num]!=$0) && (!($moved))) {  # while there are possible moves to try
    if ($move_try & $possible[$move_num]) {		   # if left shift of move_try is a possible move
	  $moved = 1;							   	   # we try it and remember
	  $last_move[$move_num] = $move_try;		   # our last move incase we need to "backup"
	  $xx = $xx + $xoff{$move_try};			   # calc our new board position for this move
	  $yy = $yy + $yoff{$move_try};
	  $move_num++;							   # increment the move counter
	  $new_move = 1;						   # set flag that we made a new move so we mark it					
	}
	else {		# there are more moves yet to try?
	  $move_try = $move_try<<1;				   # advance to new move try by shifting left
	}
  }
  if ((!($moved)) && ($move_num<$tot_moves)) {	# moved to a deadend (need to backup)
	  $board[$xx][$yy] = 0;					# this move was a deadend so we will backup, so now not visited
	  $move_num--;
	  $xx = $xx - $xoff{$last_move[$move_num]};	# backup our position on the board
	  $yy = $yy - $yoff{$last_move[$move_num]};
	  $move_try = $last_move[$move_num];		# recall what move we tried last from the previous position
	  $possible[$move_num] = $possible[$move_num] & ~$move_try;	# that move resulted in deadend so remove it as possible
	  $move_try = $move_try<<1;				# try next move in packed byte (might not be possible)
	  $new_move = 0;						# this is not a new move, but rather a backup move
  }
}
$board[$xx][$yy] = $move_num+1;			# mark the last move
prnt_brd();								# print board one last time
exit;

#################################
# Now print out results of tour #
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
  ##########################################################################
  # Calculate all possible moves from this square All 8 possible moves are #
  # checked to see if they are within the bounds of the board and also not #
  # already visited.  For each possible move a bit in a byte is set.  See  #
  # definition of $xoff{} $yoff{}.                                         #
  #                                                                        #
  # NOTE: This routine in the next perl program, and the equivalent routine#
  # in my verilog only checks the move is in bounds, the check that the    #
  # position being moved to has not yet been visited is checked elsewhere. # 
  ##########################################################################
  $poss = $0;
  $try = 1;					## Start with LSB
  for ($x=0; $x<8; $x++) {
    if (($xx+$xoff{$try}>=0) && ($xx+$xoff{$try}<5) &&	## if location tried is in bounds
 	    ($yy+$yoff{$try}>=0) && ($yy+$yoff{$try}<5)) {
	  if ($board[$xx+$xoff{$try}][$yy+$yoff{$try}]==0) {  ## if has not been visited
		$poss = $poss | $try;	## add it as a possible move
	  }
	}
    $try = $try<<1;
  }
  return $poss;
}

