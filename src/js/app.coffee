# build my robot's state machine

# Enhance RoboFinding to keep searching until our success is broadcast
RoboGameFinding = class extends RoboFinding
  listener: (currentState, event, bot) ->
    newState = super currentState, event, bot
    if event.broadcast
      game = event.broadcast.game
      if game && game.reached
        return @parent.behaviors[game.reached]
    # broadcast when we think we reached the goal, but don't think we've finished yet
    if newState == @parent    
      bot.broadcast game: {location: @current_location}
    return null

# add hooks to announce game results when finishing
RoboGameClock = class extends RoboTiming
  completed: (bot) ->
    bot.broadcast game: {running: false, won: true, elapsed: @elapsed}

  alarmed: (bot) ->
    bot.broadcast game: {running: false, won: false, elapsed: @elapsed}

# respond to a bot reaching the goal in a game
RoboGameFinding = class extends RoboFinding
  listener: (currentState, event, bot) ->
    broadcast = event.broadcast
    if broadcast && broadcast.game
      game = broadcast.game
      if game.location
        # advance if perimeter was broken
        distance = @distance(game.location.coords, @location)
        if distance < @perimeter
          next = 1 + (@ in @parent.behaviors)
          bot.broadcast game: {running: true, sender: broadcast.sender, next: next}
          return @parent
    return null

# run a game using the current set of flags
RoboGaming = class extends RoboSequencing
  constructor: (name, goals, @copyFrom) ->
    super(name, goals)

  entering: (oldState, currentState, bot) ->
    if currentState == @ && !@contains(oldState)
      @behaviors = []
      for flag in @copyFrom.behaviors
        @addChild new RoboGameFinding flag.basename, [], null, flag.location
      bot.broadcast game: {running: true, flags: item.location for item in @copyFrom.behaviors}

# ready state for participating in the game
RoboPlaying = class extends RoboDoing
  constructor: (name, goals, @sequence) ->
    super(name, goals)

  listener: (currentState, event) ->
    return null unless event.broadcast && event.broadcast.game && event.broadcast.game.flags

    # someone (?) just started a game!!
    # clear our flags, set them using the custom finder, and set it as the new current state
    @sequence.behaviors = []
    for location in event.broadcast.game.flags
      @sequence.addChild new RoboGameFinding "game", [], new RoboSteering(@driver), location
    return @sequence


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

    # run game
    @playing = @addChild new RoboSequencing "playing", ["play"]
    @playing.addChild new RoboFlagging "homebasing", [],
      (coords) => @playing.behaviors[3] = new RoboFinding "home", [], new RoboSteering(@driver), coords
    @playing.addChild new RoboTiming "gamelimit", [], 180
    @gaming = @addChild new RoboGameClock "gaming", ["game"], 180
    @gaming.addChild new RoboGaming "gamesequencing", [], @sequence

    @playing = @addChild new RoboPlaying "playing", ["play"], @sequence

  listener: (currentState, event) ->
    if currentState == @resetting
      return new RoboRacing @driver
    else
      return super currentState, event

  entering: (oldState, currentState, bot) ->
    if currentState == @
      @driver.drive 0
      bot.broadcast game: {running: false}

timerId = null
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
  clearTimeout timerId
  timerId = setTimeout ((html) -> $("#set").html(html).collapsibleset("refresh")), 1000, html

$ ->
  # build and wire up
  bot.setState new RoboRacing(new LittleCar(bot))
  bot.addAnnouncer new ButtonAnnouncer "button", ["go", "stop", "store", "reset", "drive", "shoot", "calibrate", "compass", "game", "play"]
  bot.addAnnouncer new CrashAnnouncer "crash"
  bot.addAnnouncer new OrientationAnnouncer "orientation"
  bot.addAnnouncer new LocationAnnouncer "location"
  bot.addAnnouncer new TimeAnnouncer "time"
  bot.addAnnouncer new CorrectionAnnouncer "correction"
  bot.addAnnouncer new BroadcastAnnouncer "broadcasts"
