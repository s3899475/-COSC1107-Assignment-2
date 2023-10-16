# js langton's ant display
import dom
from math import ceil, pow
from strutils import parseInt, parseFloat, allCharsInSet

import ../langton

const
  INITIAL_GRID_SIZE = 256
  # scale goes in reverse
  INITIAL_SCALE = 4
  MAX_SCALE = 256

type
  Canvas* = ref CanvasObj
  CanvasObj {.importc.} = object of dom.Element
    width*: int
    height*: int
  
  CanvasContext2d* = ref CanvasContext2dObj
  CanvasContext2dObj {.importc.} = object
    canvas*: Canvas
    font*: cstring
    fillStyle*: cstring # converting to hex in nim js core seems very slow

  Button* = ref ButtonObj
  ButtonObj {.importc.} = object of dom.Element

  WheelEvent* = ref WheelEventObj
  WheelEventObj {.importc.} = object of dom.MouseEvent
    deltaY*: float


proc getContext2d*(c: Canvas): CanvasContext2d =
  {.emit: "`result` = `c`.getContext('2d');".}

proc beginPath*(ctx: CanvasContext2d) {.importcpp.}
proc closePath*(ctx: CanvasContext2d) {.importcpp.}
proc stroke*(ctx: CanvasContext2d) {.importcpp.}
proc strokeText*(ctx: CanvasContext2d, txt: cstring, x, y: float) {.importcpp.}
proc fillRect*(ctx: CanvasContext2d, x, y, width, height: int) {.importcpp.}
proc clearRect*(ctx: CanvasContext2d, x, y, width, height: int) {.importcpp.}
# only works with literals >:(
#proc fillStyle*(ctx: CanvasContext2d, r, g, b: float) =
#  {.emit: "`ctx`.fillStyle = ``rgb(`r`,`g`,`b`)``;".}
#template fillStyle(ctx: CanvasContext2d, col: tuple[r, g, b: float]) =
#  ctx.fillStyle(col.r, col.g, col.b)

template id(str: string): Element = dom.document.getElementById(str)

# draw a single "pixel" on the grid
proc draw_on_grid(ctx: CanvasContext2d, x, y: int, scale: int) =
  let grid_size: int = INITIAL_GRID_SIZE div scale
  let pos: tuple[x, y: int] = (
    ctx.canvas.width div 2 + x*grid_size,
    ctx.canvas.height div 2 + y*grid_size
  )
  ctx.fillRect(
    pos.x,
    pos.y,
    grid_size,
    grid_size
  )

# greyscale colour palette
proc greyscale(top: int, val: int): cstring =
  let shade = $(255 - math.ceil(val.float / top.float * 255))
  #fmt"rgb({shade}, {shade}, {shade})".cstring
  cstring("rgb(" & shade & "," & shade & "," & shade & ")")

# rainbow colour palette
proc rainbow(top: int, val: int): cstring =
  if val == 0:
    cstring("#FFFFFF")
  else:
    let hue = $(360 - math.ceil(val.float / top.float * 360))
    cstring("hsl(" & hue & ",90%,50%)")

# generate full palette
proc gen_palette(a: Ant, palette: cstring): seq[cstring] =
  var fn: proc(top, val: int): cstring
  case palette:
    of "greyscale":
      fn = greyscale
    of "rainbow":
      fn = rainbow
    else:
      fn = greyscale

  for i in 0..<a.nstates:
    result.add fn(a.nstates-1, i)

proc draw_spaces(ctx: CanvasContext2d, a: Ant, scale: int, palette: seq[cstring]) =

  # draw grid spaces
  for y_idx in 0..<a.size.y:
    for x_idx in 0..<a.size.x:
      let val = a[x_idx, y_idx]
      let (x, y) = (x_idx - a.size.x div 2, y_idx - a.size.y div 2)
      if val > 0:
        ctx.fillStyle = palette[val]
        ctx.draw_on_grid(x, y, scale)

proc draw_ant(ctx: CanvasContext2d, a: Ant, scale: int, colour: cstring = "red") =
  ctx.fillStyle = colour
  ctx.draw_on_grid((a.pos.x - a.size.x div 2), (a.pos.y - a.size.y div 2), scale)

proc draw_bounds(ctx: CanvasContext2d, a: Ant, scale: int, colour: cstring = "black") =
  let
    grid_size: int = INITIAL_GRID_SIZE div scale
    bounds_size: tuple[x, y: int] = (
      (a.size.x + 1) * grid_size,
      (a.size.y + 1) * grid_size
    )
    tl: tuple[x, y: int] = (
      ctx.canvas.width div 2 - (a.size.x div 2 + 1) * grid_size,
      ctx.canvas.height div 2 - (a.size.y div 2 + 1) * grid_size
    )
  ctx.fillStyle = colour
  # x, y, width, height
  ctx.fillRect(tl.x, tl.y, bounds_size.x, grid_size)
  ctx.fillRect(tl.x, tl.y+bounds_size.y, bounds_size.x, grid_size)
  ctx.fillRect(tl.x, tl.y, grid_size, bounds_size.y)
  ctx.fillRect(tl.x + bounds_size.x, tl.y, grid_size, bounds_size.y + grid_size)

