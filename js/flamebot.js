// Generated by CoffeeScript 1.8.0
var Announcer, BigCar, Bot, ButtonAnnouncer, Car, CompassAnnouncer, CorrectionAnnouncer, CrashAnnouncer, LittleCar, LocationAnnouncer, OrientationAnnouncer, RoboBatteryWatching, RoboButtonWatching, RoboCompassCalibrating, RoboCompassDisplaying, RoboCounting, RoboDoing, RoboDriving, RoboFinding, RoboFlagging, RoboInterrupting, RoboLooping, RoboPhotographing, RoboSequencing, RoboSteering, RoboTiming, TimeAnnouncer,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

RoboDoing = (function() {
  function RoboDoing(name, goals) {
    this.name = name;
    this.goals = goals != null ? goals : [];
    this.behaviors = [];
    this.parent = null;
  }

  RoboDoing.prototype.listener = function(currentState, event, bot) {
    return null;
  };

  RoboDoing.prototype.entering = function(oldState, currentState, bot) {};

  RoboDoing.prototype.addChild = function(state) {
    state.parent = this;
    this.behaviors.push(state);
    return state;
  };

  RoboDoing.prototype.processEvent = function(currentState, event, bot) {
    var newState;
    if (this.parent) {
      newState = this.parent.processEvent(currentState, event, bot);
      if (newState) {
        return newState;
      }
    }
    return this.listener(currentState, event, bot);
  };

  RoboDoing.prototype.responseTo = function(property, args) {
    if (args == null) {
      args = [];
    }
    if (this[property]) {
      return this[property].apply(this, args);
    }
    if (this.parent) {
      return this.parent.responseTo(property, args);
    }
    return null;
  };

  RoboDoing.prototype.enterAll = function(oldState, currentState, bot) {
    if (this.parent) {
      this.parent.enterAll(oldState, currentState, bot);
    }
    return this.entering(oldState, currentState, bot);
  };

  RoboDoing.prototype.findHandler = function(goal) {
    return this.ancestor().findHandlerR(goal);
  };

  RoboDoing.prototype.findHandlerR = function(goal) {
    var behavior, found, _i, _len, _ref;
    if (__indexOf.call(this.goals, goal) >= 0) {
      return this;
    }
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      behavior = _ref[_i];
      found = behavior.findHandlerR(goal);
      if (found) {
        return found;
      }
    }
    return null;
  };

  RoboDoing.prototype.ancestor = function() {
    if (!this.parent) {
      return this;
    }
    return this.parent.ancestor();
  };

  RoboDoing.prototype.contains = function(target) {
    var child, _i, _len, _ref;
    if (target === this) {
      return true;
    }
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      if (child.contains(target)) {
        return true;
      }
    }
    return false;
  };

  RoboDoing.prototype.toRadians = function(r) {
    return r * Math.PI / 180.0;
  };

  RoboDoing.prototype.toDegrees = function(d) {
    return 180.0 * d / Math.PI;
  };

  RoboDoing.prototype.bearing = function(a, b) {
    var lat1, lat2, lon1, lon2, x, y;
    lat1 = this.toRadians(a.latitude);
    lat2 = this.toRadians(b.latitude);
    lon1 = this.toRadians(a.longitude);
    lon2 = this.toRadians(b.longitude);
    y = Math.sin(lon2 - lon1) * Math.cos(lat2);
    x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(lon2 - lon1);
    return this.toDegrees(Math.atan2(y, x));
  };

  RoboDoing.prototype.accordian = function(target, event) {
    var child, collapsed, x, _i, _len, _ref;
    collapsed = target !== this && this.contains(target) ? "false" : "true";
    x = "<div data-role='collapsible' data-collapsed='" + collapsed + "' data-theme='b'><h3>" + (target === this ? "*" + this.name + event : this.name) + "</h3>";
    _ref = this.behaviors;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      x += child.accordian(target, event);
    }
    x += '</div>';
    return x;
  };

  RoboDoing.prototype.fullName = function() {
    if (this.parent) {
      return "" + (this.parent.fullName()) + "/" + this.name;
    } else {
      return this.name;
    }
  };

  return RoboDoing;

})();

RoboLooping = (function(_super) {
  __extends(RoboLooping, _super);

  function RoboLooping() {
    return RoboLooping.__super__.constructor.apply(this, arguments);
  }

  RoboLooping.prototype.listener = function(currentState, event) {
    if (currentState !== this) {
      return null;
    }
    return this.behaviors[0] || this.parent;
  };

  return RoboLooping;

})(RoboDoing);

