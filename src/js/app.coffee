# build my robot's state machine

# extending buttonwatcher as the toplevel state so that buttons can override anything
class RobotTestMachine extends ButtonWatcher
  constructor: (@driver) ->
    # ready state responds to "stop" goal and when entered it stops the car
    super "ready", ["stop"]

    # activities under limited should be allowed some number of seconds to complete, then aborted
    @limited = @addChild new RobotTimeLimit "limiting", [], 600

    # this state will collect the flags we put down and it's where we start when the user hits go
    @sequence = @limited.addChild new RobotSequentialState "stepping", ["go"]

    # plot a known final destination for debugging
    #@sequence.addChild new RobotFindingState "trailhead", [], new Steering(@driver), latitude: 40.460304, longitude: -111.797706

    # hitting the store button goes here and drops a flag under the sequence state
    @limited.addChild new RobotFlaggingState "storing", ["store"],
      (coords) => @sequence.addChild new RobotFindingState "p", [], new Steering(@driver), coords

    # simply engage the motor, subject to the time limit above
    @driving = @limited.addChild new Driving "driving", ["drive"], @driver, 5

    # the reset button is special... it constructs a brand new state machine (with no flags)
    # and sends in the same driver for reuse
    @resetting = @addChild new RobotState "resetting", ["reset"]

    # shoot a picture
    @addChild new RobotPhotographingState "shooting", ["shoot"], "picture1"

    # calibrate compass
    @addChild new CompassCalibrator "calibrating", ["calibrate"], @driver

    # display compass
    @addChild new CompassDisplay "compass", ["compass"]

  listener: (currentState, event) =>
    if currentState == @resetting
      return new RobotTestMachine @driver
    else
      return super currentState, event

  entering: (oldState, currentState) =>
    if currentState == @
      @driver.drive 0

timer_id = null
bot = new StateTracker (state, event) ->
  # this code is run each time the state changes
  # useful for displaying the current state machine and for debugging
  # event caused the last state change
  console.log "now #{state.fullName()}"
  lastevent = if event
    eventkey = Object.keys(event)[0]
    eventval = event[eventkey]
    " #{eventkey}:#{eventval}"
  else
    ""
  html = state.ancestor().accordian(state, lastevent)
  clearTimeout timer_id
  timer_id = setTimeout ((html) -> $("#set").html(html).collapsibleset("refresh")), 1000, html

$ ->
  # build and wire up
  bot.setState new RobotTestMachine(new BigCar(bot, 200))
  bot.addAnnouncer new ButtonAnnouncer "button", ["go", "stop", "store", "reset", "drive", "shoot", "calibrate", "compass"]
  bot.addAnnouncer new CrashAnnouncer "crash"
  bot.addAnnouncer new OrientationAnnouncer "orientation"
  bot.addAnnouncer new LocationAnnouncer "location"
  bot.addAnnouncer new TimeAnnouncer "time"

