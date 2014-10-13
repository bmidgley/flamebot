class RobotState
  constructor: (@name, @goals, @listener, @entering) ->
    @behaviors = []
    @parent = null
    @addForward = true

  # add a child state
  addChild: (state) ->
    state.parent = @
    if @addForward
      @behaviors.push state
    else
      @behaviors.unshift state
    state

  # process an event
  processEvent: (currentState, event) ->
    if @parent
      newState = @parent.processEvent(currentState, event)
    unless newState
      newState = @listener(currentState, event)
      if newState && newState.entering
        newState.entering(currentState)
    newState

  findHandler: (goal) ->
    @ancestor().findHandlerR(goal)

  findHandlerR: (goal) ->
    return @ if goal in @goals
    for behavior in @behaviors
      found = behavior.findHandlerR(goal)
      if found
        return found
    null

  ancestor: ->
    return @ unless @parent
    return @parent.ancestor()

  contains: (target) ->
    return true if target == @
    for child in @behaviors
      return true if child.contains(target)
    return false

# loop forever state
class RobotLoopState extends RobotState
  constructor: (name, goals) ->
    super name, goals, (currentState, event) ->
      # only modify the current state if it is me
      return null if currentState != @
      @behaviors[0] || @parent

# move to each child state in sequence then move to parent state
class RobotSequentialState extends RobotState
  constructor: (name, goals) ->
    super name, goals, (currentState, event) ->
      # only modify the current state if it is me
      return null if currentState != @
      return @behaviors[@counter] || @parent
    , (oldState) ->
      # sequence is initialized/incremented if reached from a descendant
      # and reset if we entered from elsewhere
      @counter = if @contains(oldState) then (@counter || -1) + 1 else 0

# drop a flag at the current location as a finding state and child of x
class RobotFlaggingState extends RobotState
  constructor: (name, goals, parent) ->
    super name, goals, (currentState, event) ->
      if event.location
        parent.addChild new RobotFindingState("flag: #{name}", [], event.location.coords)
        return @parent
      null

# shoot a picture and move to parent state
class RobotPhotographingState extends RobotState
  constructor: (name, goals, filename) ->
    super name, goals, (currentState, event) ->
      @parent
    , ->
      options = camera: navigator.mozCameras.getListOfCameras()[0]
      naigator.mozCameras.getCamera options, (camera) ->
        poptions =
          rotation: 90
          pictureSize: camera.capabilities.pictureSizes[0]
          fileFormat: camera.capabilities.fileFormats[0]
        camera.takePicture poptions, (blob) ->
          navigator.getDeviceStorage('pictures').addNamed(blob, filename)

# go to the location specified and then move to parent state
class RobotFindingState extends RobotState
  constructor: (name, goals, @location, @perimeter=1, @compass_variance=20) ->
    super name, goals, (currentState, event) ->
      # location
      if event.location
        @current_location = event.location.coords

        # finish if perimeter was broken
        if @distance(@current_location, @location) < @perimeter
          return @parent

      # compass
      if event.orientation
        @compass_reading = event.orientation.alpha

      newState = @

      # compare the direction with our goal direction
      d = @correction()
      if d > @compass_variance
        newState = @left_turning
      if d < -@compass_variance
        newState = @right_turning

      return null if currentState == newState
      return newState
    , ->
      drive 1

    @left_turning = @addChild new RobotState "#{@name}: left-turn", ["left-turn"],
    (currentState, event) ->
      null
    , ->
      drive 5

    @right_turning = @addChild new RobotState "#{@name}: right-turn", ["right-turn"],    
    (currentState, event) ->
      null
    , ->
      drive 6

  toRadians: (r) ->
    r * Math.PI / 180.0

  toDegrees: (d) ->
    180.0 * d / Math.PI

  correction: ->
    # return signed degree measurement needed to course correct
    # return 0 if we don't know which way we need to turn
    return 0 unless @compass_reading
    return 0 unless @current_location
    bearing = @bearing @location, @current_location
    ((360 + @compass_reading - bearing) % 360) - 180

  bearing: (a, b) ->
    lat1 = @toRadians(a.latitude)
    lat2 = @toRadians(b.latitude)
    lon1 = @toRadians(a.longitude)
    lon2 = @toRadians(b.longitude)
    y = Math.sin(lon2 - lon1) * Math.cos(lat2)
    x = Math.cos(lat1)*Math.sin(lat2) - Math.sin(lat1)*Math.cos(lat2)*Math.cos(lon2-lon1)
    @toDegrees Math.atan2(y, x)

  distance: (a, b, r=6371000) ->
    lat1 = @toRadians(a.latitude)
    lat2 = @toRadians(b.latitude)
    lon1 = @toRadians(a.longitude)
    lon2 = @toRadians(b.longitude)
    n = (Math.sin((lat2-lat1)/2)**2) + Math.cos(lat1) * Math.cos(lat2) * Math.sin((lon2-lon1)/2) * Math.sin((lon2-lon1)/2)
    d = 2 * r * Math.atan2(Math.sqrt(n), Math.sqrt(1-n))
    return d