RoboCounting = (function(_super) {
  __extends(RoboCounting, _super);

  function RoboCounting(name, goals, limit) {
    this.limit = limit;
    this.entering = __bind(this.entering, this);
    RoboCounting.__super__.constructor.call(this, name, goals);
  }

  RoboCounting.prototype.listener = function(currentState, event) {
    if (currentState !== this) {
      return null;
    }
    if (this.counter < this.limit) {
      return this.behaviors[0];
    }
    return this.parent;
  };

  RoboCounting.prototype.entering = function(oldState, currentState) {
    if (currentState !== this) {
      return;
    }
    return this.counter = this.contains(oldState) ? this.counter + 1 : 0;
  };

  return RoboCounting;

})(RoboDoing);

RoboSequencing = (function(_super) {
  __extends(RoboSequencing, _super);

  function RoboSequencing(name, goals) {
    this.entering = __bind(this.entering, this);
    RoboSequencing.__super__.constructor.call(this, name, goals);
    this.counter = -1;
  }

  RoboSequencing.prototype.listener = function(currentState, event) {
    if (currentState !== this) {
      return null;
    }
    return this.behaviors[this.counter] || this.parent;
  };

  RoboSequencing.prototype.entering = function(oldState, currentState) {
    if (currentState !== this) {
      return;
    }
    return this.counter = this.contains(oldState) ? this.counter + 1 : 0;
  };

  RoboSequencing.prototype.addChild = function(state) {
    state.name += " " + (this.behaviors.length + 1);
    return RoboSequencing.__super__.addChild.call(this, state);
  };

  return RoboSequencing;

})(RoboDoing);

RoboTiming = (function(_super) {
  __extends(RoboTiming, _super);

  function RoboTiming(name, goals, duration) {
    this.duration = duration;
    this.entering = __bind(this.entering, this);
    RoboTiming.__super__.constructor.call(this, name, goals);
    this.elapsed = 0;
  }

  RoboTiming.prototype.listener = function(currentState, event) {
    if (currentState === this) {
      if (this.contained) {
        return this.parent;
      } else {
        return this.behaviors[0] || this.parent;
      }
    }
    if (event.timer) {
      this.elapsed += event.timer;
      if (this.elapsed > this.duration) {
        this.elapsed = 0;
        return this.parent;
      }
    }
    return null;
  };

  RoboTiming.prototype.entering = function(oldState, currentState) {
    this.contained = this.contains(oldState);
    if (!this.contained) {
      return this.elapsed = 0;
    }
  };

  return RoboTiming;

})(RoboDoing);

RoboInterrupting = (function(_super) {
  __extends(RoboInterrupting, _super);

  function RoboInterrupting(name, goals, activity, interrupt, interruptWhen) {
    this.activity = activity;
    this.interrupt = interrupt;
    this.interruptWhen = interruptWhen;
    RoboInterrupting.__super__.constructor.call(this, name, goals);
    this.addChild(this.activity);
    this.addChild(this.interrupt);
    this.next = [];
    this.prev = [];
  }

  RoboInterrupting.prototype.listener = function() {
    return this.next.pop();
  };

  RoboInterrupting.prototype.entering = function(oldState, currentState, bot) {
    if (currentState === this) {
      return this.next = this.activity.contains(oldState) ? [this.parent] : [this.prev.pop() || this.activity];
    } else {
      if (this.activity.contains(currentState) && this.interruptWhen(bot)) {
        this.next = [this.interrupt];
        return this.prev = [currentState];
      }
    }
  };

  return RoboInterrupting;

})(RoboDoing);

RoboDriving = (function(_super) {
  __extends(RoboDriving, _super);

  function RoboDriving(name, goals, driver, direction) {
    this.driver = driver;
    this.direction = direction;
    this.entering = __bind(this.entering, this);
    RoboDriving.__super__.constructor.call(this, name, goals);
  }

  RoboDriving.prototype.entering = function(oldState, currentState) {
    if (currentState === this) {
      return this.driver.drive(this.direction);
    }
  };

  return RoboDriving;

})(RoboDoing);

RoboFlagging = (function(_super) {
  __extends(RoboFlagging, _super);

  function RoboFlagging(name, goals, flagfactory) {
    this.flagfactory = flagfactory;
    this.listener = __bind(this.listener, this);
    RoboFlagging.__super__.constructor.call(this, name, goals);
  }

  RoboFlagging.prototype.listener = function(currentState, event) {
    if (event.location) {
      this.flagfactory(event.location.coords);
      return this.parent;
    }
    return null;
  };

  return RoboFlagging;

})(RoboDoing);

