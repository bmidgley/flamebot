# robot states use/extend RobotState
class RobotState
  constructor: (@name, @goals=[]) ->
    @behaviors = []
    @parent = null

  # deliver event notifications and accept a resulting state change
  # events are delivered first to parent states then child states down to the current state
  # the first listener that returns a state will stop this chain and set the new current state
  listener: (currentState, event) ->
    null

  # after a state change, alert all the states in the new stack
  # to take appropriate actions when entering this or a child state
  entering: (oldState, currentState, bot) ->

  # add a child state
  addChild: (state) ->
    state.parent = @
    @behaviors.push state
    state

  # process an event
  processEvent: (currentState, event) ->
    if @parent
      newState = @parent.processEvent currentState, event
      return newState if newState
    @listener currentState, event

  enterAll: (oldState, currentState, bot) ->
    @parent.enterAll(oldState, currentState, bot) if @parent
    @entering(oldState, currentState, bot)

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

  toRadians: (r) ->
    r * Math.PI / 180.0

  toDegrees: (d) ->
    180.0 * d / Math.PI

  bearing: (a, b) ->
    lat1 = @toRadians(a.latitude)
    lat2 = @toRadians(b.latitude)
    lon1 = @toRadians(a.longitude)
    lon2 = @toRadians(b.longitude)
    y = Math.sin(lon2 - lon1) * Math.cos(lat2)
    x = Math.cos(lat1)*Math.sin(lat2) - Math.sin(lat1)*Math.cos(lat2)*Math.cos(lon2-lon1)
    @toDegrees Math.atan2(y, x)

  accordian: (target, event) ->
    collapsed = if (target != @ && @contains(target)) then "false" else "true"
    x = "<div data-role='collapsible' data-collapsed='#{collapsed}' data-theme='b'><h3>#{if target == @ then "*#{@name}#{event}" else @name}</h3>"
    for child in @behaviors
      x += child.accordian(target, event)
    x += '</div>'
    return x

# loop forever state
class RobotLoopState extends RobotState
  listener: (currentState, event) ->
    # only modify the current state if it is me
    return null if currentState != @
    @behaviors[0] || @parent

# move to each child state in sequence then move to parent state
class RobotSequentialState extends RobotState
  constructor: (name, goals) ->
    super name, goals
    @counter = -1
    
  listener: (currentState, event) ->
    # only modify the current state if it is me
    return null if currentState != @
    return @behaviors[@counter] || @parent
    
  entering: (oldState, currentState) =>
    # sequence is initialized/incremented if reached from a descendant
    # and reset if we entered from elsewhere
    return unless currentState == @
    @counter = if @contains(oldState) then @counter + 1 else 0

  addChild: (state) ->
    state.name += " #{@behaviors.length+1}"
    super state

# limit time spent on an activity
class RobotTimeLimit extends RobotState
  constructor: (name, goals, @duration) ->
    super name, goals
    @elapsed = 0
    
  listener: (currentState, event) ->
    if currentState == @
      if @contained
        return @parent
      else
        return @behaviors[0] || @parent
    if event.timer
      @elapsed += event.timer
      if @elapsed > @duration
        @elapsed = 0
        return @parent
    null

  entering: (oldState, currentState) =>
    # if the state was an ancestor before, need to reset the timer
    @contained = @contains oldState
    @elapsed = 0 unless @contained

# drive in a specified direction
class Driving extends RobotState
  constructor: (name, goals, @driver, @direction) ->
    super name, goals
  entering: (oldState, currentState) =>
    @driver.drive @direction if currentState == @

# drop a flag at the current location as a finding state and child of x
class RobotFlaggingState extends RobotState
  constructor: (@driver, name, @flagname, goals, @target) ->
    super name, goals
    
  listener: (currentState, event) ->
    if event.location
      @target.addChild new RobotFindingState(@driver, @flagname, [], event.location.coords)
      return @parent
    null

# shoot a picture and move to parent state
class RobotPhotographingState extends RobotState
  constructor: (name, goals, @filename) ->
    super name, goals
    
  listener: (currentState, event) ->
    @parent
    
  entering: (oldState, currentState) =>
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
  constructor: (@driver, @basename, goals, @location, @perimeter=3, @compass_variance=20) ->
    super @basename, goals
    @left_turning = @addChild new Driving "left", [], @driver, 5
    @right_turning = @addChild new Driving "right", [], @driver, 6

  listener: (currentState, event) ->
    # location
    if event.location
      @current_location = event.location.coords

      # finish if perimeter was broken
      distance = @distance(@current_location, @location)
      if distance < @perimeter
        return @parent

    # compass
    if event.compass
      @compass_reading = event.compass
      if @debug
        console.log "true orientation: #{@compass_reading}"
        @debug = false

    if event.timer
      @debug = false
      @debug2 = false

    newState = @

    # compare the direction with our goal direction
    d = @correction()
    if d > @compass_variance
      newState = @left_turning
    if d < -@compass_variance
      newState = @right_turning

    return null if currentState == newState
    return newState

  entering: (oldState, currentState) =>
    @driver.drive 1 if currentState == @

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
    @name = "#{@basename}#{Math.round(@compass_reading)}/#{Math.round(bearing)}/#{Math.round(relative)} #{Math.round(@distance(@current_location, @location))}m"
    if @debug2
      console.log "bearing #{bearing} from compass #{@compass_reading} off by #{relative}. #{@current_location.latitude},#{@current_location.longitude} to #{@location.latitude},#{@location.longitude} #{@distance(@current_location, @location)}m"
      @debug2 = false
    return relative

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
    super name, goals
    
  listener: (currentState, event) ->
    return @parent if event.battery && event.battery < @threshold
    return null

