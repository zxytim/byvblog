print = console.log

n = 8

Core = require './core'
ReversiBoard = Core.ReversiBoard
ReversiSearchState = Core.ReversiSearchState
KillerTable = Core.KillerTable

settings = Core.settings

[black, white] = [settings.black, settings.white]
turn2str = {}
turn2str[black] = 'black'
turn2str[white] = 'white'

flipTurn = (turn) ->
  if turn is black then white else black


print_usage = (will_exit) ->
  print "Usage: #{process.argv[0]} #{process.argv[1]} <black ai> <white ai>"
  process.exit() if will_exit?

getReversiAiFromFile = (fpath) ->
  fpath = fpath.trim()
  if (fpath.substring(0, 1) isnt '/' and fpath.substring(0, 2) isnt './' and fpath.substring(0, 3) isnt '../')
    # then add './'
    fpath = './' + fpath
  ret = new (require fpath).Reversi(n)
  console.log "ai #{fpath} loaded."
  ret

randBoard = (nStep) ->
  rb = new ReversiBoard(n)
  turn = black
  for i in [0..nStep - 1]
    hints = rb.hint turn
    [x, y] = hints[Math.floor Math.random() * hints.length]
    rb.putChess x, y, turn
    turn = flipTurn turn
  rb


main = () ->
  print_usage(true) if process.argv.length isnt 4
  ai = {}
  ai[black] = getReversiAiFromFile(process.argv[2])
  ai[white] = getReversiAiFromFile(process.argv[3])

  ai[black].init()
  ai[white].init()


  if 1
    rb = new ReversiBoard(n) #randBoard(10)
    rb.fromString("""
01000000
20100201
02010020
00221122
00121210
00112211
01021000
00001000
    """)
#rb = randBoard(10)
    rb.print()
    turn = white
    [x, y] = ai[black].nextStep rb, turn
    return


  board = new ReversiBoard(n)
  turn = settings.black

  board.enableHistory = true
  ###
  state = new ReversiSearchState(board, turn)
  ntest = 10
  board.print()
  for i in [0..ntest-1] by 1
    [x, y] = board.hint(turn).first()
    board.putChess x, y, turn
    board.print()
    turn = flipTurn turn
  print "-----"
  for i in [0..ntest] by 1
    board.rollback()
    board.print()
  return
  ###


  while not board.gameEnds()
    print "#{turn2str[turn]} turn"
    if not board.missTurn turn
      [x, y] = ai[turn].nextStep board, turn
      board.putChess x, y, turn
    else
      print "#{turn} missed turn"
    turn = flipTurn turn
    board.print()
    console.log board.getParams black

main()