RoboPhotographing = (function(_super) {
  __extends(RoboPhotographing, _super);

  function RoboPhotographing(name, goals, filename) {
    this.filename = filename;
    this.entering = __bind(this.entering, this);
    RoboPhotographing.__super__.constructor.call(this, name, goals);
  }

  RoboPhotographing.prototype.listener = function(currentState, event) {
    return this.parent;
  };

  RoboPhotographing.prototype.entering = function(oldState, currentState) {
    var cname, options;
    if (currentState !== this) {
      return;
    }
    cname = navigator.mozCameras.getListOfCameras()[0];
    options = {
      camera: cname
    };
    console.log("selected Camera: " + cname);
    return navigator.mozCameras.getCamera(options, (function(_this) {
      return function(camera) {
        var poptions;
        console.log(camera);
        poptions = {
          rotation: 90,
          pictureSize: camera.capabilities.pictureSizes[0],
          fileFormat: camera.capabilities.fileFormats[0]
        };
        console.log(poptions);
        return camera.takePicture(poptions, function(blob) {
          console.log(blob);
          return navigator.getDeviceStorage('pictures').addNamed(blob, _this.filename);
        });
      };
    })(this), function(e) {
      return console.log(e);
    });
  };

  return RoboPhotographing;

})(RoboDoing);

RoboSteering = (function(_super) {
  __extends(RoboSteering, _super);

  function RoboSteering(driver) {
    RoboSteering.__super__.constructor.call(this, "steering", [], driver, 1);
    this.left_turning = this.addChild(new RoboDriving("left", [], driver, 5));
    this.right_turning = this.addChild(new RoboDriving("right", [], driver, 6));
  }

  RoboSteering.prototype.listener = function(currentState, event) {
    var d, newState;
    d = event.correction;
    if (!d) {
      return null;
    }
    newState = d > this.compass_variance ? this.left_turning : d < -this.compass_variance ? this.right_turning : this;
    if (currentState === newState) {
      return null;
    } else {
      return newState;
    }
  };

  return RoboSteering;

})(RoboDriving);

RoboFinding = (function(_super) {
  __extends(RoboFinding, _super);

  function RoboFinding(basename, goals, strategy, location, perimeter, compass_variance) {
    this.basename = basename;
    this.location = location;
    this.perimeter = perimeter != null ? perimeter : 3;
    this.compass_variance = compass_variance != null ? compass_variance : 20;
    RoboFinding.__super__.constructor.call(this, this.basename, goals);
    if (strategy) {
      this.addChild(strategy);
    }
  }

  RoboFinding.prototype.listener = function(currentState, event) {
    var distance;
    if (event.location) {
      this.current_location = event.location.coords;
      distance = this.distance(this.current_location, this.location);
      if (distance < this.perimeter) {
        return this.parent;
      }
    }
    if (event.compass) {
      this.compass_reading = event.compass;
    }
    if (currentState === this) {
      return this.behaviors[0];
    } else {
      return null;
    }
  };

  RoboFinding.prototype.toRadians = function(r) {
    return r * Math.PI / 180.0;
  };

  RoboFinding.prototype.toDegrees = function(d) {
    return 180.0 * d / Math.PI;
  };

  RoboFinding.prototype.correction = function() {
    var bearing, relative;
    if (!(this.compass_reading && this.current_location)) {
      return {};
    }
    bearing = this.bearing(this.current_location, this.location);
    relative = (360 + this.compass_reading - bearing) % 360;
    if (relative > 180) {
      relative -= 360;
    }
    this.name = "" + this.basename + (Math.round(this.compass_reading)) + "/" + (Math.round(bearing)) + "/" + (Math.round(relative)) + " " + (Math.round(this.distance(this.current_location, this.location))) + "m";
    return {
      correction: relative
    };
  };

  RoboFinding.prototype.distance = function(a, b, r) {
    var d, lat1, lat2, lon1, lon2, n;
    if (r == null) {
      r = 6371000;
    }
    lat1 = this.toRadians(a.latitude);
    lat2 = this.toRadians(b.latitude);
    lon1 = this.toRadians(a.longitude);
    lon2 = this.toRadians(b.longitude);
    n = (Math.pow(Math.sin((lat2 - lat1) / 2), 2)) + Math.cos(lat1) * Math.cos(lat2) * (Math.pow(Math.sin((lon2 - lon1) / 2), 2));
    d = 2 * r * Math.atan2(Math.sqrt(n), Math.sqrt(1 - n));
    return d;
  };

  return RoboFinding;

})(RoboDoing);

