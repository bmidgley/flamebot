# robot states use/extend RoboDoing
class RoboDoing
  constructor: (@name, @goals=[]) ->
    @behaviors = []
    @parent = null

  # deliver event notifications and accept a resulting state change
  # events are delivered first to parent states then child states down to the current state
  # the first listener that returns a state will stop this chain and set the new current state
  listener: (currentState, event, bot) ->
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
  processEvent: (currentState, event, bot) ->
    if @parent
      newState = @parent.processEvent currentState, event, bot
      return newState if newState
    @listener currentState, event, bot

  # find the most specific behavior that responds to a message
  responseTo: (property, args=[]) ->
    return @[property](args...) if @[property]
    return @parent.responseTo(property, args) if @parent
    return null

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

  fullName: ->
    if @parent then "#{@parent.fullName()}/#{@name}" else @name

# loop forever state
class RoboLooping extends RoboDoing
  listener: (currentState, event) ->
    # only modify the current state if it is me
    return null if currentState != @
    @behaviors[0] || @parent

# loop n times state
class RoboCounting extends RoboDoing
  constructor: (name, goals, @limit) ->
    super name, goals

  listener: (currentState, event) ->
    return null unless currentState == @
    return @behaviors[0] if @counter < @limit
    return @parent

  entering: (oldState, currentState) =>
    return unless currentState == @
    @counter = if @contains(oldState) then @counter + 1 else 0

# move to each child state in sequence then move to parent state
class RoboSequencing extends RoboDoing
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
class RoboTiming extends RoboDoing
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

# interrupt something but then return after the interrupt activity finishes
# activity must be a child so we get notified when it's entered
# interrupt must be a child so we get an enter message when it finishes
class RoboInterrupting extends RoboDoing
  constructor: (name, goals, @activity, @interrupt, @interruptWhen) ->
    super name, goals
    @addChild @activity
    @addChild @interrupt
    @next = []
    @prev = []

  listener: ->
    @next.pop()

  entering: (oldState, currentState, bot) ->
    if currentState == @
      @next = if @activity.contains oldState
        [@parent]
      else
        [@prev.pop() || @activity]
    else
      if @activity.contains(currentState) && @interruptWhen(bot)
        @next = [@interrupt]
        @prev = [currentState]

# drive in a specified direction
class RoboDriving extends RoboDoing
  constructor: (name, goals, @driver, @direction) ->
    super name, goals
  entering: (oldState, currentState) =>
    @driver.drive @direction if currentState == @

# drop a flag at the current location as a finding state and child of x
class RoboFlagging extends RoboDoing
  constructor: (name, goals, @flagfactory) ->
    super name, goals
    
  listener: (currentState, event) =>
    if event.location
      @flagfactory event.location.coords
      return @parent
    null

# shoot a picture and move to parent state
class RoboPhotographing extends RoboDoing
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

# basic steering strategy
class RoboSteering extends RoboDriving
  constructor: (driver) ->
    super "steering", [], driver, 1
    @left_turning = @addChild new RoboDriving "left", [], driver, 5
    @right_turning = @addChild new RoboDriving "right", [], driver, 6

  listener: (currentState, event) ->
    # compare the direction with our goal direction
    d = event.correction
    return null unless d

    newState = if d > @compass_variance
      @left_turning
    else if d < -@compass_variance
      @right_turning
    else
      @

    return if currentState == newState then null else newState

# go to the location specified and then move to parent state
class RoboFinding extends RoboDoing
  constructor: (@basename, goals, strategy, @location, @perimeter=3, @compass_variance=20) ->
    super @basename, goals
    @addChild strategy if strategy

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

    # activate the strategy
    return if currentState == @ then @behaviors[0] else null

  toRadians: (r) ->
    r * Math.PI / 180.0

  toDegrees: (d) ->
    180.0 * d / Math.PI

  correction: ->
    # return event with signed degree measurement needed to course correct
    # return empty object if we don't know which way we need to turn
    return {} unless @compass_reading && @current_location
    bearing = @bearing @current_location, @location
    relative = ((360 + @compass_reading - bearing) % 360)
    relative -= 360 if relative > 180
    @name = "#{@basename}#{Math.round(@compass_reading)}/#{Math.round(bearing)}/#{Math.round(relative)} #{Math.round(@distance(@current_location, @location))}m"
    return correction: relative

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
class RoboBatteryWatching extends RoboDoing
  constructor: (name, goals, @threshold) ->
    super name, goals
    
  listener: (currentState, event) ->
    return @parent if event.battery && event.battery < @threshold
    return null

