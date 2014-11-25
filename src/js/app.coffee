# robot states use/extend RobotState
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
      return newState if newState
    if @listener
      newState = @listener(currentState, event)
      return newState if newState
    null

  enterAll: (oldState, currentState) ->
    @parent.enterAll(oldState, currentState) if @parent
    @entering(oldState, currentState) if @entering

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

  accordian: (target, event) ->
    collapsed = if (target != @ && @contains(target)) then "false" else "true"
    x = "<div data-role='collapsible' data-collapsed='#{collapsed}' data-theme='b'><h3>#{if target == @ then "*#{@name}#{event}" else @name}</h3>"
    for child in @behaviors
      x += child.accordian(target, event)
    x += '</div>'
    return x

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
    , (oldState, currentState) =>
      # sequence is initialized/incremented if reached from a descendant
      # and reset if we entered from elsewhere
      return unless currentState == @
      @counter = if @contains(oldState) then (@counter || -1) + 1 else 0

  addChild: (state) ->
    state.name += " #{@behaviors.length+1}"
    super state

# limit time spent on an activity
class RobotTimeLimit extends RobotState
  constructor: (name, goals, @duration) ->
    @elapsed = 0
    super name, goals, (currentState, event) ->
      if event.timer
        #console.log "comparing elapsed #{@elapsed} with duration #{@duration}"
        @elapsed += event.timer
        if @elapsed > @duration
          @elapsed = 0
          return @parent
      if currentState == @
        console.log "limit's child completed; passing back to parent"
        return @parent
      null
    , (oldState, currentState) =>
      # if the state was an ancestor before, need to reset the timer
      unless @contains oldState
        @elapsed = 0

# drop a flag at the current location as a finding state and child of x
class RobotFlaggingState extends RobotState
  constructor: (driver, name, flagname, goals, @target) ->
    super name, goals, (currentState, event) ->
      if event.location
        @target.addChild new RobotFindingState(driver, flagname, [], event.location.coords)
        return @parent
      null

# shoot a picture and move to parent state
class RobotPhotographingState extends RobotState
  constructor: (name, goals, @filename) ->
    super name, goals, (currentState, event) ->
      @parent
    , (oldState, currentState) =>
      return unless currentState == @
      cname = navigator.mozCameras.getListOfCameras()[0]
      options = camera: cname
      console.log "selected Camera: #{cname}"
      navigator.mozCameras.getCamera options, (camera) =>
        console.log camera
        poptions =
          rotation: 90
          pictureSize: camera.capabilities.pictureSizes[0]
          fileFormat: camera.capabilities.fileFormats[0]
        console.log poptions
        camera.takePicture poptions, (blob) =>
          console.log blob
          navigator.getDeviceStorage('pictures').addNamed(blob, @filename)
      , (e) -> console.log e

# go to the location specified and then move to parent state
class RobotFindingState extends RobotState
  constructor: (@driver, name, goals, @location, @perimeter=1, @compass_variance=20) ->
    super name, goals, (currentState, event) ->
      # location
      if event.location
        @current_location = event.location.coords

        # finish if perimeter was broken
        if @distance(@current_location, @location) < @perimeter
          return @parent

      # compass
      if event.orientation
        declination = 13
        @compass_reading = (630 - event.orientation.alpha) % 360
        if @debug
          console.log "true orientation: #{@compass_reading}"
          @debug = false

      if event.timer
        @debug2 = true

      newState = @

      # compare the direction with our goal direction
      d = @correction()
      if d > @compass_variance
        newState = @left_turning
      if d < -@compass_variance
        newState = @right_turning

      return null if currentState == newState
      return newState
    , (oldState, currentState) =>
      @driver.drive 1 if currentState == @

    @left_turning = @addChild new RobotState "left", [], (-> null), (=> @driver.drive 5)

    @right_turning = @addChild new RobotState "right", [], (-> null), (=> @driver.drive 6)

  toRadians: (r) ->
    r * Math.PI / 180.0

  toDegrees: (d) ->
    180.0 * d / Math.PI

  correction: ->
    # return signed degree measurement needed to course correct
    # return 0 if we don't know which way we need to turn
    return 0 unless @compass_reading
    return 0 unless @current_location
    bearing = @bearing @current_location, @location
    relative = ((360 + @compass_reading - bearing) % 360)
    relative -= 360 if relative > 180
    if @debug2
      console.log "bearing #{bearing} from compass #{@compass_reading} off by #{relative}. #{@current_location.latitude},#{@current_location.longitude} to #{@location.latitude},#{@location.longitude} #{@distance(@current_location, @location)}m"
      @debug2 = false
    return relative

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
    n = (Math.sin((lat2-lat1)/2)**2) + Math.cos(lat1) * Math.cos(lat2) * (Math.sin((lon2-lon1)/2)**2)
    d = 2 * r * Math.atan2(Math.sqrt(n), Math.sqrt(1-n))
    return d