RoboBatteryWatching = (function(_super) {
  __extends(RoboBatteryWatching, _super);

  function RoboBatteryWatching(name, goals, threshold) {
    this.threshold = threshold;
    RoboBatteryWatching.__super__.constructor.call(this, name, goals);
  }

  RoboBatteryWatching.prototype.listener = function(currentState, event) {
    if (event.battery && event.battery < this.threshold) {
      return this.parent;
    }
    return null;
  };

  return RoboBatteryWatching;

})(RoboDoing);

RoboButtonWatching = (function(_super) {
  __extends(RoboButtonWatching, _super);

  function RoboButtonWatching() {
    return RoboButtonWatching.__super__.constructor.apply(this, arguments);
  }

  RoboButtonWatching.prototype.listener = function(currentState, event) {
    if (event.button) {
      return currentState.findHandler(event.button);
    }
    return null;
  };

  return RoboButtonWatching;

})(RoboDoing);

RoboCompassDisplaying = (function(_super) {
  __extends(RoboCompassDisplaying, _super);

  function RoboCompassDisplaying(name, goals) {
    this.listener = __bind(this.listener, this);
    RoboCompassDisplaying.__super__.constructor.call(this, name, goals);
    this.directions = [this.addChild(new RoboDoing("north")), this.addChild(new RoboDoing("east")), this.addChild(new RoboDoing("south")), this.addChild(new RoboDoing("west"))];
  }

  RoboCompassDisplaying.prototype.listener = function(currentState, event) {
    var direction, idx;
    if (event.compass) {
      idx = Math.floor((event.compass + 45) / 90);
      direction = this.directions[idx];
      if (currentState !== direction) {
        return direction;
      }
    }
    return null;
  };

  return RoboCompassDisplaying;

})(RoboDoing);

RoboCompassCalibrating = (function(_super) {
  __extends(RoboCompassCalibrating, _super);

  function RoboCompassCalibrating(name, goals, driver) {
    this.driver = driver;
    this.listener = __bind(this.listener, this);
    RoboCompassCalibrating.__super__.constructor.call(this, name, goals);
    this.pathing = (this.addChild(new RoboTiming("pathlimiting", [], 2))).addChild(new RoboDriving("pathing", [], this.driver, 1));
    this.turning = (this.addChild(new RoboTiming("turnlimiting", [], 8))).addChild(new RoboDriving("rightturning", [], this.driver, 6));
    this.registering = this.addChild(new RoboDoing("registering"));
    this.reset();
  }

  RoboCompassCalibrating.prototype.listener = function(currentState, event) {
    switch (currentState) {
      case this.pathing:
        if (event.location) {
          this.location1 || (this.location1 = event.location);
          this.location2 = event.location;
        } else if (event.orientation) {
          this.readings1.push(event.orientation);
        }
        break;
      case this.turning:
        if (event.orientation) {
          this.readings2.push(event.orientation);
        }
        break;
      case this.registering:
        return this;
    }
    return RoboCompassCalibrating.__super__.listener.call(this, currentState, event);
  };

  RoboCompassCalibrating.prototype.entering = function(oldState, currentState, bot) {
    var backward_indicators, deltas, factor, normal_indicators, offset;
    RoboCompassCalibrating.__super__.entering.call(this, oldState, currentState, bot);
    if (currentState === this.registering) {
      this.driver.drive(0);
      deltas = this.readings2.map(function(v, i, a) {
        return v - a[(i || 1) - 1];
      });
      normal_indicators = (deltas.filter(function(n) {
        return n < 300;
      })).length;
      backward_indicators = (deltas.filter(function(n) {
        return n > 300;
      })).length;
      factor = normal_indicators > backward_indicators ? 1 : -1;
      offset = 0;
      bot.addAnnouncer(new CompassAnnouncer("compass", offset, factor));
      return this.reset();
    }
  };

  RoboCompassCalibrating.prototype.reset = function() {
    this.readings1 = [];
    this.readings2 = [];
    this.location1 = null;
    return this.location2 = null;
  };

  return RoboCompassCalibrating;

})(RoboSequencing);

