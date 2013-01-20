#= require ../jquery-1.8.2
#= require reversi/core
$ ->

  deepCopy = (x) ->
    $.extend({}, x)


  # used in where efficiency is of no importance
  range = () ->
    return [] if arguments.length == 0
    return [0..arguments[0] - 1] if arguments.length == 1
    return [arguments[0]..arguments[1] - 1]
  # defines
  [empty, white, black] = [0, 1, 2]
  chessSet = [white, black]
  [STATUS_FREE, STATUS_AI_THINKING] = [i for i in range(100)]
  
  # {
  class ReversiController
    constructor: ($reversiDiv, @unit = 60, @borderLength = 4) ->
      @$reversiDiv = $reversiDiv
      @n = 8
      @reversi = new Reversi(@n)

      @status = STATUS_FREE

      @turn = black
      @settings =
        hint: true

      @canvas = document.createElement 'div'
      @canvas.id = "canvas"
      @canvas.style.width = "#{@n * @unit}px"
      @canvas.style.height = "#{@n * @unit}px"

      @colorCssClass ={}
      @colorCssClass[empty] = 'empty-cell'
      @colorCssClass[black] = 'black-cell'
      @colorCssClass[white] = 'white-cell'

      @rvsBoard = new ReversiBoard(@n)

      # html empty board, and chesses
      @board = []
      @chess = []
      for i in range(@n)
        @board.push []
        @chess.push []
        for j in range(@n)
          type = @rvsBoard[i][j]
          @board[i][j] = @newBoardCell i, j
          @chess[i][j] = @newChessCell i, j, type

      # add board background
      background = document.createElement 'div'
      background.style.left = '0px'
      background.style.right = '0px'
      background.style.width = "#{@unit * @n + @borderLength * (@n + 1)}px"
      background.style.height = "#{@unit * @n + @borderLength * (@n + 1)}px"
      background.className = 'board'
      @canvas.appendChild background

      $reversiDiv.data("controller", this)
      $reversiDiv[0].appendChild @canvas
      @updateHtmlBoard()

      # (eventEmitter, ...)
      
    cellPosition: (x) ->
      x * @unit + (x + 1) * @borderLength

    newBoardCell: (x, y) ->
      elem = document.createElement 'div'
      elem.style.left = "#{@cellPosition x}px"
      elem.style.top = "#{@cellPosition y}px"
      elem.style.width = "#{@unit}px"
      elem.style.height = "#{@unit}px"
      elem.className = "board-cell x-#{x} y-#{y}"
      elem.boardAttr = {}
      elem.boardAttr.x = x
      elem.boardAttr.y = y

      @canvas.appendChild elem
      elem

    newChessCell: (x, y, type) ->
      console.log type, @colorCssClass
      elem = document.createElement 'div'
      elem.style.left = "#{@cellPosition x}px"
      elem.style.top = "#{@cellPosition y}px"
      elem.style.width = "#{@unit}px"
      elem.style.height = "#{@unit}px"
      elem.style.borderRadius = "#{@unit / 2}px"
      elem.className = "clickable #{@colorCssClass[type]} x-#{x} y-#{y}"
      elem.boardAttr = {}
      elem.boardAttr.x = x
      elem.boardAttr.y = y
      elem.boardAttr.type = type

      @canvas.appendChild elem
      elem

    flipTurn: (turn) ->
      if turn is black then white else black

    updateHtmlBoard: () ->
      for i in range @n
        for j in range @n
          if i is 3 and j is 4
            hello = 1
          to = @rvsBoard[i][j]
          chess = @chess[i][j]

          chess.setAttribute("data-rvsboard", to)
          $(chess).removeClass('hint-cell')

          # hint
          if @settings.hint and @rvsBoard.canPutChess i, j, @turn
            $(chess).addClass('hint-cell')
            continue

          ctype = chess.boardAttr.type
          #console.log i, j, "ctype", ctype, "to", to
          continue if ctype is to
          # to is not empty
          
          # the same type

          if ctype is empty
            # new chess here
            $(chess).removeClass(@colorCssClass[empty]).addClass @colorCssClass[to]
          else # animate TODO: more cool 3D flip
            console.log "animate", i, j
            #[clsa, clsb] = (@colorCssClass[i] for i in chessSet)
            $(chess)
            .removeClass(@colorCssClass[@flipTurn to])
            .addClass(@colorCssClass[to])
          chess.boardAttr.type = to

    # EVENT
    cellClick: (cell) ->
      # human placing chess
      [x, y] = [cell.boardAttr.x, cell.boardAttr.y]
      if not @rvsBoard.canPutChess x, y, @turn
        console.log "can not place chess at (#{x},#{y})"
        return
      @rvsBoard.putChess x, y, @turn
      @rvsBoard.print()
      @turn = @flipTurn @turn
      @updateHtmlBoard()
        
      # ai thinking
      nextStep = @reversi.nextStep @rvsBoard, @turn
      console.log "nextStep", nextStep
      if nextStep is null
        console.log "computer has nowhere to place chess"
      else
        [x, y] = nextStep
        @rvsBoard.putChess x, y, @turn
        @rvsBoard.print()
      @turn = @flipTurn @turn
      @updateHtmlBoard()
      console.log "computer place chess at (#{x},#{y})"

  # } end ReversiController
  #
  class Utils
    @addClass: (className, newClass) ->
      # [WARN] fail on if newClass == PREFIX(otherClass)
      if className.indexOf(' ' + newClass) == -1
        className + ' ' + newClass
      else
        className

    @removeClass: (className, oldClass) ->
      idx = className.indexOf(' ' + oldClass)
      if idx != -1
        className.substring(0, idx) + className.substring(idx + 1 + oldClass.length)
      else
        className

    @toggleClass: (className, toggleClass) ->
      idx = className.indexOf(' ' + toggleClass)
      if idx is -1
        className + ' ' + toggleClass
      else
        className.substring(0, idx) + className.substring(idx + 1 + toggleClass.length)


  init = () ->
    new ReversiController $(".reversi")
    controller = (div) ->
      $(div).closest(".reversi").data("controller")
    $(document)
    .on "click", ".clickable", () ->
      controller(this).cellClick(this)

  $(document).ready init