# end an activity when battery drops too low
# todo: average out the readings
class RobotBatteryLimit extends RobotState
  constructor: (name, goals, @threshold) ->
    super name, goals, (currentState, event) ->
      return @parent if event.battery && event.battery < @threshold
      return null

# base button handler and some debug
class ButtonWatcher extends RobotState
  constructor: (name, goals, entering) ->
    super name, goals, (currentState, event) ->
      return currentState.findHandler(event.button) if event.button
      #console.log("battery is now #{event.battery}") if event.battery
      return null
    , entering


# keep track of state
class StateTracker
  constructor: (@notifier) ->

  # only the state argument is required
  setState: (@state, oldState, event) ->
    @state.enterAll(oldState, @state)
    @notifier(@state, event) if @notifier

  announce: (event) ->
    return unless @state
    newState = @state.processEvent(@state, event)
    @setState(newState, @state, event) if newState


# everyone needs one of these
class ImaginaryCar
  constructor: (@bot) ->

  drive: (code) ->
    console.log "drive(#{code})"
    @bot.announce battery: 11


# LittleCar aka iRacer
# LittleCar depends on a helper to bridge to bluetooth
# adb shell
# rfcomm bind hci0 00:12:05:09:97:47 1
# while true; do
#  request=`echo -e -n "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\n\r\n99" | nc -l -p 8080`
#  echo -e -n "\x${request:5:2}"
#done >/dev/rfcomm0

class LittleCar
  constructor: (@bot) ->
    $.ajaxSetup xhr: -> new window.XMLHttpRequest mozSystem: true

  drive: (code, speed=15) ->
    $.ajax 'http://localhost:8080/' + code + speed.toString(16), type: 'GET', dataType: 'html', success: (data) =>
      @bot.announce battery: data

# BigCar aka Brookstone's Wifi Racer
# BigCar depends on the user to connect the phone to the car's wifi access point

class BigCar
  constructor: (@bot, @pace=250, @address="192.168.2.3", @port=9000) ->
    @connecting = false
    @connectSocket()
    @code = 0
    window.setInterval (=> @nextCode()), @pace

  connectSocket: ->
    return if @connecting
    try
      @socket = navigator.mozTCPSocket.open(@address, @port)
    catch error
      return if @warned
      console.log "cannot open a tcp socket"
      console.log error
      @warned = true
      return
    @connecting = true
    @socket.onopen = => @connecting = false
    @socket.onerror = => @connecting = false
    @socket.onclose = => @connecting = false
    @socket.ondata = (event) =>
      level = (parseInt(event.data.slice(2), 16) - 2655 ) * 0.20
      @bot.announce battery: level

  drive: (@code) ->

  code2command: (code) ->
    newCode = "05893476"[code-1]
    return "$#{newCode}9476$?" if newCode
    return "$?"

  steer: (code) ->
    return "3" if code == 5 || code == 7
    return "4" if code == 6 || code == 8
    return null

  nextCode: ->
    if @socket && @socket.readyState == "open"
      # car will need to be reset if we send excessive stops
      if @code > -5
        steering = @steer @code
        @socket.send @code2command steering if steering
        @socket.send @code2command @code
        @socket.send @code2command steering if steering
        @code -= 1 if @code < 1
    else
      @connectSocket()
      

# Announcers deliver events to a bot
class Announcer
  constructor: (@name, @bot) ->
    console.log "tracking #{@name} events"