Bot = (function() {
  function Bot(notifier) {
    this.notifier = notifier;
    this.announcers = {};
  }

  Bot.prototype.setState = function(state, oldState, event) {
    this.state = state;
    this.state.enterAll(oldState, this.state, this);
    if (this.notifier) {
      return this.notifier(this.state, event);
    }
  };

  Bot.prototype.announce = function(event) {
    var newState;
    if (!this.state) {
      return;
    }
    newState = this.state.processEvent(this.state, event, this);
    if (newState) {
      return this.setState(newState, this.state, event);
    }
  };

  Bot.prototype.addAnnouncer = function(announcer) {
    var previous;
    previous = this.announcers[announcer.name];
    if (previous) {
      previous.setBot(null);
    }
    announcer.setBot(this);
    return this.announcers[announcer.name] = announcer;
  };

  return Bot;

})();

Car = (function() {
  function Car(bot) {
    this.bot = bot;
  }

  Car.prototype.drive = function(code) {
    console.log("drive(" + code + ")");
    return this.announce({
      battery: 11
    });
  };

  Car.prototype.announce = function(msg) {
    return this.bot.announce(msg);
  };

  return Car;

})();

LittleCar = (function(_super) {
  __extends(LittleCar, _super);

  function LittleCar(bot) {
    this.bot = bot;
    $.ajaxSetup({
      xhr: function() {
        return new window.XMLHttpRequest({
          mozSystem: true
        });
      }
    });
  }

  LittleCar.prototype.drive = function(code, speed) {
    if (speed == null) {
      speed = 15;
    }
    return $.ajax('http://localhost:8080/' + code + speed.toString(16), {
      type: 'GET',
      dataType: 'html',
      success: (function(_this) {
        return function(data) {
          return _this.announce({
            battery: data
          });
        };
      })(this)
    });
  };

  return LittleCar;

})(Car);

BigCar = (function(_super) {
  __extends(BigCar, _super);

  function BigCar(bot, pace, address, port) {
    this.bot = bot;
    this.pace = pace != null ? pace : 250;
    this.address = address != null ? address : "192.168.2.3";
    this.port = port != null ? port : 9000;
    this.connecting = false;
    this.connectSocket();
    this.code = 0;
    window.setInterval(((function(_this) {
      return function() {
        return _this.nextCode();
      };
    })(this)), this.pace);
  }

  BigCar.prototype.connectSocket = function() {
    var error;
    if (this.connecting) {
      return;
    }
    try {
      this.socket = navigator.mozTCPSocket.open(this.address, this.port);
    } catch (_error) {
      error = _error;
      if (this.warned) {
        return;
      }
      console.log("cannot open a tcp socket");
      console.log(error);
      this.warned = true;
      return;
    }
    this.connecting = true;
    this.socket.onopen = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    this.socket.onerror = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    this.socket.onclose = (function(_this) {
      return function() {
        return _this.connecting = false;
      };
    })(this);
    return this.socket.ondata = (function(_this) {
      return function(event) {
        var level;
        level = (parseInt(event.data.slice(2), 16) - 2655) * 0.20;
        return _this.announce({
          battery: level
        });
      };
    })(this);
  };

  BigCar.prototype.drive = function(code) {
    this.code = code;
  };

  BigCar.prototype.code2command = function(code) {
    var newCode;
    newCode = "05893476"[code - 1];
    if (newCode) {
      return "$" + newCode + "9476$?";
    }
    return "$?";
  };

  BigCar.prototype.steer = function(code) {
    if (code === 5 || code === 7) {
      return "3";
    }
    if (code === 6 || code === 8) {
      return "4";
    }
    return null;
  };

  BigCar.prototype.nextCode = function() {
    var steering;
    if (this.socket && this.socket.readyState === "open") {
      if (this.code > -5) {
        console.log("sending drive " + this.code);
        steering = this.steer(this.code);
        if (steering) {
          this.socket.send(this.code2command(steering));
        }
        this.socket.send(this.code2command(this.code));
        if (steering) {
          this.socket.send(this.code2command(steering));
        }
        if (this.code < 1) {
          return this.code -= 1;
        }
      }
    } else {
      return this.connectSocket();
    }
  };

  return BigCar;

})(Car);

Announcer = (function() {
  function Announcer(name) {
    this.name = name;
    console.log("Tracking " + this.name + " events");
  }

  Announcer.prototype.setBot = function(bot) {
    this.bot = bot;
  };

  Announcer.prototype.announce = function(message) {
    if (this.bot) {
      return this.bot.announce(message);
    }
  };

  Announcer.prototype.announceResponse = function(property, args) {
    if (args == null) {
      args = [];
    }
    if (this.bot && this.bot.currentState) {
      return this.announce(this.bot.currentState.responseTo(property, args));
    }
  };

  return Announcer;

})();