proc fitCanvas(c: Canvas) =
  c.width = dom.window.innerWidth
  c.height = dom.window.innerHeight

proc get_interval(idx: int): int =
  let values = [5, 10, 50, 100, 200, 500, 1000, 2000]
  if idx < 0 or idx > values.len-1:
    100
  else:
    values[idx]

proc definition_valid(def: string): bool =
  def != "" and def.allCharsInSet({'L', 'R', 'U', 'N'})

# initaliase
dom.window.onload = proc (e: dom.Event) =
  # element selectors
  let 
    antDefinition = id"AntDefinition"
    jumpSlider = id"JumpSlider"
    jumpValueLabel = id"JumpValueLabel"
    intervalSlider = id"IntervalSlider"
    intervalValueLabel = id"IntervalValueLabel"
    paletteSelector = id"PaletteSelector"
    boundsSelector = id"BoundsSelector"
    showAntCheck = id"ShowAntCheck"
    showBoundsCheck = id"ShowBoundsCheck"
    showBoundsEditCheck = id"ShowBoundsEditCheck"
    errorText = id"ErrorText"
    sizeSliderLeft = id"SizeLeft"
    sizeSliderRight = id"SizeRight"
    sizeSliderTop = id"SizeTop"
    sizeSliderBottom = id"SizeBottom"
    runButton = id"RunButton".Button

  # initialize settings
  var
    running = false
    scale = INITIAL_SCALE
    jump = math.pow(10, parseFloat($jumpSlider.value)).int
    interval = get_interval(parseInt($intervalSlider.value))
    show_ant = showAntCheck.checked
    show_bounds = showBoundsCheck.checked

    ant: Ant
    size: tuple[x, y: int] = (100, 100)
    palette: seq[cstring]
    stop_on_bounds: bool = boundsSelector.value == "stop"
    leftBoundsClicked, rightBoundsClicked, topBoundsClicked, bottomBoundsClicked = false

  if definition_valid($antDefinition.value):
    ant = newAnt($antDefinition.value, size) # will be "RL" by default, set in html
  else:
    errorText.textContent = "Ant definition must contain only: (L,R,U,N)"
    ant = newAnt("RL", size)

  palette = ant.gen_palette(paletteSelector.value)

  jumpValueLabel.textContent = cstring($jump)
  intervalValueLabel.textContent = cstring($interval)

  let c = id"Langton".Canvas
  let ctx = c.getContext2d()
  c.fitCanvas

  proc draw() =
    # clear canvas
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height)
    ctx.draw_spaces(ant, scale, palette)
    if show_ant:
      ctx.draw_ant(ant, scale)
    if show_bounds:
      ctx.draw_bounds(ant, scale)

  proc update_bounds_sliders() =
    let grid_size: int = INITIAL_GRID_SIZE div scale
    let mid: tuple[x, y: int] = (c.width div 2, c.height div 2)
    sizeSliderLeft.style.left = cstring($(mid.x - (ant.size.x div 2)*grid_size - grid_size) & "px")
    sizeSliderRight.style.left = cstring($(mid.x + (ant.size.x div 2)*grid_size) & "px")
    sizeSliderTop.style.top = cstring($(mid.y - (ant.size.y div 2)*grid_size - grid_size) & "px")
    sizeSliderBottom.style.top = cstring($(mid.y + (ant.size.y div 2)*grid_size) & "px")
    sizeSliderLeft.style.width = cstring($grid_size & "px")
    sizeSliderRight.style.width = cstring($grid_size & "px")
    sizeSliderTop.style.height = cstring($grid_size & "px")
    sizeSliderBottom.style.height = cstring($grid_size & "px")

  proc get_bounds_size(): tuple[x, y: int] =
    let
      grid_size: int = INITIAL_GRID_SIZE div scale
      left = sizeSliderLeft.offsetLeft
      right = sizeSliderRight.offsetLeft
      top = sizeSliderTop.offsetTop
      bottom = sizeSliderBottom.offsetTop
    result = (
      (right - left) div grid_size - 1,
      (bottom - top) div grid_size - 1
    )

  # update canvas size on window resize
  dom.window.addEventListener("resize", proc(event: dom.Event) =
    c.fitCanvas
    draw()
    update_bounds_sliders()
  )

  # zoom in and out on canvas
  c.addEventListener("wheel", proc(event: dom.Event) =
    let up_scroll = event.UIEvent.MouseEvent.WheelEvent.deltaY < 0 # works!
    if up_scroll:
      # use ceil to make it always 1 or greater
      scale = math.ceil(scale.float / 2).int
    elif scale < MAX_SCALE: # stop overflow
      scale = scale * 2 # *= generates weird js?

    draw()
    update_bounds_sliders()
    # dont scroll canvas on page
    event.stopImmediatePropagation()
  )

  # Start and stop the simulation
  runButton.onclick = proc(event: dom.Event) =
    if running:
      runButton.textContent = "Run"
      running = false
    else:
      runButton.textContent = "Stop"
      running = true

  # Jump through multiple iterations
  jumpSlider.addEventListener("input", proc(event: dom.Event) =
    jump = math.pow(10, parseFloat($event.target.value)).int
    jumpValueLabel.textContent = cstring($jump)
  )

  # Change to a different ant
  let restartButton = id"RestartButton"
  restartButton.onclick = proc(event: dom.Event) =
    if definition_valid($antDefinition.value):
      size = get_bounds_size()
      errorText.textContent = ""
      ant = newAnt($antDefinition.value, size)
      palette = ant.gen_palette(paletteSelector.value)

      draw()
    else:
      running = false
      errorText.textContent = "Ant definition must contain only: (L,R,U,N)"

  # Change colour palette
  paletteSelector.onchange = proc(event: dom.Event) =
    palette = ant.gen_palette(paletteSelector.value)
    draw()
  
  # Change bounds mode
  boundsSelector.onchange = proc(event: dom.Event) =
    if boundsSelector.value == "stop":
      stop_on_bounds = true
    else:
      stop_on_bounds = false

  # Show/Don't show ant
  showAntCheck.onchange = proc(event: dom.Event) =
    show_ant = showAntCheck.checked
    draw()

  # Show/Don't show bounds
  showBoundsCheck.onchange = proc(event: dom.Event) =
    show_bounds = showBoundsCheck.checked
    draw()

  # Show/Don't show bounds editor
  showBoundsEditCheck.onchange = proc(event: dom.Event) =
    if showBoundsEditCheck.checked:
      sizeSliderLeft.style.display = "initial"
      sizeSliderRight.style.display = "initial"
      sizeSliderTop.style.display = "initial"
      sizeSliderBottom.style.display = "initial"
    else:
      sizeSliderLeft.style.display = "none"
      sizeSliderRight.style.display = "none"
      sizeSliderTop.style.display = "none"
      sizeSliderBottom.style.display = "none"

  # Bounds controls
  sizeSliderLeft.addEventListener("mousedown", proc(event: dom.Event) =
    leftBoundsClicked = true
  )
  sizeSliderRight.addEventListener("mousedown", proc(event: dom.Event) =
    rightBoundsClicked = true
  )
  sizeSliderTop.addEventListener("mousedown", proc(event: dom.Event) =
    topBoundsClicked = true
  )
  sizeSliderBottom.addEventListener("mousedown", proc(event: dom.Event) =
    bottomBoundsClicked = true
  )
  dom.document.addEventListener("mouseup", proc(event: dom.Event) =
    leftBoundsClicked = false
    rightBoundsClicked = false
    topBoundsClicked = false
    bottomBoundsClicked = false
  )
  # move the bounds
  dom.document.addEventListener("mousemove", proc(event: dom.Event) =
    let
      e = event.MouseEvent
      mid: tuple[x, y: int] = (c.width div 2, c.height div 2)
    if leftBoundsClicked:
      sizeSliderLeft.style.left = cstring($min(mid.x, e.clientX) & "px")
      sizeSliderRight.style.left = cstring($max(mid.x, c.width - e.clientX) & "px")
    if rightBoundsClicked:
      sizeSliderLeft.style.left = cstring($min(mid.x, c.width - e.clientX) & "px")
      sizeSliderRight.style.left = cstring($max(mid.x, e.clientX) & "px")
    if topBoundsClicked:
      sizeSliderTop.style.top = cstring($min(mid.y, e.clientY) & "px")
      sizeSliderBottom.style.top = cstring($max(mid.y, c.height - e.clientY) & "px")
    if bottomBoundsClicked:
      sizeSliderTop.style.top = cstring($min(mid.y, c.height - e.clientY) & "px")
      sizeSliderBottom.style.top = cstring($max(mid.y, e.clientY) & "px")
  )

  # main loop
  proc main() =
    if running:
      if not ant.in_bounds():
        if stop_on_bounds:
          errorText.textContent = "Ant hit bounds"
          runButton.textContent = "Run"
          running = false
          return
        else: # loop
          if ant.pos.x >= 0:
            ant.pos.x = ant.pos.x mod ant.size.x
          else:
            ant.pos.x = ant.size.x - 1

          if ant.pos.y >= 0:
            ant.pos.y = ant.pos.y mod ant.size.y
          else:
            ant.pos.y = ant.size.y - 1

      if jump == 1:# incremental draw
        let prev_pos = ant.pos
        ant.step()

        ctx.fillStyle = palette[ant[prev_pos.x, prev_pos.y]]
        ctx.draw_on_grid(prev_pos.x - ant.size.x div 2, prev_pos.y - ant.size.y div 2, scale)
        if show_ant:
          ctx.draw_ant(ant, scale)
        if show_bounds:
          ctx.draw_bounds(ant, scale)
      else: # draw whole thing each jump
        for _ in 1..jump:
          ant.step()
          if not ant.in_bounds(): break

        draw()

  var mainInterval = window.setInterval(main, interval)
  
  intervalSlider.addEventListener("input", proc(event: dom.Event) =
    interval = get_interval(parseInt($intervalSlider.value))
    intervalValueLabel.textContent = cstring($interval)
    mainInterval.clearInterval()
    mainInterval = window.setInterval(main, interval)
  )

