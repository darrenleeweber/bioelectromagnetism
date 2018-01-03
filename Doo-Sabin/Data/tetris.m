function [pts,pgons]=tetris

pts=...
  [0 0 0;
   0 0 1;
   1 0 1;
   1 0 0;
   0 3 0;
   0 3 1;
   1 3 1;
   1 3 0;
   1 1 0;
   1 1 1;
   1 2 1;
   1 2 0;
   3 1 0;
   3 1 1;
   3 2 1;
   3 2 0;];

pgons=...
  {[1 2 3 4]
   [4 3 10 9]
   [1 4 9 12 8 5]
   [1 5 6 2]
   [2 6 7 11 10 3]
   [7 6 5 8]
   [11 7 8 12]
   [10 11 15 14]
   [9 10 14 13]
   [9 13 16 12]
   [16 15 11 12]
   [13 14 15 16]};
   