ButtonAnnouncer = (function(_super) {
  __extends(ButtonAnnouncer, _super);

  function ButtonAnnouncer(name, buttons) {
    var action, _fn, _i, _len;
    ButtonAnnouncer.__super__.constructor.call(this, name);
    _fn = (function(_this) {
      return function(action) {
        return $("#" + action + "-button").click(function() {
          return _this.announce({
            button: action
          });
        });
      };
    })(this);
    for (_i = 0, _len = buttons.length; _i < _len; _i++) {
      action = buttons[_i];
      _fn(action);
    }
  }

  return ButtonAnnouncer;

})(Announcer);

CrashAnnouncer = (function(_super) {
  __extends(CrashAnnouncer, _super);

  function CrashAnnouncer(name, magnitude, mininterval) {
    this.magnitude = magnitude != null ? magnitude : 25;
    this.mininterval = mininterval != null ? mininterval : 1000000;
    CrashAnnouncer.__super__.constructor.call(this, name);
    this.motionTimeStamp = 0;
    this.motionVector = {
      x: 0,
      y: 0,
      z: 0
    };
    this.crash_id = window.addEventListener('devicemotion', (function(_this) {
      return function(event) {
        var a, interval, m, v;
        a = event.accelerationIncludingGravity;
        m = _this.motionVector;
        v = Math.pow(a.x - m.x, 2) + Math.pow(a.y - m.y, 2) + Math.pow(a.z - m.z, 2);
        interval = event.timeStamp - _this.motionTimeStamp;
        _this.motionVector = {
          x: a.x,
          y: a.y,
          z: a.z
        };
        if (v > _this.magnitude && interval > _this.mininterval) {
          console.log("motion event magnitude " + v + " after " + (interval / _this.mininterval) + " intervals");
          _this.announce({
            crash: event
          });
          return _this.motionTimeStamp = event.timeStamp;
        }
      };
    })(this));
  }

  return CrashAnnouncer;

})(Announcer);

OrientationAnnouncer = (function(_super) {
  __extends(OrientationAnnouncer, _super);

  function OrientationAnnouncer(name) {
    OrientationAnnouncer.__super__.constructor.call(this, name);
    this.orientation_id = window.addEventListener('deviceorientation', (function(_this) {
      return function(event) {
        return _this.announce({
          orientation: event
        });
      };
    })(this), true);
  }

  return OrientationAnnouncer;

})(Announcer);

CorrectionAnnouncer = (function(_super) {
  __extends(CorrectionAnnouncer, _super);

  function CorrectionAnnouncer(name) {
    CorrectionAnnouncer.__super__.constructor.call(this, name);
    this.interval_id = window.setInterval(((function(_this) {
      return function() {
        return _this.announceResponse("correction");
      };
    })(this)), 1000);
  }

  return CorrectionAnnouncer;

})(Announcer);

LocationAnnouncer = (function(_super) {
  __extends(LocationAnnouncer, _super);

  function LocationAnnouncer(name) {
    LocationAnnouncer.__super__.constructor.call(this, name);
    this.watch_id = navigator.geolocation.watchPosition(((function(_this) {
      return function(location) {
        return _this.announce({
          location: location
        });
      };
    })(this)), (function() {
      return console.log("geolocation error");
    }), {
      enableHighAccuracy: true
    });
  }

  return LocationAnnouncer;

})(Announcer);

TimeAnnouncer = (function(_super) {
  __extends(TimeAnnouncer, _super);

  function TimeAnnouncer(name) {
    TimeAnnouncer.__super__.constructor.call(this, name);
    this.interval_id = window.setInterval(((function(_this) {
      return function() {
        return _this.announce({
          timer: 1
        });
      };
    })(this)), 1000);
  }

  return TimeAnnouncer;

})(Announcer);

CompassAnnouncer = (function(_super) {
  __extends(CompassAnnouncer, _super);

  function CompassAnnouncer(name, offset, factor) {
    this.offset = offset != null ? offset : 0;
    this.factor = factor != null ? factor : 1;
    CompassAnnouncer.__super__.constructor.call(this, name);
    this.orientation_id = window.addEventListener('deviceorientation', (function(_this) {
      return function(event) {
        var adjusted;
        adjusted = Math.floor((360 + _this.offset + _this.factor * event.alpha) % 360);
        return _this.announce({
          compass: adjusted
        });
      };
    })(this), true);
  }

  return CompassAnnouncer;

})(Announcer);