# limit time spent on an activity
class RobotTimeLimit extends RobotState
  constructor: (name, goals, @remaining) ->
    super name, goals, (currentState, event) ->
      if event.timer
        @remaining -= event.timer
        return @parent if @remaining <= 0
      null

# build my state machine
class RobotTestMachine extends RobotState
  constructor: ->
    super "waiting", ["stop"], (currentState, event) ->
      if event.button
        return currentState.findHandler(event.button)
      null
    , ->
      drive 0
    @go = @addChild new RobotSequentialState "stepping", ["go"]
    @store = @addChild new RobotFlaggingState "storing", ["store"], @go
    @reset = @addChild RobotState "resetting", ["reset"], (currentState, event) ->
      # start again with a clean slate
      new RobotTestMachine()

finderBotState = new RobotTestMachine()
announceBotEvent = (event) ->
  newState = finderBotState.processEvent(finderBotState, event)
  if newState
    finderBotState = newState
    console.log finderBotState.name

$.ajaxSetup xhr: ->
  new window.XMLHttpRequest mozSystem: true

drive = (code, speed=8) ->
  $.ajax 'http://localhost:8080/' + code + speed.toString(16), type: 'GET', dataType: 'html', success: (data) ->
    announceBotEvent battery: data

$ ->
  for action in ["go", "stop", "store", "reset"]
    $("##{action}-button").click ->
      announceBotEvent button: action

  motionTimeStamp = 0
  motionVector = {x:0, y:0, z:0}
  minInterval = 1000000
  crash_id = window.addEventListener 'devicemotion', (event) ->
    a = event.accelerationIncludingGravity 
    m = motionVector
    v = (a.x - m.x)**2 + (a.y - m.y)**2 + (a.z - m.z)**2
    interval = event.timeStamp - motionTimeStamp
    motionVector = {x:a.x, y:a.y, z:a.z}
    if v > 25 && interval > minInterval
      console.log "motion event magnitude #{v} after #{interval/minInterval} intervals"
      announceBotEvent crash: event
      motionTimeStamp = event.timeStamp

  orientation_id = window.addEventListener 'deviceorientation', (event) ->
    e = event
    # event.{alpha,beta,gamma} where alpha is compass direction
    announceBotEvent orientation: event
  , true

  watch_id = navigator.geolocation.watchPosition (position) ->
    # position.coords.{latitude,longitude}
    announceBotEvent location: position

  interval_id = window.setInterval ->
    announceBotEvent timer: 1
  , 1000

console.log finderBotState.name

# adb shell
# rfcomm bind hci0 00:12:05:09:97:47 1
# echo $$ >/persist/drive.pid
# while true; do
#  request=`echo -e -n "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\n\r\n99" | nc -l -p 8080`
#  echo -e -n "\x${request:5:2}"
#done >/dev/rfcomm0