# wire up the list of buttons to send corresponding events
class ButtonAnnouncer extends Announcer
  constructor: (name, bot, buttons) ->
    super name, bot
    for action in buttons
      do (action) ->
        $("##{action}-button").click => @bot.announce button: action

# announce a crash if the accelerometer seems to indicate it
class CrashAnnouncer extends Announcer
  constructor: (name, bot, @magnitude = 25, @mininterval = 1000000) ->
    super name, bot
    @motionTimeStamp = 0
    @motionVector = {x:0, y:0, z:0}
    @crash_id = window.addEventListener 'devicemotion', (event) =>
      a = event.accelerationIncludingGravity
      m = @motionVector
      v = (a.x - m.x)**2 + (a.y - m.y)**2 + (a.z - m.z)**2
      interval = event.timeStamp - @motionTimeStamp
      @motionVector = {x:a.x, y:a.y, z:a.z}
      if v > @magnitude && interval > @mininterval
        console.log "motion event magnitude #{v} after #{interval/@mininterval} intervals"
        @bot.announce crash: event
        @motionTimeStamp = event.timeStamp

# announce orentation event.{alpha,beta,gamma} where alpha is compass direction
class OrientationAnnouncer extends Announcer
  constructor: (name, bot) ->
    super name, bot
    @orientation_id = window.addEventListener 'deviceorientation', (event) =>
      @bot.announce orientation: event
    , true

# announce location.coords.{latitude,longitude}
class LocationAnnouncer extends Announcer
  constructor: (name, bot) ->
    super name, bot
    @watch_id = navigator.geolocation.watchPosition ((location) => @bot.announce location: location), 
      (-> console.log "geolocation error"), enableHighAccuracy: true

# announce time has passed
class TimeAnnouncer extends Announcer
  constructor: (name, bot) ->
    super name, bot
    @interval_id = window.setInterval (=> @bot.announce timer: 1), 1000

# build my robot's state machine
# todo: low-grade location might be accepted
# todo: firefox flame phone does not reverse the compass but zte open does--detect and adjust

# extending buttonwatcher as the toplevel state so that buttons can override anything
class RobotTestMachine extends ButtonWatcher
  constructor: (@driver) ->

    # ready state responds to "stop" goal and when entered it stops the car
    super "ready", ["stop"], (oldState, currentState) => @driver.drive(0) if currentState == @

    # activities under limited should be allowed some number of seconds to complete, then aborted
    @limited = @addChild new RobotTimeLimit "limiting", [], 180

    # this state will collect the flags we put down and it's where we start when the user hits go
    @sequence = @limited.addChild new RobotSequentialState "stepping", ["go"]
    @sequence.addForward = false

    # plot a known final destination for debugging
#    @sequence.addChild new RobotFindingState(@driver, "trailhead", [], latitude: 40.460304, longitude: -111.797706)

    # hitting the store button goes here and drops a flag under the sequence state
    @limited.addChild new RobotFlaggingState @driver, "storing", "point", ["store"], @sequence

    # simply engage the motor, subject to the time limit above
    @limited.addChild new RobotState "driving", ["drive"], null, => @driver.drive 5

    # the reset button is special... it constructs a brand new state machine (with no flags)
    # and sends in the same driver for reuse
    @addChild new RobotState "resetting", ["reset"], => new RobotTestMachine(@driver)

    # shoot a picture
    @addChild new RobotPhotographingState "shooting", ["shoot"], "picture1"

bot = new StateTracker (state, event) ->
  console.log "pushed state to #{state.name}"
  lastevent = if event
    eventkey = Object.keys(event)[0]
    eventval = event[eventkey]
    " #{eventkey}:#{eventval}"
  else
    ""
  $("#set").html(state.ancestor().accordian(state, lastevent)).collapsibleset("refresh")

$ ->
  # build and wire up
  bot.setState new RobotTestMachine(new BigCar(bot, 200))
  new ButtonAnnouncer "button", bot, ["go", "stop", "store", "reset", "drive", "shoot"]
#  new CrashAnnouncer "crash", bot
  new OrientationAnnouncer "orientation", bot
  new LocationAnnouncer "location", bot
  new TimeAnnouncer "time", bot