# base button handler and some debug
class ButtonWatcher extends RobotState
  listener: (currentState, event) ->
    return currentState.findHandler(event.button) if event.button
    #console.log("battery is now #{event.battery}") if event.battery
    return null

# indicate the compass heading
class CompassDisplay extends RobotState
  constructor: (name, goals) ->
    super name, goals
    @directions = [
      @addChild new RobotState "north"
      @addChild new RobotState "east"
      @addChild new RobotState "south"
      @addChild new RobotState "west"
      ]

  listener: (currentState, event) =>
    if event.compass
      idx = Math.floor((event.compass + 45)/90)
      direction = @directions[idx]
      return direction if currentState != direction
    null

# calibrate the compass (orientation events are not consistent between devices)
# also intercept any state below this one by first calibrating
class CompassCalibrator extends RobotSequentialState
  constructor: (name, goals, @driver) ->
    super name, goals
    @pathing = (@addChild new RobotTimeLimit "pathlimiting", [], 2).addChild new Driving "pathing", [], @driver, 1
    @turning = (@addChild new RobotTimeLimit "turnlimiting", [], 8).addChild new Driving "rightturning", [], @driver, 6
    @registering = @addChild new RobotState "registering"
    @reset()

  listener: (currentState, event) =>
    switch currentState
      when @pathing
        if event.location
          @location1 ||= event.location
          @location2 = event.location
        else if event.orientation
          @readings1.push(event.orientation)
      when @turning
        if event.orientation
          @readings2.push(event.orientation)
      when @registering
        return @
    super currentState, event

  entering: (oldState, currentState, bot) ->
    super oldState, currentState, bot
    if currentState == @registering
      @driver.drive 0
      # register the new calibrated announcer

      # normal/forward readings should have big drops as we turn clockwise pass north
      deltas = @readings2.map (v, i, a) -> v - a[(i||1)-1]
      normal_indicators = (deltas.filter (n) -> n < 300).length
      backward_indicators = (deltas.filter (n) -> n > 300).length
      factor = if normal_indicators > backward_indicators then 1 else -1

      # then see if there is an offset
      #bearing = @bearing @location1, @location2
      #reading = @average_heading @readings1
      offset = 0

      bot.addAnnouncer new CompassAnnouncer "compass", offset, factor
      @reset()

  reset: ->
    @readings1 = []
    @readings2 = []
    @location1 = null
    @location2 = null

# keep track of state
class StateTracker
  constructor: (@notifier) ->
    @announcers = {}

  # only the state argument is required
  setState: (@state, oldState, event) ->
    @state.enterAll oldState, @state, @
    @notifier(@state, event) if @notifier

  announce: (event) ->
    return unless @state
    newState = @state.processEvent(@state, event)
    @setState(newState, @state, event) if newState

  addAnnouncer: (announcer) ->
    previous = @announcers[announcer.name]
    previous.setBot null if previous
    announcer.setBot @
    @announcers[announcer.name] = announcer

# everyone needs one of these
class ImaginaryCar
  constructor: (@bot) ->

  drive: (code) ->
    console.log "drive(#{code})"
    @announce battery: 11


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
      @announce battery: data

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
      @announce battery: level

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
        console.log "sending drive #{@code}"
        steering = @steer @code
        @socket.send @code2command steering if steering
        @socket.send @code2command @code
        @socket.send @code2command steering if steering
        @code -= 1 if @code < 1
    else
      @connectSocket()
      

# Announcers deliver events to a bot
class Announcer
  constructor: (@name) ->
    console.log "Tracking #{@name} events"

  setBot: (@bot) ->

  announce: (message) ->
    @bot.announce message if @bot

# wire up the list of buttons to send corresponding events
class ButtonAnnouncer extends Announcer
  constructor: (name, buttons) ->
    super name, bot
    for action in buttons
      do (action) =>
        $("##{action}-button").click => @announce button: action

# announce a crash if the accelerometer seems to indicate it
class CrashAnnouncer extends Announcer
  constructor: (name, @magnitude = 25, @mininterval = 1000000) ->
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
        @announce crash: event
        @motionTimeStamp = event.timeStamp

# announce orentation event.{alpha,beta,gamma} where alpha is compass direction
class OrientationAnnouncer extends Announcer
  constructor: (name) ->
    super name, bot
    @orientation_id = window.addEventListener 'deviceorientation', (event) =>
      @announce orientation: event
    , true

# announce location.coords.{latitude,longitude}
class LocationAnnouncer extends Announcer
  constructor: (name) ->
    super name, bot
    @watch_id = navigator.geolocation.watchPosition ((location) => @announce location: location), 
      (-> console.log "geolocation error"), enableHighAccuracy: true

# announce time has passed
class TimeAnnouncer extends Announcer
  constructor: (name) ->
    super name, bot
    @interval_id = window.setInterval (=> @announce timer: 1), 1000

# announce calibrated compass events
class CompassAnnouncer extends Announcer
  constructor: (name, @offset = 0, @factor = 1) ->
    super name, bot
    @orientation_id = window.addEventListener 'deviceorientation', (event) =>
      adjusted = Math.floor((360 + @offset + @factor * event.alpha) % 360)
      @announce compass: adjusted
    , true

