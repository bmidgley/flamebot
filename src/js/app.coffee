# build my robot's state machine

# extending buttonwatching as the toplevel state so that buttons can override anything
class RoboRacing extends RoboButtonWatching
  constructor: (@driver) ->
    # ready state responds to "stop" goal and when entered it stops the car
    super "ready", ["stop"]

    # activities under limited should be allowed some number of seconds to complete, then aborted
    @limited = @addChild new RoboTiming "limiting", [], 180

    # this state will collect the flags we put down and it's where we start when the user hits go
    @sequence = new RoboSequencing "stepping", ["go"]

    # make sure compass has been calibrated before running through the sequence
    @calibrator = new RoboCompassCalibrating "auto compass calibrating", [], @driver
    @limited.addChild new RoboInterrupting "require calibrated compass", [], @sequence, @calibrator,
      (bot) -> !bot.announcers.compass

    # plot a known final destination for debugging
    #@sequence.addChild new RoboFinding "trailhead", [], new RoboSteering(@driver), latitude: 40.460304, longitude: -111.797706

    # hitting the store button goes here and drops a flag under the sequence state
    @limited.addChild new RoboFlagging "storing", ["store"],
      (coords) => @sequence.addChild new RoboFinding "p", [], new RoboSteering(@driver), coords

    # simply engage the motor, subject to the time limit above
    @driving = @limited.addChild new RoboDriving "driving", ["drive"], @driver, 5

    # the reset button is special... it constructs a brand new state machine (with no flags)
    # and sends in the same driver for reuse
    @resetting = @addChild new RoboDoing "resetting", ["reset"]

    # shoot a picture
    @addChild new RoboPhotographing "shooting", ["shoot"], "picture1"

    # manually calibrate compass
    @addChild new RoboCompassCalibrating "compass calibrating", ["calibrate"], @driver

    # display compass
    @addChild new RoboCompassDisplaying "compass", ["compass"]

  listener: (currentState, event) =>
    if currentState == @resetting
      return new RoboRacing @driver
    else
      return super currentState, event

  entering: (oldState, currentState) =>
    if currentState == @
      @driver.drive 0

timer_id = null
bot = new Bot (state, event) ->
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
  bot.setState new RoboRacing(new BigCar(bot, 200))
  bot.addAnnouncer new ButtonAnnouncer "button", ["go", "stop", "store", "reset", "drive", "shoot", "calibrate", "compass"]
  bot.addAnnouncer new CrashAnnouncer "crash"
  bot.addAnnouncer new OrientationAnnouncer "orientation"
  bot.addAnnouncer new LocationAnnouncer "location"
  bot.addAnnouncer new TimeAnnouncer "time"
  bot.addAnnouncer new CorrectionAnnouncer "correction"
  bot.addAnnouncer new BroadcastAnnouncer "broadcasts"
