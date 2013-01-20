n = 8

Core = require './core'
ReversiBoard = Core.ReversiBoard
ReversiSearchState = Core.ReversiSearchState
settings = Core.settings

[black, white] = [settings.black, settings.white]

flipTurn = (turn) ->
  if turn is black then white else black

randBoard = (nStep) ->
  rb = new ReversiBoard(n)
  turn = black
  for i in [0..nStep - 1]
    hints = rb.hint turn
    [x, y] = hints[Math.floor Math.random() * hints.length]
    rb.putChess x, y, turn
    turn = flipTurn turn
  rb

nStep = Number(process.argv[2])
randBoard(nStep).print()