# base button handler
class RoboButtonWatching extends RoboDoing
  listener: (currentState, event) ->
    return currentState.findHandler(event.button) if event.button
    return null

# indicate the compass heading
class RoboCompassDisplaying extends RoboDoing
  constructor: (name, goals) ->
    super name, goals
    @directions = [
      @addChild new RoboDoing "north"
      @addChild new RoboDoing "east"
      @addChild new RoboDoing "south"
      @addChild new RoboDoing "west"
      ]

  listener: (currentState, event) =>
    if event.compass
      idx = Math.floor((event.compass + 45)/90)
      direction = @directions[idx]
      return direction if currentState != direction
    null

# calibrate the compass (orientation events are not consistent between devices)
class RoboCompassCalibrating extends RoboSequencing
  constructor: (name, goals, @driver) ->
    super name, goals
    @pathing = (@addChild new RoboTiming "pathlimiting", [], 2).addChild new RoboDriving "pathing", [], @driver, 1
    @turning = (@addChild new RoboTiming "turnlimiting", [], 8).addChild new RoboDriving "rightturning", [], @driver, 6
    @registering = @addChild new RoboDoing "registering"
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

      # normal/forward readings should have big drops as we turned clockwise passing north
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


# keep track of running a robot
class Bot
  constructor: (@notifier) ->
    @announcers = {}

  # only the state argument is required
  setState: (@state, oldState, event) ->
    @state.enterAll oldState, @state, @
    @notifier(@state, event) if @notifier

  announce: (event) ->
    return unless @state
    newState = @state.processEvent @state, event, @
    @setState(newState, @state, event) if newState

  addAnnouncer: (announcer) ->
    previous = @announcers[announcer.name]
    previous.setBot null if previous
    announcer.setBot @
    @announcers[announcer.name] = announcer


# base car driver
class Car
  constructor: (@bot) ->

  drive: (code) ->
    console.log "drive(#{code})"
    @announce battery: 11
    
  announce: (msg) ->
    @bot.announce msg

# LittleCar aka iRacer
# LittleCar depends on a helper to bridge to bluetooth
# adb shell
# rfcomm bind hci0 00:12:05:09:97:47 1
# while true; do
#  request=`echo -e -n "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\n\r\n99" | nc -l -p 8080`
#  echo -e -n "\x${request:5:2}"
#done >/dev/rfcomm0
class LittleCar extends Car
  constructor: (@bot) ->
    $.ajaxSetup xhr: -> new window.XMLHttpRequest mozSystem: true

  drive: (code, speed=15) ->
    $.ajax 'http://localhost:8080/' + code + speed.toString(16), type: 'GET', dataType: 'html', success: (data) =>
      @announce battery: data

# BigCar aka Brookstone's Wifi Racer
# BigCar depends on the user to connect the phone to the car's wifi access point
class BigCar extends Car
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
      

# Announcer delivers events to a bot
class Announcer
  constructor: (@name) ->
    console.log "Tracking #{@name} events"

  setBot: (@bot) ->

  announce: (message) ->
    @bot.announce message if @bot

  announceResponse: (property, args=[]) ->
    if @bot && @bot.currentState
      @announce @bot.currentState.responseTo property, args

# wire up the list of buttons to send corresponding events
class ButtonAnnouncer extends Announcer
  constructor: (name, buttons) ->
    super name
    for action in buttons
      do (action) =>
        $("##{action}-button").click => @announce button: action

# announce a crash if the accelerometer seems to indicate it
class CrashAnnouncer extends Announcer
  constructor: (name, @magnitude = 25, @mininterval = 1000000) ->
    super name
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
    super name
    @orientation_id = window.addEventListener 'deviceorientation', (event) =>
      @announce orientation: event
    , true

# announce course corrections
class CorrectionAnnouncer extends Announcer
  constructor: (name) ->
    super name
    @interval_id = window.setInterval (=> @announceResponse "correction"), 1000

# announce location.coords.{latitude,longitude}
class LocationAnnouncer extends Announcer
  constructor: (name) ->
    super name
    @watch_id = navigator.geolocation.watchPosition ((location) => @announce location: location), 
      (-> console.log "geolocation error"), enableHighAccuracy: true

# announce time has passed
class TimeAnnouncer extends Announcer
  constructor: (name) ->
    super name
    @interval_id = window.setInterval (=> @announce timer: 1), 1000

# announce calibrated compass events
class CompassAnnouncer extends Announcer
  constructor: (name, @offset = 0, @factor = 1) ->
    super name
    @orientation_id = window.addEventListener 'deviceorientation', (event) =>
      adjusted = Math.floor((360 + @offset + @factor * event.alpha) % 360)
      @announce compass: adjusted
    , true

